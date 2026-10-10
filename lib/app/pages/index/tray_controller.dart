import 'dart:async';
import 'dart:io';

import 'package:asuka/asuka.dart';
import 'package:clash_for_flutter/app/enum/type_enum.dart';
import 'package:clash_for_flutter/app/bean/proxies_bean.dart';
import 'package:clash_for_flutter/app/bean/profile_base_bean.dart';
import 'package:clash_for_flutter/app/bean/profile_file_bean.dart';
import 'package:clash_for_flutter/app/bean/profile_url_bean.dart';
import 'package:clash_for_flutter/app/exceptions/message_exception.dart';
import 'package:clash_for_flutter/app/pages/index/tray_menus.dart';
import 'package:clash_for_flutter/app/pages/router.dart';
import 'package:clash_for_flutter/app/source/app_config.dart';
import 'package:clash_for_flutter/app/source/core_config.dart';
import 'package:clash_for_flutter/app/source/desktop_dialogs.dart';
import 'package:clash_for_flutter/app/source/desktop_presentation.dart';
import 'package:clash_for_flutter/app/source/proxy_latency_tester.dart';
import 'package:clash_for_flutter/app/utils/app_json.dart';
import 'package:clash_for_flutter/app/source/logs_subscription.dart';
import 'package:clash_for_flutter/app/source/request.dart';
import 'package:clash_for_flutter/app/utils/constants.dart';
import 'package:clash_for_flutter/core_control.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:mobx/mobx.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:system_tray/system_tray.dart';
import 'package:window_manager/window_manager.dart';

/// Windows/macOS 托盘菜单与运行状态图标。
class TrayController {
  static const _activeIcon = 'assets/icon.ico';
  static const _inactiveIcon = 'assets/icon_inactive.ico';
  static const _activeIconOther = 'assets/logo_64.png';
  static const _inactiveIconOther = 'assets/logo_64_inactive.png';
  static const _activeIconMacos = 'assets/tray_macos_active.png';
  static const _inactiveIconMacos = 'assets/tray_macos_inactive.png';

  final SystemTray _tray = SystemTray();
  final AppConfig _config = Modular.get<AppConfig>();
  final CoreConfig _core = Modular.get<CoreConfig>();
  final Request _request = Modular.get<Request>();
  final LogsSubscription _logs = Modular.get<LogsSubscription>();
  final List<ReactionDisposer> _reactions = [];

  StreamSubscription? _trafficSubscription;
  Timer? _trafficRetry;
  bool _stopping = false;

  bool _initialized = false;
  late final presentation = DesktopPresentation(
    lightMode: _config.clashForMe.lightMode,
    saveMode: (value) => _config.setTrayPreferences(lightMode: value),
    setSkipTaskbar: (value) => windowManager.setSkipTaskbar(value),
    show: () => windowManager.show(),
    hide: () => windowManager.hide(),
    focus: () => windowManager.focus(),
  );
  final Menu _menu = Menu();
  final Map<String, int?> _delays = {};
  Timer? _snapshotTimer;
  bool _readingSnapshot = false;
  bool _menuDirty = false;
  bool _testing = false;
  bool _profileAction = false;
  bool? _loginEnabled;
  bool _openingMenu = false;
  bool _proxyUnavailable = false;
  Proxies? _proxies;
  bool? _lastEnabled;
  Future<void>? _refreshTask;
  String _appVersion = '—';
  PageController? _pageController;

  void attachPageController(PageController controller) {
    _pageController = controller;
  }

  void detachPageController(PageController controller) {
    if (identical(_pageController, controller)) _pageController = null;
  }

  void init() {
    if (_initialized) return;
    _initialized = true;
    presentation.dashboardVisible.addListener(_syncDashboardServices);
    _syncDashboardServices();
    unawaited(_initialize());
  }

  void _syncDashboardServices() {
    if (presentation.dashboardVisible.value) {
      _logs.startSubLogs();
    } else {
      _logs.pause();
    }
  }

  Future<void> _initialize() async {
    final package = await PackageInfo.fromPlatform();
    _appVersion = package.version;
    _reactions.addAll([
      reaction((_) => _config.systemProxy, (_) => unawaited(_refreshTray())),
      reaction((_) => _core.clash, (_) => unawaited(_refreshTray())),
      reaction((_) => _core.tunEnable, (_) => unawaited(_refreshTray())),
      reaction((_) => _config.clashForMe, (_) {
        if (Platform.isMacOS) unawaited(_showSpeed(_lastUp, _lastDown));
        unawaited(_refreshTray());
      }),
    ]);

    await _tray.initSystemTray(
      iconPath: _iconPath(enabled: _isEnabled),
      isTemplate: false,
      toolTip: _toolTip,
    );
    _tray.registerSystemTrayEventHandler((event) {
      if (event == kSystemTrayEventClick) {
        if (Platform.isMacOS) {
          unawaited(_openMenu());
        } else {
          unawaited(_showPage('/home'));
        }
      } else if (event == kSystemTrayEventRightClick) {
        unawaited(_openMenu());
      }
    });
    await _refreshTray(forceIcon: true);
    if (Platform.isMacOS) {
      _subscribeTraffic();
      _loginEnabled = await DesktopDialogs.loginStatus();
    }
    unawaited(_syncSnapshot());
    _snapshotTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (presentation.dashboardVisible.value || _openingMenu) unawaited(_syncSnapshot());
    });
  }

  static String formatSpeed(int bytes) {
    if (bytes < 1024) return '$bytes B/s';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB/s';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB/s';
  }

  int _lastUp = 0;
  int _lastDown = 0;

  Future<void> _showSpeed(int up, int down) async {
    _lastUp = up;
    _lastDown = down;
    if (_stopping) return;
    await _tray.setSystemTrayInfo(
      title: _config.clashForMe.showTraySpeed
          ? '${formatSpeed(up)}\n${formatSpeed(down)}' : '',
    );
  }

  void _subscribeTraffic() {
    if (_stopping) return;
    unawaited(_showSpeed(0, 0));
    _trafficSubscription = _request.traffic().listen(
      (speed) => unawaited(_showSpeed(speed?.up ?? 0, speed?.down ?? 0)),
      onError: (Object error) => _retryTraffic(),
      onDone: _retryTraffic,
      cancelOnError: true,
    );
  }

  void _retryTraffic() {
    if (_stopping) return;
    unawaited(_showSpeed(0, 0));
    _trafficRetry?.cancel();
    _trafficRetry = Timer(const Duration(seconds: 2), _subscribeTraffic);
  }

  Future<void> _stopTraffic() async {
    _stopping = true;
    _trafficRetry?.cancel();
    _snapshotTimer?.cancel();
    await _trafficSubscription?.cancel();
    presentation.dashboardVisible.removeListener(_syncDashboardServices);
    _logs.pause();
    for (final dispose in _reactions) { dispose(); }
    _reactions.clear();
  }

  bool get _isEnabled => _config.systemProxy || _core.tunEnable;

  Future<void> _readProxies() async {
    try {
      _proxies = await _request.getProxies();
      _proxyUnavailable = _proxies == null;
    } catch (_) {
      _proxies = null;
      _proxyUnavailable = true;
    }
  }

  Future<void> _syncSnapshot() async {
    if (_readingSnapshot || _stopping) return;
    _readingSnapshot = true;
    try {
      await Future.wait([_core.asyncConfig(), _readProxies()]);
      if (Platform.isMacOS) _loginEnabled = await DesktopDialogs.loginStatus();
      await _refreshTray();
    } catch (_) {
      // Keep the menu and restart actions available even when the core is down.
    } finally {
      _readingSnapshot = false;
    }
  }

  Future<void> _openMenu() async {
    if (_openingMenu || _stopping) return;
    // Open the cached menu immediately; a dead REST socket cannot block it.
    await _refreshTray();
    _openingMenu = true;
    unawaited(_syncSnapshot());
    try {
      await _tray.popUpContextMenu();
    } finally {
      _openingMenu = false;
      if (_menuDirty) await _refreshTray();
    }
  }

  String get _toolTip => _isEnabled ? 'ClashWave · 已开启' : 'ClashWave · 未开启';

  String _iconPath({required bool enabled}) {
    if (Platform.isMacOS) {
      return enabled ? _activeIconMacos : _inactiveIconMacos;
    }
    if (Platform.isWindows) {
      return enabled ? _activeIcon : _inactiveIcon;
    }
    return enabled ? _activeIconOther : _inactiveIconOther;
  }

  Future<void> _refreshTray({bool forceIcon = false}) async {
    if (_stopping) return;
    if (_openingMenu) {
      _menuDirty = true;
      return;
    }
    if (_refreshTask != null) {
      _menuDirty = true;
      await _refreshTask;
      return;
    }
    _menuDirty = false;
    final task = _applyTray(forceIcon: forceIcon);
    _refreshTask = task;
    try {
      await task;
    } finally {
      _refreshTask = null;
    }
    if (_menuDirty && !_openingMenu) await _refreshTray();
  }

  Future<void> _applyTray({required bool forceIcon}) async {
    final enabled = _isEnabled;
    final mode = _core.clash.mode ?? Mode.Rule;

    if (forceIcon || enabled != _lastEnabled) {
      await _tray.setSystemTrayInfo(
        iconPath: _iconPath(enabled: enabled),
        isTemplate: false,
        toolTip: _toolTip,
      );
      _lastEnabled = enabled;
    }

    final menu = await _buildMenu(enabled: enabled, mode: mode);
    await _tray.setContextMenu(menu);
  }

  Future<Menu> _buildMenu({required bool enabled, required Mode mode}) async {
    await _menu.buildFrom([
      MenuItemLabel(label: '打开仪表板…', onClicked: (_) => unawaited(_showPage('/home'))),
      MenuSeparator(),
      SubMenu(label: '出站模式（${_modeLabel(mode)}）', children: [
        for (final value in Mode.values) _modeItem(value, mode),
      ]),
      ...TrayMenus.proxyGroups(
        snapshot: _proxies, mode: mode, unavailable: _proxyUnavailable,
        testing: _testing, delays: _delays,
        sortByDelay: _config.clashForMe.sortProxiesByDelay,
        onSelect: (group, node) => unawaited(_runAction(() async {
          if (!await _request.changeProxy(name: group, select: node)) {
            throw MessageException('Mihomo 未接受代理选择');
          }
          await _readProxies();
        })),
        onTest: (group) => unawaited(_testDelay(group.all)),
      ),
      MenuItemLabel(
        label: _testing ? '正在测速…' : '测试全部节点延迟',
        enabled: !_testing && _proxies != null,
        onClicked: (_) => unawaited(_testDelay(_proxies!.proxies.keys)),
      ),
      MenuSeparator(),
      TrayMenus.subscriptions(
        profiles: _config.profiles.toList(), selectedFile: _config.selectedFile,
        onSelect: (file) => unawaited(_runProfileAction(() async {
          await _config.selectProfile(file);
          _delays.clear();
          await _readProxies();
        })),
        onUpdate: (profile) => unawaited(_runProfileAction(() => _updateProfile(profile))),
        onManage: () => unawaited(_showPage('/profiles')),
        actions: _profileMenuActions(),
      ),
      MenuSeparator(),
      MenuItemCheckbox(label: '设置为系统代理', checked: _config.systemProxy,
        onClicked: (_) => unawaited(_toggleSystemProxy())),
      MenuItemCheckbox(label: 'TUN 模式', checked: _core.tunEnable,
        onClicked: (_) => unawaited(_toggleTun())),
      MenuItemCheckbox(label: '允许局域网连接', checked: _core.clash.allowLan ?? false,
        onClicked: (_) => unawaited(_runAction(() => _core.setState(
          allowLan: !(_core.clash.allowLan ?? false))))),
      MenuSeparator(),
      SubMenu(label: '设置', children: [
        MenuItemCheckbox(label: '启动时打开仪表板', checked: !presentation.lightMode,
          onClicked: (_) => unawaited(_runAction(() => presentation.setLightMode(!presentation.lightMode)))),
        if (Platform.isMacOS)
          MenuItemCheckbox(label: _loginEnabled == null ? '登录时启动（需 macOS 13+）' : '登录时启动',
            checked: _loginEnabled ?? false, enabled: _loginEnabled != null,
            onClicked: (_) => unawaited(_runAction(() async {
              _loginEnabled = await DesktopDialogs.setLoginEnabled(!(_loginEnabled ?? false));
            }))),
        if (Platform.isMacOS)
          MenuItemCheckbox(label: '显示菜单栏网速', checked: _config.clashForMe.showTraySpeed,
            onClicked: (_) => unawaited(_runAction(() => _config.setTrayPreferences(
              showTraySpeed: !_config.clashForMe.showTraySpeed)))),
        MenuItemCheckbox(label: '节点按延迟排序', checked: _config.clashForMe.sortProxiesByDelay,
          onClicked: (_) => unawaited(_runAction(() => _config.setTrayPreferences(
            sortProxiesByDelay: !_config.clashForMe.sortProxiesByDelay)))),
        SubMenu(label: '日志等级（${(_core.clash.logLevel ?? LogLevel.info).value}）', children: [
          for (final level in LogLevel.values)
            MenuItemCheckbox(label: level.value, checked: level == (_core.clash.logLevel ?? LogLevel.info),
              onClicked: (_) => unawaited(_runAction(() => _core.setState(logLevel: level)))),
        ]),
        if (Platform.isMacOS)
          MenuItemLabel(label: '修改延迟测试地址…', onClicked: (_) => unawaited(_runAction(_editDelayUrl))),
        MenuItemLabel(label: '更多设置…', onClicked: (_) => unawaited(_showPage('/settings'))),
      ]),
      SubMenu(label: '工具', children: [
        MenuItemLabel(label: '重新加载当前配置', onClicked: (_) => unawaited(_reloadProfile())),
        MenuItemLabel(label: '复制终端代理命令', onClicked: (_) => unawaited(_copyEnvironmentVariables())),
        MenuItemLabel(label: '关闭所有连接', onClicked: (_) => unawaited(_runAction(() async {
          if (!await _request.closeAllConnections()) throw MessageException('无法关闭连接');
        }))),
        MenuItemLabel(label: '打开配置目录', onClicked: (_) => unawaited(_runAction(
          () => _openDirectory(Constants.homeDir.path)))),
        MenuItemLabel(label: '查看日志…', onClicked: (_) => unawaited(_showPage('/logs'))),
        MenuItemLabel(label: '重启 Mihomo 内核', onClicked: (_) => unawaited(_restartCore())),
        MenuItemLabel(label: '重启应用', onClicked: (_) => unawaited(_restartApp())),
      ]),
      MenuItemLabel(label: 'ClashWave $_appVersion', enabled: false),
      MenuSeparator(),
      MenuItemLabel(label: enabled ? '退出（运行中）' : '退出', onClicked: (_) => unawaited(_runAction(_exit))),
    ]);
    return _menu;
  }

  String _modeLabel(Mode mode) => switch (mode) {
    Mode.Rule => '规则', Mode.Global => '全局', Mode.Direct => '直连',
  };

  List<MenuItemBase> _profileMenuActions() {
    final profile = _config.active;
    return [
      MenuItemLabel(label: '导入本地配置文件…', onClicked: (_) => unawaited(_runProfileAction(_importFile))),
      MenuItemLabel(label: '添加订阅地址…', onClicked: (_) => unawaited(Platform.isMacOS
        ? _runProfileAction(_importUrl) : _showPage('/profiles'))),
      if (Platform.isMacOS)
        MenuItemLabel(label: '从剪贴板导入订阅', onClicked: (_) => unawaited(_runProfileAction(() async {
          final text = (await Clipboard.getData(Clipboard.kTextPlain))?.text;
          if (text == null || text.trim().isEmpty) throw MessageException('剪贴板没有订阅地址');
          await _config.importProfile(ProfileURL.emptyBean()..url = text.trim()..interval = 24);
          _delays.clear();
          await _readProxies();
        }))),
      MenuItemLabel(label: '更新全部订阅', enabled: _config.profiles.whereType<ProfileURL>().isNotEmpty,
        onClicked: (_) => unawaited(_runProfileAction(_updateAllProfiles))),
      MenuItemCheckbox(label: '自动更新订阅', checked: _config.clashForMe.autoUpdateSubscriptions,
        onClicked: (_) => unawaited(_runAction(() => _config.setTrayPreferences(
          autoUpdateSubscriptions: !_config.clashForMe.autoUpdateSubscriptions)))),
      if (profile != null && Platform.isMacOS)
        SubMenu(label: '当前配置操作', children: [
          MenuItemLabel(label: '重命名…', onClicked: (_) => unawaited(_runProfileAction(() => _renameProfile(profile)))),
          if (profile is ProfileURL) ...[
            MenuItemLabel(label: '修改订阅地址…', onClicked: (_) => unawaited(_runProfileAction(() => _editProfileUrl(profile)))),
            MenuItemLabel(label: '更新间隔（${profile.interval} 小时）…',
              onClicked: (_) => unawaited(_runProfileAction(() => _editProfileInterval(profile)))),
            MenuItemLabel(label: '复制订阅地址', onClicked: (_) => unawaited(_runAction(
              () => Clipboard.setData(ClipboardData(text: profile.url))))),
          ],
          MenuItemLabel(label: '在 Finder 中显示配置', onClicked: (_) => unawaited(_runAction(() async {
            await Process.run('open', ['-R', '${_config.profilesPath}/${profile.file}']);
          }))),
          MenuItemLabel(label: '移除配置…', onClicked: (_) => unawaited(_runProfileAction(() async {
            if (await DesktopDialogs.confirm('移除配置', '确定移除“${profile.name}”？')) {
              await _config.removeProfile(profile.file);
              _delays.clear();
              await _readProxies();
            }
          }))),
        ]),
      MenuItemLabel(label: '重新加载当前配置', onClicked: (_) => unawaited(_reloadProfile())),
      MenuItemLabel(label: '打开配置目录', onClicked: (_) => unawaited(_runAction(
        () => _openDirectory(_config.profilesPath)))),
    ];
  }

  Future<void> _importFile() async {
    final path = await DesktopDialogs.pickProfileFile();
    if (path == null || path.isEmpty) return;
    await _config.importProfile(ProfileFile.emptyBean()..path = path);
    _delays.clear();
    await _readProxies();
  }

  Future<void> _importUrl() async {
    final url = await DesktopDialogs.prompt(title: '添加订阅', message: '输入 HTTP / HTTPS 订阅地址');
    if (url == null || url.trim().isEmpty) return;
    await _config.importProfile(ProfileURL.emptyBean()..url = url.trim()..interval = 24);
    _delays.clear();
    await _readProxies();
  }

  Future<void> _renameProfile(ProfileBase profile) async {
    final name = await DesktopDialogs.prompt(title: '重命名配置', value: profile.name);
    if (name == null || name.trim().isEmpty) return;
    final copy = AppJson.fromJson<ProfileBase>(AppJson.encode(profile))!;
    copy.name = name.trim();
    await _config.editProfile(copy);
  }

  Future<void> _editProfileUrl(ProfileURL profile) async {
    final url = await DesktopDialogs.prompt(title: '修改订阅地址', value: profile.url);
    if (url == null || url.trim().isEmpty) return;
    final copy = AppJson.cloneProfileUrl(profile)..url = url.trim();
    await _config.editProfile(copy);
    await _updateProfile(copy);
  }

  Future<void> _editProfileInterval(ProfileURL profile) async {
    final text = await DesktopDialogs.prompt(title: '更新间隔（小时）', message: '0 表示不自动更新此订阅', value: '${profile.interval}');
    if (text == null) return;
    final hours = int.tryParse(text.trim());
    if (hours == null || hours < 0) throw MessageException('请输入大于或等于 0 的整数');
    await _config.editProfile(AppJson.cloneProfileUrl(profile)..interval = hours);
  }

  Future<void> _updateProfile(ProfileURL profile) async {
    await _config.refreshProfile(profile);
    await _core.asyncConfig();
    _delays.clear();
    await _readProxies();
  }

  Future<void> _updateAllProfiles() async {
    var failures = 0;
    for (final profile in _config.profiles.whereType<ProfileURL>().toList()) {
      try {
        await _config.refreshProfile(profile);
      } catch (_) {
        failures++;
      }
    }
    await _core.asyncConfig();
    _delays.clear();
    await _readProxies();
    if (failures > 0) throw MessageException('$failures 个订阅更新失败，已保留原配置；可单独更新查看原因');
  }

  Future<void> _editDelayUrl() async {
    final url = await DesktopDialogs.prompt(title: '延迟测试地址', value: _config.clashForMe.delayTestUrl);
    if (url == null) return;
    final uri = Uri.tryParse(url.trim());
    if (uri == null || !['http', 'https'].contains(uri.scheme) || uri.host.isEmpty) {
      throw MessageException('请输入有效的 HTTP 或 HTTPS 地址');
    }
    _config.setState(delayTestUrl: url.trim());
    await _config.clashForMe.saveFile();
  }

  Future<void> _reloadProfile() => _runProfileAction(() async {
    if (!await _config.asyncProfile()) throw MessageException('Mihomo 拒绝了当前配置');
    await _core.asyncConfig();
    _delays.clear();
    await _readProxies();
  });

  Future<void> _testDelay(Iterable<String> names) async {
    if (_testing || _stopping) return;
    _testing = true;
    await _runAction(() async {
      await _refreshTray();
      final selected = _config.selectedFile;
      final url = _config.clashForMe.delayTestUrl;
      final result = await const ProxyLatencyTester().test(
        names.where((name) => !['DIRECT', 'REJECT', 'REJECT-DROP', 'PASS'].contains(name)),
        (name) => _request.getProxyDelay(name, url),
        cancelled: () => _stopping || selected != _config.selectedFile,
      );
      if (!_stopping && selected == _config.selectedFile) {
        _delays.addAll(result);
        await _readProxies();
      }
    });
    _testing = false;
    await _refreshTray();
  }

  Future<void> _runProfileAction(Future<void> Function() action) async {
    if (_profileAction) {
      await _notifyError(MessageException('正在处理配置，请稍后重试'));
      return;
    }
    _profileAction = true;
    try {
      await _runAction(action);
    } finally {
      _profileAction = false;
    }
  }

  MenuItemCheckbox _modeItem(Mode value, Mode current) {
    return MenuItemCheckbox(
      checked: value == current,
      label: _modeLabel(value),
      onClicked: (_) => unawaited(_setMode(value)),
    );
  }

  Future<void> _setMode(Mode mode) async {
    await _runAction(() async {
      await _core.setState(mode: mode);
    });
  }

  Future<void> _toggleSystemProxy() async {
    await _runAction(() async {
      if (_config.systemProxy) {
        await _config.closeProxy();
      } else {
        await _config.openProxy();
      }
    });
  }

  Future<void> _toggleTun() async {
    await _runAction(() async {
      if (_core.tunEnable) {
        await _core.closeTun();
      } else {
        await _core.openTun();
      }
    });
  }

  Future<void> _copyEnvironmentVariables() async {
    await _runAction(() async {
      final port = await _request.ensureMixedPort();
      final http = 'http://${Constants.localhost}:$port';
      final socks = 'socks5://${Constants.localhost}:$port';
      final command = Platform.isWindows
          ? '\$env:HTTP_PROXY="$http"; \$env:HTTPS_PROXY="$http"; '
                '\$env:ALL_PROXY="$socks"'
          : 'export HTTP_PROXY="$http" HTTPS_PROXY="$http" '
                'ALL_PROXY="$socks"';
      await Clipboard.setData(ClipboardData(text: command));
    });
  }

  Future<void> _restartCore() async {
    await _runAction(() async {
      await CoreControl.restartService();
      _logs.reconnect();
      if (!await _config.asyncProfile()) throw MessageException('内核已重启，但当前配置未能加载');
      await _core.asyncConfig();
      await _readProxies();
    });
  }

  Future<void> _restartApp() async {
    try {
      await CoreControl.shutdown();
      final executable = File(Platform.resolvedExecutable);
      if (Platform.isWindows) {
        String quote(String value) => value.replaceAll("'", "''");
        final command =
            "Start-Sleep -Milliseconds 400; Start-Process -FilePath '${quote(executable.path)}' "
            "-WorkingDirectory '${quote(executable.parent.path)}'";
        await Process.start('powershell.exe', [
          '-NoProfile',
          '-NonInteractive',
          '-WindowStyle',
          'Hidden',
          '-Command',
          command,
        ], mode: ProcessStartMode.detached);
      } else {
        await Process.start('/bin/sh', [
          '-c',
          'sleep 0.4; exec ${_shellQuote(executable.path)}',
        ], mode: ProcessStartMode.detached);
      }
      await _stopTraffic();
      await _tray.destroy();
      await windowManager.setPreventClose(false);
      await windowManager.destroy();
    } catch (error) {
      await _notifyError(error);
    }
  }

  String _shellQuote(String value) => "'${value.replaceAll("'", "'\\''")}'";

  Future<void> _runAction(Future<void> Function() action) async {
    try {
      await action();
    } catch (error) {
      await _notifyError(error);
    } finally {
      await _refreshTray();
    }
  }

  Future<void> _showPage(String path) async {
    await _showWindow();
    await WidgetsBinding.instance.endOfFrame;
    final index = menu.menuList.indexWhere((item) => item.path == path);
    final pageController = _pageController;
    if (index >= 0 && pageController != null && pageController.hasClients) {
      pageController.jumpToPage(index);
    }
    Modular.to.navigate('/tab$path/');
  }

  Future<void> _showWindow() => presentation.openDashboard();

  Future<void> _notifyError(Object error) async {
    if (Platform.isMacOS) {
      await DesktopDialogs.message('操作失败', error.toString());
    } else {
      await _showWindow();
      Asuka.showSnackBar(SnackBar(content: Text('操作失败：$error')));
    }
  }

  Future<void> _openDirectory(String path) async {
    if (Platform.isWindows) {
      await Process.run('explorer.exe', [path]);
    } else if (Platform.isMacOS) {
      await Process.run('open', [path]);
    } else {
      await Process.run('xdg-open', [path]);
    }
  }

  Future<void> _exit() async {
    if (_config.systemProxy) await _config.closeProxy();
    if (_core.tunEnable) await _core.closeTun();
    await CoreControl.shutdown();
    await _stopTraffic();
    await _tray.destroy();
    await windowManager.setPreventClose(false);
    await windowManager.close();
    await windowManager.destroy();
  }
}

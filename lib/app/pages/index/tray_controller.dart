import 'dart:async';
import 'dart:io';

import 'package:asuka/asuka.dart';
import 'package:clash_for_flutter/app/enum/type_enum.dart';
import 'package:clash_for_flutter/app/pages/router.dart';
import 'package:clash_for_flutter/app/source/app_config.dart';
import 'package:clash_for_flutter/app/source/core_config.dart';
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
  bool _lightMode = false;
  bool? _lastEnabled;
  int _refreshGeneration = 0;
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
    unawaited(_initialize());
  }

  Future<void> _initialize() async {
    final package = await PackageInfo.fromPlatform();
    _appVersion = package.version;
    _reactions.addAll([
      reaction((_) => _config.systemProxy, (_) => unawaited(_refreshTray())),
      reaction((_) => _core.clash.mode, (_) => unawaited(_refreshTray())),
      reaction((_) => _core.tunEnable, (_) => unawaited(_refreshTray())),
    ]);

    await _tray.initSystemTray(
      iconPath: _iconPath(enabled: _isEnabled),
      isTemplate: false,
      toolTip: _toolTip,
    );
    _tray.registerSystemTrayEventHandler((event) {
      if (event == kSystemTrayEventClick) {
        if (Platform.isMacOS) {
          unawaited(_tray.popUpContextMenu());
        } else {
          unawaited(_showPage('/home'));
        }
      } else if (event == kSystemTrayEventRightClick) {
        unawaited(_tray.popUpContextMenu());
      }
    });
    await _refreshTray(forceIcon: true);
    if (Platform.isMacOS) _subscribeTraffic();
  }

  static String formatSpeed(int bytes) {
    if (bytes < 1024) return '$bytes B/s';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB/s';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB/s';
  }

  Future<void> _showSpeed(int up, int down) async {
    if (_stopping) return;
    await _tray.setSystemTrayInfo(
      title: '${formatSpeed(up)}\n${formatSpeed(down)}',
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
    await _trafficSubscription?.cancel();
  }

  bool get _isEnabled => _config.systemProxy || _core.tunEnable;

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
    final generation = ++_refreshGeneration;
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
    if (generation == _refreshGeneration) {
      await _tray.setContextMenu(menu);
    }
  }

  Future<Menu> _buildMenu({required bool enabled, required Mode mode}) async {
    final menu = Menu();
    await menu.buildFrom([
      MenuItemLabel(
        label: '仪表板',
        onClicked: (_) => unawaited(_showPage('/home')),
      ),
      MenuSeparator(),
      SubMenu(
        label: '出站模式（${mode.value}）',
        children: [
          _modeItem(Mode.Rule, mode),
          _modeItem(Mode.Global, mode),
          _modeItem(Mode.Direct, mode),
        ],
      ),
      MenuItemLabel(
        label: '订阅',
        onClicked: (_) => unawaited(_showPage('/profiles')),
      ),
      MenuItemLabel(
        label: '代理',
        onClicked: (_) => unawaited(_showPage('/proxys')),
      ),
      MenuSeparator(),
      MenuItemCheckbox(
        label: '系统代理',
        checked: _config.systemProxy,
        onClicked: (_) => unawaited(_toggleSystemProxy()),
      ),
      MenuItemCheckbox(
        label: 'TUN 模式',
        checked: _core.tunEnable,
        onClicked: (_) => unawaited(_toggleTun()),
      ),
      MenuSeparator(),
      MenuItemCheckbox(
        label: '轻量模式',
        checked: _lightMode,
        onClicked: (_) => unawaited(_toggleLightMode()),
      ),
      SubMenu(
        label: '打开目录',
        children: [
          MenuItemLabel(
            label: '配置目录',
            onClicked: (_) => unawaited(_openDirectory(Constants.homeDir.path)),
          ),
          MenuItemLabel(
            label: '程序目录',
            onClicked: (_) => unawaited(
              _openDirectory(File(Platform.resolvedExecutable).parent.path),
            ),
          ),
        ],
      ),
      SubMenu(
        label: '更多',
        children: [
          MenuItemLabel(
            label: '复制环境变量',
            onClicked: (_) => unawaited(_copyEnvironmentVariables()),
          ),
          MenuItemLabel(
            label: '关闭所有连接',
            onClicked: (_) => unawaited(
              _runAction(() async => _request.closeAllConnections()),
            ),
          ),
          MenuItemLabel(
            label: '重启 Mihomo 内核',
            onClicked: (_) => unawaited(_restartCore()),
          ),
          MenuItemLabel(
            label: '重启应用',
            onClicked: (_) => unawaited(_restartApp()),
          ),
          MenuSeparator(),
          MenuItemLabel(label: 'ClashWave 版本 $_appVersion', enabled: false),
        ],
      ),
      MenuSeparator(),
      MenuItemLabel(
        label: enabled ? '退出（运行中）' : '退出',
        onClicked: (_) => unawaited(_exit()),
      ),
    ]);
    return menu;
  }

  MenuItemCheckbox _modeItem(Mode value, Mode current) {
    return MenuItemCheckbox(
      checked: value == current,
      label: value.value,
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

  Future<void> _toggleLightMode() async {
    _lightMode = !_lightMode;
    if (_lightMode) {
      await windowManager.hide();
    } else {
      await _showWindow();
    }
    await _refreshTray();
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
      await _core.asyncConfig();
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
      await _showWindow();
      Asuka.showSnackBar(SnackBar(content: Text('重启应用失败：$error')));
    }
  }

  String _shellQuote(String value) => "'${value.replaceAll("'", "'\\''")}'";

  Future<void> _runAction(Future<void> Function() action) async {
    try {
      await action();
    } catch (error) {
      await _showWindow();
      Asuka.showSnackBar(SnackBar(content: Text('操作失败：$error')));
    } finally {
      await _refreshTray();
    }
  }

  Future<void> _showPage(String path) async {
    await _showWindow();
    final index = menu.menuList.indexWhere((item) => item.path == path);
    final pageController = _pageController;
    if (index >= 0 && pageController != null && pageController.hasClients) {
      pageController.jumpToPage(index);
    }
    Modular.to.navigate('/tab$path/');
  }

  Future<void> _showWindow() async {
    if (_lightMode) {
      _lightMode = false;
      unawaited(_refreshTray());
    }
    await windowManager.show();
    await windowManager.focus();
  }

  Future<void> _openDirectory(String path) async {
    if (Platform.isWindows) {
      await Process.run('explorer.exe', [path]);
    } else if (Platform.isMacOS) {
      await Process.run('open', [path]);
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

import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:clash_for_flutter/app/bean/clash_for_me_config_bean.dart';
import 'package:clash_for_flutter/app/bean/profile_base_bean.dart';
import 'package:clash_for_flutter/app/bean/profile_file_bean.dart';
import 'package:clash_for_flutter/app/bean/profile_url_bean.dart';
import 'package:clash_for_flutter/app/exceptions/message_exception.dart';
import 'package:clash_for_flutter/app/source/core_config.dart';
import 'package:clash_for_flutter/app/source/request.dart';
import 'package:clash_for_flutter/app/source/profile_importer.dart';
import 'package:clash_for_flutter/app/utils/constants.dart';
import 'package:clash_for_flutter/app/utils/app_json.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:mobx/mobx.dart';
import 'package:path/path.dart' hide context;
import 'package:proxy_manager/proxy_manager.dart';

part 'app_config.g.dart';

class AppConfig = AppConfigBase with _$AppConfig;

final proxyManager = ProxyManager();

abstract class AppConfigBase with Store {
  final _request = Modular.get<Request>();
  final _core = Modular.get<CoreConfig>();
  Timer? _subscriptionTimer;
  bool _checkingSubscriptions = false;
  bool _switchingProfile = false;

  final String profilesPath =
      "${Constants.homeDir.path}${Constants.profilesPath}";

  @observable
  bool systemProxy = false;
  @observable
  ClashForMeConfig clashForMe = ClashForMeConfig.defaultConfig();

  /// 当前应用中的配置文件
  @computed
  ProfileBase? get active {
    if (selectedFile == null) {
      return null;
    }
    return clashForMe.profiles.firstWhere((e) => e.file == selectedFile);
  }

  @computed
  String? get selectedFile => clashForMe.selectedFile;

  @computed
  bool get tunIf => clashForMe.tunIf ?? !Constants.isDesktop;

  @computed
  List<ProfileBase> get profiles => clashForMe.profiles;

  Future<void> init() async {
    await _initConfig();
    _request.setSubscriptionUserAgent(clashForMe.subscriptionUserAgent);
    _initReaction();
    _startSubscriptionUpdates();
  }

  @action
  _initConfig() async {
    ClashForMeConfig? tempCfm = ClashForMeConfig.formFile();
    tempCfm = await _profilesInitCheck(tempCfm);
    if (tempCfm != null) {
      clashForMe = tempCfm;
    }
  }

  _initReaction() {
    reaction(
      (_) => clashForMe,
      (ClashForMeConfig config) => config.saveFile(),
      delay: 1000,
    );
  }

  /// Publish the selected profile only after the core accepts it. Both the
  /// dashboard and menu bar use this path, avoiding duplicate reloads.
  Future<void> selectProfile(String file) async {
    if (!profiles.any((profile) => profile.file == file)) {
      throw MessageException('该订阅已被移除');
    }
    if (_switchingProfile) throw MessageException('正在切换订阅，请稍后重试');
    _switchingProfile = true;
    try {
      if (!await _request.changeConfig('$profilesPath/$file')) {
        throw MessageException('Mihomo 拒绝了该订阅，保留当前配置');
      }
      setState(selectedFile: file);
      await clashForMe.saveFile();
      await _core.asyncConfig();
    } finally {
      _switchingProfile = false;
    }
  }

  Future<void> setTrayPreferences({
    bool? lightMode,
    bool? showTraySpeed,
    bool? sortProxiesByDelay,
    bool? autoUpdateSubscriptions,
  }) async {
    final previous = clashForMe;
    runInAction(() {
      clashForMe = clashForMe.copyWith(
        lightMode: lightMode,
        showTraySpeed: showTraySpeed,
        sortProxiesByDelay: sortProxiesByDelay,
        autoUpdateSubscriptions: autoUpdateSubscriptions,
      );
    });
    try {
      await clashForMe.saveFile();
    } catch (_) {
      runInAction(() => clashForMe = previous);
      rethrow;
    }
  }

  Future<void> importProfile(ProfileBase source) async {
    if (_switchingProfile) throw MessageException('正在处理配置，请稍后重试');
    if (source is ProfileURL) {
      source.url = source.url.trim();
      final uri = Uri.tryParse(source.url);
      if (uri == null || !['https', 'http'].contains(uri.scheme) || uri.host.isEmpty) {
        throw MessageException('请输入有效的 HTTP 或 HTTPS 订阅地址');
      }
      if (hasSubscriptionUrl(source.url)) throw MessageException('该订阅地址已经存在');
    }
    _switchingProfile = true;
    ProfileBase? imported;
    try {
      if (source is ProfileURL) {
        imported = await _request.getSubscribe(profile: source, profilesDir: profilesPath);
      } else if (source is ProfileFile && source.path?.isNotEmpty == true) {
        imported = await ProfileImporter.fromFile(source.path!, profilesPath);
        if (source.name.isNotEmpty) imported.name = source.name;
      } else {
        throw MessageException('未选择配置文件');
      }
      if (profiles.isEmpty &&
          !await _request.changeConfig('$profilesPath/${imported.file}')) {
        throw MessageException('Mihomo 拒绝了该配置');
      }
      setState(profiles: [...profiles, imported]);
      await clashForMe.saveFile();
      await _core.asyncConfig();
    } catch (_) {
      if (imported != null && !profiles.any((p) => p.file == imported!.file)) {
        final failed = File('$profilesPath/${imported.file}');
        if (await failed.exists()) await failed.delete();
      }
      rethrow;
    } finally {
      _switchingProfile = false;
    }
  }

  Future<void> editProfile(ProfileBase profile) async {
    if (profile is ProfileURL) {
      final uri = Uri.tryParse(profile.url.trim());
      if (uri == null || !['http', 'https'].contains(uri.scheme) || uri.host.isEmpty) {
        throw MessageException('请输入有效的 HTTP 或 HTTPS 订阅地址');
      }
      if (hasSubscriptionUrl(profile.url, exceptFile: profile.file)) {
        throw MessageException('该订阅地址已经存在');
      }
    }
    final updated = profiles.toList();
    final index = updated.indexWhere((p) => p.file == profile.file);
    if (index < 0) throw MessageException('该配置已被移除');
    updated[index] = profile;
    setState(profiles: updated);
    await clashForMe.saveFile();
  }

  Future<void> replaceFileProfile(ProfileFile old, String path) async {
    if (_switchingProfile) throw MessageException('正在处理配置，请稍后重试');
    _switchingProfile = true;
    ProfileFile? latest;
    var activated = false;
    final previous = clashForMe;
    try {
      latest = await ProfileImporter.fromFile(path, profilesPath);
      latest.name = old.name;
      final updated = profiles.toList();
      final index = updated.indexWhere((p) => p.file == old.file);
      if (index < 0) throw MessageException('该配置已被移除');
      activated = selectedFile == old.file;
      if (activated && !await _request.changeConfig('$profilesPath/${latest.file}')) {
        activated = false;
        throw MessageException('Mihomo 拒绝了该配置，保留原文件');
      }
      updated[index] = latest;
      setState(profiles: updated, selectedFile: activated ? latest.file : selectedFile);
      await clashForMe.saveFile();
      await _core.asyncConfig();
    } catch (_) {
      runInAction(() => clashForMe = previous);
      if (activated) {
        try { await _request.changeConfig('$profilesPath/${old.file}'); } catch (_) {}
      }
      if (latest != null) {
        final failed = File('$profilesPath/${latest.file}');
        if (await failed.exists()) await failed.delete();
      }
      rethrow;
    } finally {
      _switchingProfile = false;
    }
    final oldFile = File('$profilesPath/${old.file}');
    if (await oldFile.exists()) await oldFile.delete();
  }

  Future<void> removeProfile(String file) async {
    if (_switchingProfile) throw MessageException('正在处理配置，请稍后重试');
    final remaining = profiles.where((p) => p.file != file).toList();
    if (remaining.length == profiles.length) return;
    if (selectedFile == file) {
      if (remaining.isNotEmpty) {
        await selectProfile(remaining.first.file);
      } else {
        // Removing the last profile must stop using its nodes immediately.
        if (!await _request.changeConfig('${Constants.homeDir.path}${Constants.clashConfig}')) {
          throw MessageException('无法卸载当前配置，已保留该订阅');
        }
        await _core.asyncConfig();
      }
    }
    setState(profiles: remaining);
    await clashForMe.saveFile();
    final removed = File('$profilesPath/$file');
    if (await removed.exists()) await removed.delete();
  }

  /// 校验本地订阅文件与配置里对应
  Future<ClashForMeConfig?> _profilesInitCheck(ClashForMeConfig? config) async {
    if (config == null) return null;

    var profilesDir = Directory(profilesPath);
    var fileList = <String>[];
    if (profilesDir.existsSync()) {
      fileList = profilesDir
          .listSync()
          .map((file) => basename(file.path))
          .toList();
    }

    List<ProfileBase> profiles = config.profiles
        .where((e) => fileList.contains(e.file))
        .toList();
    return config.copyWith(profiles: profiles);
  }

  @action
  setState({
    String? selectedFile,
    List<ProfileBase>? profiles,
    String? mmdbUrl,
    String? delayTestUrl,
    bool? tunIf,
    String? subscriptionUserAgent,
  }) {
    clashForMe = clashForMe.copyWith(
      selectedFile: selectedFile,
      profiles: profiles,
      mmdbUrl: mmdbUrl,
      delayTestUrl: delayTestUrl,
      tunIf: tunIf,
      subscriptionUserAgent: subscriptionUserAgent,
    );
  }

  Future<void> setSubscriptionUserAgent(String value) async {
    final normalized = value.trim();
    if (normalized.isEmpty || normalized.contains(RegExp(r'[\r\n]'))) {
      throw MessageException('请输入有效的订阅 User-Agent');
    }
    _request.setSubscriptionUserAgent(normalized);
    runInAction(() {
      clashForMe = clashForMe.copyWith(subscriptionUserAgent: normalized);
    });
    await clashForMe.saveFile();
  }

  bool hasSubscriptionUrl(String url, {String? exceptFile}) {
    final normalized = url.trim();
    return profiles.whereType<ProfileURL>().any(
      (profile) =>
          profile.file != exceptFile && profile.url.trim() == normalized,
    );
  }

  void _startSubscriptionUpdates() {
    _subscriptionTimer?.cancel();
    _subscriptionTimer = Timer.periodic(
      const Duration(minutes: 15),
      (_) => unawaited(checkSubscriptionUpdates()),
    );
    unawaited(
      Future<void>.delayed(
        const Duration(seconds: 10),
        checkSubscriptionUpdates,
      ),
    );
  }

  Future<void> checkSubscriptionUpdates() async {
    if (!clashForMe.autoUpdateSubscriptions) return;
    if (_checkingSubscriptions) return;
    _checkingSubscriptions = true;
    try {
      final now = DateTime.now();
      final expired = profiles
          .whereType<ProfileURL>()
          .where(
            (profile) =>
                profile.interval > 0 &&
                now.isAfter(
                  profile.time.add(Duration(hours: profile.interval)),
                ),
          )
          .toList();
      for (final profile in expired) {
        try {
          await refreshProfile(profile);
        } catch (error) {
          // An automatic update must keep the last known-good subscription.
          // The next timer tick retries it.
          developer.log(
            '订阅自动更新失败（${profile.name}）',
            name: 'ClashWave.subscription',
            error: error,
          );
        }
      }
    } finally {
      _checkingSubscriptions = false;
    }
  }

  /// Replaces [old] transactionally. The old file and metadata are kept until
  /// the new file has passed validation and, when active, Mihomo accepted it.
  Future<ProfileURL> refreshProfile(ProfileURL old) async {
    if (_switchingProfile) throw MessageException('正在处理配置，请稍后重试');
    _switchingProfile = true;
    try {
      return await _refreshProfile(old);
    } finally {
      _switchingProfile = false;
    }
  }

  Future<ProfileURL> _refreshProfile(ProfileURL old) async {
    final previous = clashForMe;
    final latest = await _request.getSubscribe(
      profile: AppJson.cloneProfileUrl(old),
      profilesDir: profilesPath,
    );
    final latestFile = File('$profilesPath/${latest.file}');
    final oldFile = File('$profilesPath/${old.file}');
    final active = selectedFile == old.file;
    var activatedLatest = false;
    try {
      if (active) {
        final accepted = await _request.changeConfig(latestFile.path);
        if (!accepted) throw MessageException('Mihomo 拒绝了更新后的订阅');
        activatedLatest = true;
      }

      final updatedProfiles = profiles.toList();
      final index = updatedProfiles.indexWhere((item) => item.file == old.file);
      if (index < 0) {
        throw MessageException('订阅已被移除，已取消更新');
      }
      updatedProfiles[index] = latest;
      runInAction(() {
        clashForMe = clashForMe.copyWith(
          selectedFile: active ? latest.file : selectedFile,
          profiles: updatedProfiles,
        );
      });
      await clashForMe.saveFile();

      if (await oldFile.exists()) await oldFile.delete();
      return latest;
    } catch (_) {
      runInAction(() => clashForMe = previous);
      if (activatedLatest && await oldFile.exists()) {
        try {
          await _request.changeConfig(oldFile.path);
        } catch (_) {
          // Preserve both the original error and the old on-disk profile.
        }
      }
      if (await latestFile.exists()) await latestFile.delete();
      rethrow;
    }
  }

  Future<bool> asyncProfile() {
    if (selectedFile == null) {
      return Future.value(true);
    }
    return _request.changeConfig("$profilesPath/$selectedFile");
  }

  Future<void> setGeodataBaseUrl(String value) async {
    final base = value.trim().replaceFirst(RegExp(r'/+$'), '');
    final uri = Uri.tryParse(base);
    if (uri == null ||
        !uri.hasAuthority ||
        (uri.scheme != 'https' && uri.scheme != 'http')) {
      throw MessageException('请输入完整的 HTTP 或 HTTPS 下载目录地址');
    }
    runInAction(() {
      clashForMe = clashForMe.copyWith(
        geodataBaseUrl: base,
        mmdbUrl: '$base/country.mmdb',
      );
    });
    await clashForMe.saveFile();
  }

  /// 打开代理
  @action
  Future<void> openProxy() async {
    if (Constants.isDesktop) {
      final port = await _request.ensureMixedPort();
      await _core.asyncConfig();
      try {
        final socket = await Socket.connect(
          Constants.localhost,
          port,
          timeout: const Duration(seconds: 2),
        );
        socket.destroy();
      } on SocketException {
        throw MessageException('内核未监听代理端口 $port，请检查端口是否被占用');
      }
      if (!Platform.isWindows) {
        await proxyManager.setAsSystemProxy(
          ProxyTypes.socks,
          Constants.localhost,
          port,
        );
      } else {
        await proxyManager.setAsSystemProxy(
          ProxyTypes.http,
          Constants.localhost,
          port,
        );
        await proxyManager.setAsSystemProxy(
          ProxyTypes.https,
          Constants.localhost,
          port,
        );
      }
      systemProxy = true;
    }
  }

  /// 关闭代理
  @action
  Future<void> closeProxy() async {
    if (Constants.isDesktop) {
      proxyManager.cleanSystemProxy();
      systemProxy = false;
    }
  }
}

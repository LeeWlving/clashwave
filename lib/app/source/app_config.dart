import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:clash_for_flutter/app/bean/clash_for_me_config_bean.dart';
import 'package:clash_for_flutter/app/bean/profile_base_bean.dart';
import 'package:clash_for_flutter/app/bean/profile_url_bean.dart';
import 'package:clash_for_flutter/app/exceptions/message_exception.dart';
import 'package:clash_for_flutter/app/source/core_config.dart';
import 'package:clash_for_flutter/app/source/request.dart';
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
    reaction((_) => selectedFile, (String? file) {
      if (file == null) {
        return;
      }

      if (!File(file).isAbsolute) {
        file = "$profilesPath/$file";
      }
      _request.changeConfig(file);
    });
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

import 'dart:io';

import 'package:clash_for_flutter/app/bean/config_bean.dart';
import 'package:clash_for_flutter/app/bean/tun_bean.dart';
import 'package:clash_for_flutter/app/enum/type_enum.dart';
import 'package:clash_for_flutter/app/source/request.dart';
import 'package:clash_for_flutter/app/source/logs_subscription.dart';
import 'package:clash_for_flutter/app/utils/constants.dart';
import 'package:clash_for_flutter/core_control.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:mobx/mobx.dart';

part 'core_config.g.dart';

class CoreConfig = CoreConfigBase with _$CoreConfig;

abstract class CoreConfigBase with Store {
  final _request = Modular.get<Request>();

  @observable
  Config clash = Config.defaultConfig();

  @computed
  bool get tunEnable => clash.tun?.enable ?? false;

  @computed
  int get mixedPort => clash.mixedPort ?? 0;

  @action
  setState({
    int? redirPort,
    int? tproxyPort,
    int? mixedPort,
    bool? allowLan,
    Mode? mode,
    LogLevel? logLevel,
    bool? ipv6,
  }) async {
    final updated = clash.copyWith(
      redirPort: redirPort,
      tproxyPort: tproxyPort,
      mixedPort: mixedPort,
      allowLan: allowLan,
      mode: mode,
      logLevel: logLevel,
      ipv6: ipv6,
    );
    // Only explicit edits write configuration; reading core state is read-only.
    await _request.patchConfigs(updated);
    await updated.saveFile();
    clash = updated;
  }

  @action
  Future<void> asyncConfig() async {
    final updated = await _request.getConfigs() ?? clash;
    if (Platform.isAndroid) {
      clash = updated.copyWith(
        tun: Tun(enable: await CoreControl.isVpnRunning()),
      );
    } else {
      clash = updated;
    }
  }

  Future<void> openTun() async {
    if (Constants.isDesktop) {
      final promoted = await CoreControl.ensurePrivilegedDesktopCore();
      if (promoted) {
        await Future<void>.delayed(const Duration(milliseconds: 200));
        Modular.get<LogsSubscription>().reconnect();
      }
      await _request.patchConfigs(Config(tun: Tun(enable: true)));
    } else if (Platform.isAndroid) {
      await CoreControl.startVpn();
    }
    await asyncConfig();
  }

  Future<void> closeTun() async {
    if (Constants.isDesktop) {
      await _request.patchConfigs(Config(tun: Tun(enable: false)));
    } else if (Platform.isAndroid) {
      await CoreControl.stopVpn();
    }
    await asyncConfig();
  }
}

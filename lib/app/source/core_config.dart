import 'dart:io';

import 'package:clash_for_flutter/app/bean/config_bean.dart';
import 'package:clash_for_flutter/app/bean/tun_bean.dart';
import 'package:clash_for_flutter/app/enum/type_enum.dart';
import 'package:clash_for_flutter/app/exceptions/message_exception.dart';
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
  Future<void> setState({
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
    if (!await _request.patchConfigs(updated)) {
      throw MessageException('Mihomo 未接受该设置');
    }
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
      // The foreground service starts Mihomo and establishes TUN asynchronously. Wait briefly
      // so the dashboard reflects the real service state instead of flashing back to "off".
      for (var attempt = 0; attempt < 50; attempt++) {
        if (await CoreControl.isVpnRunning()) break;
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
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

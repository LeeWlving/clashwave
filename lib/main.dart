import 'dart:io';

import 'package:clash_for_flutter/app/app_module.dart';
import 'package:clash_for_flutter/app/app_widget.dart';
import 'package:clash_for_flutter/app/startup_app.dart';
import 'package:clash_for_flutter/app/utils/clash_custom_messages.dart';
import 'package:clash_for_flutter/core_control.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:path_provider/path_provider.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:window_manager/window_manager.dart';
import 'package:clash_for_flutter/app/bean/config_bean.dart';
import 'package:clash_for_flutter/app/bean/clash_for_me_config_bean.dart';
import 'package:clash_for_flutter/app/utils/bundled_geodata.dart';
import 'package:clash_for_flutter/app/utils/controller_auth.dart';

import 'app/utils/constants.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isAndroid) {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  if (Constants.isDesktop) {
    await windowManager.ensureInitialized();
    WindowOptions windowOptions = const WindowOptions(
      minimumSize: Size(460, 600),
      size: Size(900, 650),
      center: true,
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.hidden,
    );

    await windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

  timeago.setLocaleMessages('zh_cn', ClashCustomMessages());

  runApp(
    StartupApp(
      initialize: initializeCore,
      builder: (_) => ModularApp(module: AppModule(), child: const AppWidget()),
    ),
  );
}

Future<void> initializeCore() async {
  // 初始化 Clash
  CoreControl.init();
  await getApplicationSupportDirectory().then((dir) => Constants.homeDir = dir);
  final controller = await ControllerAuth.loadOrCreate(Constants.homeDir);
  Constants.controllerSecret = controller.secret;
  // 设置主目录
  await CoreControl.setHomeDir(Constants.homeDir);
  // Mihomo 直接提供 Clash REST API；每次启动只监听随机本地端口。
  await CoreControl.startRust(
    controller.address,
  ).then((addr) => Constants.rustAddr = addr ?? "");
  // 创建默认配置文件
  if (!(Config.fileExist() ?? false)) {
    await Config.defaultConfig().saveFile();
  }
  final appConfig = ClashForMeConfig.formFile();
  await appConfig.saveFile();
  await Config.ensureController(
    geoxUrls: appConfig.geoxUrls,
    chooseAvailablePort: Constants.isDesktop,
  );
  await BundledGeodata.install(Constants.homeDir);
  // 启动内核
  if (await CoreControl.startService() != true) {
    throw StateError('Mihomo 内核启动失败，请检查配置或端口占用后重启应用。');
  }
}

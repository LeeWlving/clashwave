import 'dart:math';

import 'package:clash_for_flutter/app/app_module.dart';
import 'package:clash_for_flutter/app/app_widget.dart';
import 'package:clash_for_flutter/app/utils/clash_custom_messages.dart';
import 'package:clash_for_flutter/core_control.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:path_provider/path_provider.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:window_manager/window_manager.dart';
import 'package:clash_for_flutter/app/bean/config_bean.dart';

import 'app/utils/constants.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

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

  // 初始化 Clash
  CoreControl.init();
  await getApplicationSupportDirectory().then((dir) => Constants.homeDir = dir);
  // 设置主目录
  await CoreControl.setHomeDir(Constants.homeDir);
  // Mihomo 直接提供 Clash REST API；每次启动只监听随机本地端口。
  await CoreControl.startRust(
    "${Constants.localhost}:${Random().nextInt(9999) + 10000}",
  ).then((addr) => Constants.rustAddr = addr ?? "");
  // 创建默认配置文件
  if (!(Config.fileExist() ?? false)) {
    await Config.defaultConfig().saveFile();
  }
  await Config.ensureController();
  // 启动内核
  await CoreControl.startService();

  runApp(ModularApp(module: AppModule(), child: const AppWidget()));
}

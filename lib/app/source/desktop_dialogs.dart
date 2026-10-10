import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';

/// macOS dialogs are app-modal panels, independent of the dashboard window.
class DesktopDialogs {
  static const channel = MethodChannel('io.qzz.wenyun/desktop-dialogs');

  static Future<bool?> loginStatus() => channel.invokeMethod<bool>('loginStatus');

  static Future<bool?> setLoginEnabled(bool enabled) =>
      channel.invokeMethod<bool>('setLoginEnabled', {'enabled': enabled});

  static Future<String?> pickProfileFile() async {
    if (Platform.isMacOS) {
      return channel.invokeMethod<String>('pickProfileFile');
    }
    final files = await FilePicker.pickFiles(
      dialogTitle: '导入 YAML 配置文件',
      type: FileType.custom,
      allowedExtensions: ['yaml', 'yml'],
    );
    return files.isEmpty ? null : files.first.path;
  }

  static Future<String?> prompt({
    required String title,
    String message = '',
    String value = '',
  }) => channel.invokeMethod<String>('prompt', {
    'title': title, 'message': message, 'value': value,
  });

  static Future<bool> confirm(String title, String message) async =>
      await channel.invokeMethod<bool>('confirm', {
        'title': title, 'message': message,
      }) ?? false;

  static Future<void> message(String title, String message) =>
      channel.invokeMethod<void>('message', {'title': title, 'message': message});
}

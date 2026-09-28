import 'dart:io';

import 'package:clash_for_flutter/app/exceptions/message_exception.dart';
import 'package:yaml/yaml.dart';

/// Performs a side-effect free first-pass validation before a downloaded
/// subscription is allowed to replace the last known-good file.
class SubscriptionValidation {
  const SubscriptionValidation._();

  static Future<void> validateFile(File file) async {
    if (!await file.exists() || await file.length() == 0) {
      throw MessageException('订阅内容为空');
    }
    final content = await file.readAsString();
    validateText(content);
  }

  static void validateText(String content) {
    final trimmed = content.trimLeft();
    if (trimmed.isEmpty) throw MessageException('订阅内容为空');
    if (trimmed.startsWith('<!DOCTYPE') || trimmed.startsWith('<html')) {
      throw MessageException('订阅地址返回了网页，而不是 Mihomo YAML 配置');
    }

    final Object? document;
    try {
      document = loadYaml(content);
    } on YamlException catch (error) {
      throw MessageException('订阅 YAML 格式错误：${error.message}');
    }
    if (document is! YamlMap) {
      throw MessageException('订阅根节点必须是 YAML 对象');
    }

    const usableKeys = {
      'proxies',
      'proxy-providers',
      'listeners',
      'rules',
      'rule-providers',
    };
    if (!document.keys.any((key) => usableKeys.contains(key.toString()))) {
      throw MessageException('订阅中未找到代理、代理提供者或规则配置');
    }
  }
}

import 'dart:io';

import 'package:clash_for_flutter/app/source/desktop_dialogs.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final calls = <MethodCall>[];
  Object? response;
  setUp(() {
    calls.clear();
    response = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      DesktopDialogs.channel, (call) async {
        calls.add(call);
        return response;
      },
    );
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(DesktopDialogs.channel, null);
  });

  test('cancelled native prompts and confirmations do not supply an action value', () async {
    expect(await DesktopDialogs.prompt(title: '添加订阅'), isNull);
    expect(await DesktopDialogs.confirm('移除配置', '确认移除？'), isFalse);
    expect(calls.map((call) => call.method), ['prompt', 'confirm']);
  });

  test('native prompt keeps unicode values and errors use an independent alert', () async {
    response = '新名称';
    expect(await DesktopDialogs.prompt(title: '重命名', value: '旧名称'), '新名称');
    expect(calls.single.arguments, {'title': '重命名', 'message': '', 'value': '旧名称'});
    response = null;
    await DesktopDialogs.message('操作失败', '保留原配置');
    expect(calls.last.method, 'message');
  });

  test('macOS native file panel cancellation returns no imported file', () async {
    expect(await DesktopDialogs.pickProfileFile(), isNull);
    expect(calls.single.method, 'pickProfileFile');
  }, skip: !Platform.isMacOS);
}

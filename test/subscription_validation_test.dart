import 'dart:io';

import 'package:clash_for_flutter/app/bean/profile_url_bean.dart';
import 'package:clash_for_flutter/app/exceptions/message_exception.dart';
import 'package:clash_for_flutter/app/source/request.dart';
import 'package:clash_for_flutter/app/utils/constants.dart';
import 'package:clash_for_flutter/app/utils/subscription_validation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('accepts a Mihomo YAML subscription', () {
    expect(
      () => SubscriptionValidation.validateText('''
proxies:
  - name: DIRECT
    type: direct
proxy-groups:
  - name: Proxy
    type: select
    proxies: [DIRECT]
rules:
  - MATCH,Proxy
'''),
      returnsNormally,
    );
  });

  test('rejects HTML and unrelated YAML', () {
    expect(
      () => SubscriptionValidation.validateText('<html>login</html>'),
      throwsA(isA<MessageException>()),
    );
    expect(
      () => SubscriptionValidation.validateText('message: unauthorized'),
      throwsA(isA<MessageException>()),
    );
  });

  test('failed download never commits a profile file', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final directory = await Directory.systemTemp.createTemp(
      'clashwave-invalid-sub-',
    );
    server.listen((request) async {
      request.response
        ..statusCode = HttpStatus.ok
        ..write('<html>expired subscription</html>');
      await request.response.close();
    });
    Constants.rustAddr = '127.0.0.1:${server.port}';

    try {
      final profile = ProfileURL.emptyBean()
        ..url = 'http://${Constants.rustAddr}/subscription';
      await expectLater(
        Request().getSubscribe(profile: profile, profilesDir: directory.path),
        throwsA(isA<MessageException>()),
      );
      expect(directory.listSync(), isEmpty);
    } finally {
      await server.close(force: true);
      await directory.delete(recursive: true);
    }
  });
}

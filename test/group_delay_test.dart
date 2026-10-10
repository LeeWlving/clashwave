import 'dart:convert';
import 'dart:io';

import 'package:clash_for_flutter/app/source/request.dart';
import 'package:clash_for_flutter/app/utils/constants.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = null;
  late HttpServer server;
  Uri? received;
  String? authorization;
  setUpAll(() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    Constants.rustAddr = '127.0.0.1:${server.port}';
    Constants.controllerSecret = 'group-delay-test-secret';
    server.listen((request) async {
      received = request.uri;
      authorization = request.headers.value(HttpHeaders.authorizationHeader);
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode({'香港': 28, '日本': 0}));
      await request.response.close();
    });
  });
  tearDownAll(() => server.close(force: true));

  test('group tests use the policy-group API and safely encode names and test URLs', () async {
    const group = '自动 / 选择#1';
    const url = 'https://example.com/generate_204?region=hk&check=1';
    final delays = await Request().getGroupDelay(group, url);
    expect(received!.pathSegments, ['group', group, 'delay']);
    expect(received!.queryParameters, {'timeout': '2900', 'url': url});
    expect(authorization, 'Bearer ${Constants.controllerSecret}');
    expect(delays, {'香港': 28, '日本': 0});
  });
}

import 'dart:io';

import 'package:clash_for_flutter/app/bean/profile_url_bean.dart';
import 'package:clash_for_flutter/app/exceptions/message_exception.dart';
import 'package:clash_for_flutter/app/source/request.dart';
import 'package:clash_for_flutter/app/utils/constants.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(() => Constants.rustAddr = '127.0.0.1:1');

  late HttpServer server;
  late Directory directory;
  late List<String> agents;

  setUp(() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    directory = await Directory.systemTemp.createTemp('clashwave-sub-download-');
    agents = [];
  });
  tearDown(() async {
    await server.close(force: true);
    await directory.delete(recursive: true);
  });

  ProfileURL profile() => ProfileURL.emptyBean()
    ..url = 'http://127.0.0.1:${server.port}/subscribe?token=test-secret';

  void respond(int Function(String agent) status) {
    server.listen((request) async {
      final agent = request.headers.value(HttpHeaders.userAgentHeader) ?? '';
      agents.add(agent);
      final code = status(agent);
      request.response.statusCode = code;
      if (code == HttpStatus.ok) {
        request.response.headers.set('profile-update-interval', 'not-a-number');
        request.response.write('proxies: []\nrules: [MATCH,DIRECT]\n');
      } else {
        // Neither response bodies nor credential-bearing URLs may appear in
        // the UI error, including a server that echoes the request URI.
        request.response.write('denied ${request.uri}');
      }
      await request.response.close();
    });
  }

  test('403 retries a recognized client and preserves the configured agent', () async {
    respond((agent) => agents.length == 1 ? HttpStatus.forbidden : HttpStatus.ok);
    final request = Request()..setSubscriptionUserAgent('ProviderRequired/2.0');
    final downloaded = await request.getSubscribe(
      profile: profile(), profilesDir: directory.path,
    );
    expect(agents, ['ProviderRequired/2.0', 'mihomo/1.19.31']);
    expect(downloaded.interval, 0);
    expect(await File('${directory.path}/${downloaded.file}').exists(), isTrue);
    expect(directory.listSync().where((file) => file.path.endsWith('.part')), isEmpty);

    await request.getSubscribe(profile: profile(), profilesDir: directory.path);
    expect(agents.last, 'ProviderRequired/2.0');
  });

  test('legacy ClashX fallback can complete a subscription', () async {
    respond((agent) => agent.startsWith('ClashX/') ? HttpStatus.ok : HttpStatus.forbidden);
    await Request().getSubscribe(profile: profile(), profilesDir: directory.path);
    expect(agents.length, 3);
    expect(agents.last, 'ClashX/1.116.1');
    expect(directory.listSync(), hasLength(1));
  });

  for (final status in [HttpStatus.forbidden, HttpStatus.unauthorized, HttpStatus.notFound]) {
    test('HTTP $status leaves no files or credential-bearing error', () async {
      respond((_) => status);
      await expectLater(
        Request().getSubscribe(profile: profile(), profilesDir: directory.path),
        throwsA(isA<MessageException>()
          .having((error) => error.toString(), 'status', contains('HTTP $status'))
          .having((error) => error.toString(), 'no token', isNot(contains('test-secret')))
          .having((error) => error.toString(), 'no URL', isNot(contains('127.0.0.1')))),
      );
      expect(agents.length, status == HttpStatus.forbidden ? 3 : 1);
      expect(directory.listSync(), isEmpty);
    });
  }
}

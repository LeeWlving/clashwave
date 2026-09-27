import 'dart:convert';
import 'dart:io';

import 'package:clash_for_flutter/app/bean/clash_for_me_config_bean.dart';
import 'package:clash_for_flutter/app/bean/config_bean.dart';
import 'package:clash_for_flutter/app/source/request.dart';
import 'package:clash_for_flutter/app/utils/bundled_geodata.dart';
import 'package:clash_for_flutter/app/utils/constants.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yaml_edit/yaml_edit.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // These integration tests use an actual loopback HTTP server.
  HttpOverrides.global = null;
  late Directory home;
  late HttpServer server;
  var port = 0;
  var patches = 0;
  String? loadedProfile;

  setUpAll(() async {
    home = await Directory.systemTemp.createTemp('clashwave-core-test-');
    Constants.homeDir = home;
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    Constants.rustAddr = '127.0.0.1:${server.port}';
    server.listen((request) async {
      request.response.headers.contentType = ContentType.json;
      if (request.method == 'GET') {
        request.response.write(jsonEncode({'mixed-port': port}));
      } else {
        final body = jsonDecode(await utf8.decoder.bind(request).join()) as Map;
        if (request.method == 'PUT') {
          loadedProfile = body['payload'] as String;
          port =
              YamlEditor(loadedProfile!).parseAt(['mixed-port']).value as int;
        } else {
          patches++;
          port = body['mixed-port'] as int;
        }
        request.response.statusCode = HttpStatus.noContent;
      }
      await request.response.close();
    });
  });

  tearDownAll(() async {
    await server.close(force: true);
    await home.delete(recursive: true);
  });

  test(
    'repairs a disabled saved port and preserves a custom valid port',
    () async {
      final file = File('${home.path}/config.yaml');
      await file.writeAsString('mixed-port: 0\nrules: [MATCH,DIRECT]\n');
      await Config.ensureController();
      expect(
        YamlEditor(await file.readAsString()).parseAt(['mixed-port']).value,
        7890,
      );
      await file.writeAsString('mixed-port: 17890\n');
      await Config.ensureController();
      expect(
        YamlEditor(await file.readAsString()).parseAt(['mixed-port']).value,
        17890,
      );
    },
  );

  test(
    'reload overlays port and mirror before rules are parsed, without editing subscription',
    () async {
      port = 17890;
      final settings = ClashForMeConfig.defaultConfig().copyWith(
        mmdbUrl: 'https://mirror.example/country.mmdb',
        geodataBaseUrl: 'https://mirror.example',
      );
      await settings.saveFile();
      final file = File('${home.path}/subscription.yaml');
      const source = 'mixed-port: 0\nrules: ["MATCH,DIRECT"]\n';
      await file.writeAsString(source);
      expect(await Request().changeConfig(file.path), isTrue);
      final yaml = YamlEditor(loadedProfile!);
      expect(yaml.parseAt(['mixed-port']).value, 17890);
      expect(yaml.parseAt(['geox-url', 'mmdb']).value, settings.mmdbUrl);
      expect(yaml.parseAt(['geox-url', 'geosite']).value, settings.geositeUrl);
      expect(yaml.parseAt(['rules']).value, ['MATCH,DIRECT']);
      expect(await file.readAsString(), source);
    },
  );

  test(
    'enabling proxy repairs live zero port and reads back the result',
    () async {
      port = 0;
      patches = 0;
      final selectedPort = await Request().ensureMixedPort();
      expect(selectedPort, inInclusiveRange(1, 65535));
      expect(port, selectedPort);
      expect(patches, 1);
      port = 17890;
      patches = 0;
      expect(await Request().ensureMixedPort(), 17890);
      expect(patches, 0);
    },
  );

  test(
    'bundled databases install offline without overwriting existing updates',
    () async {
      final dataHome = await Directory('${home.path}/data').create();
      await BundledGeodata.install(dataHome, bundle: rootBundle);
      for (final name in BundledGeodata.files) {
        expect(
          await File('${dataHome.path}/$name').length(),
          greaterThan(1000),
        );
      }
      final existing = File('${dataHome.path}/Country.mmdb');
      final bytes = await existing.readAsBytes();
      final changed = [...bytes, 1];
      await existing.writeAsBytes(changed);
      await BundledGeodata.install(dataHome, bundle: rootBundle);
      expect(await existing.readAsBytes(), changed);
    },
  );
}

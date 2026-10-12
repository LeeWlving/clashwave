import 'dart:io';

import 'package:clash_for_flutter/app/exceptions/message_exception.dart';
import 'package:clash_for_flutter/app/source/profile_importer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory root;
  late File source;
  late String profiles;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('clashwave-file-import-');
    source = File(p.join(root.path, 'local.yml'));
    profiles = p.join(root.path, 'profiles');
  });
  tearDown(() => root.delete(recursive: true));

  test('valid local YAML is copied and the original is never modified', () async {
    const yaml = 'proxies: []\nrules: ["MATCH,DIRECT"]\n';
    await source.writeAsString(yaml);
    final imported = await ProfileImporter.fromFile(source.path, profiles);
    expect(imported.name, 'local.yml');
    expect(imported.path, source.path);
    expect(await File(p.join(profiles, imported.file)).readAsString(), yaml);
    expect(await source.readAsString(), yaml);
    expect(
      Directory(profiles).listSync().map((file) => file.path),
      [p.join(profiles, imported.file)],
    );
  });

  test('invalid files are rejected and leave no partial imported config', () async {
    const html = '<html>not a config</html>';
    await source.writeAsString(html);
    await expectLater(ProfileImporter.fromFile(source.path, profiles), throwsA(isA<MessageException>()));
    expect(Directory(profiles).listSync(), isEmpty);
    expect(await source.readAsString(), html);
  });

  test('an unreadable selection leaves no empty profile or partial file', () async {
    await expectLater(ProfileImporter.fromFile(source.path, profiles), throwsA(isA<FileSystemException>()));
    expect(Directory(profiles).listSync(), isEmpty);
  });
}

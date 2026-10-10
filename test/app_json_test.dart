import 'dart:io';

import 'package:clash_for_flutter/app/bean/clash_for_me_config_bean.dart';
import 'package:clash_for_flutter/app/bean/config_bean.dart';
import 'package:clash_for_flutter/app/bean/profile_base_bean.dart';
import 'package:clash_for_flutter/app/bean/profile_file_bean.dart';
import 'package:clash_for_flutter/app/bean/group_bean.dart';
import 'package:clash_for_flutter/app/bean/profile_url_bean.dart';
import 'package:clash_for_flutter/app/bean/proxies_bean.dart';
import 'package:clash_for_flutter/app/bean/proxy_bean.dart';
import 'package:clash_for_flutter/app/enum/type_enum.dart';
import 'package:clash_for_flutter/app/utils/app_json.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('decodes Mihomo proxies and groups', () {
    final proxies = AppJson.fromJson<Proxies>('''
      {
        "proxies": {
          "DIRECT": {"name": "DIRECT", "type": "Direct"},
          "Auto": {
            "name": "Auto",
            "type": "URLTest",
            "all": ["DIRECT"],
            "now": "DIRECT",
            "history": [{"time": "2026-01-01T00:00:00Z", "delay": 12}]
          }
        }
      }
    ''')!;

    expect(proxies.proxies['DIRECT'], isA<Proxy>());
    final group = proxies.proxies['Auto'] as Group;
    expect(group.type, GroupType.URLTest);
    expect(group.now, 'DIRECT');
    expect(group.history!.single.delay, 12);
  });

  test('round-trips core config', () {
    final source = Config(
      mixedPort: 7890,
      allowLan: false,
      mode: Mode.Rule,
      logLevel: LogLevel.info,
      ipv6: true,
    );

    final decoded = AppJson.fromJson<Config>(AppJson.encode(source))!;
    expect(decoded.mixedPort, 7890);
    expect(decoded.allowLan, isFalse);
    expect(decoded.mode, Mode.Rule);
    expect(decoded.logLevel, LogLevel.info);
    expect(decoded.ipv6, isTrue);
  });

  test('round-trips persisted subscription settings', () {
    final profile = ProfileURL(
      file: 'sample.yaml',
      name: 'Sample',
      time: DateTime.utc(2026, 1, 2),
      url: 'https://leewlving.github.io/clashwave/sample.yaml',
      interval: 24,
    );
    final source = ClashForMeConfig(
      selectedFile: profile.file,
      profiles: [profile],
      mmdbUrl: 'https://leewlving.github.io/clashwave/country.mmdb',
      delayTestUrl: 'https://www.gstatic.com/generate_204',
      subscriptionUserAgent: 'ClashWave/test',
      tunIf: true,
      lightMode: true, showTraySpeed: false, sortProxiesByDelay: true, autoUpdateSubscriptions: false,
    );

    final decoded = AppJson.fromJson<ClashForMeConfig>(AppJson.encode(source))!;
    final decodedProfile = decoded.profiles.single as ProfileURL;
    expect(decoded.selectedFile, 'sample.yaml');
    expect(
      decodedProfile.url,
      'https://leewlving.github.io/clashwave/sample.yaml',
    );
    expect(decodedProfile.interval, 24);
    expect(decoded.subscriptionUserAgent, 'ClashWave/test');
    expect(decoded.tunIf, isTrue);
    expect(decoded.lightMode, isTrue);
    expect(decoded.showTraySpeed, isFalse);
    expect(decoded.sortProxiesByDelay, isTrue);
    expect(decoded.autoUpdateSubscriptions, isFalse);
    final edited = decoded.copyWith(delayTestUrl: 'https://example.com/test');
    expect(edited.lightMode, isTrue);
    expect(edited.showTraySpeed, isFalse);
    expect(edited.sortProxiesByDelay, isTrue);
    expect(edited.autoUpdateSubscriptions, isFalse);
  });
  test('renaming a file profile preserves its source and does not mutate the snapshot', () {
    final original = ProfileFile.emptyBean()..file = 'local.yaml'..name = 'Original'..path = '/tmp/local.yml';
    final copy = AppJson.fromJson<ProfileBase>(AppJson.encode(original))!;
    copy.name = 'Renamed';
    expect(copy, isA<ProfileFile>());
    expect((copy as ProfileFile).path, original.path);
    expect(copy.file, original.file);
    expect(original.name, 'Original');
  });

  test('legacy settings use macOS menu-bar startup and explicit GUI preferences survive decoding', () {
    final legacy = AppJson.fromMap<ClashForMeConfig>({
      'profiles': [], 'mmdb-url': 'https://example.com/country.mmdb',
      'delay-test-url': 'https://example.com/test',
    })!;
    expect(legacy.lightMode, Platform.isMacOS);
    expect(legacy.autoUpdateSubscriptions, isTrue);
    expect(legacy.showTraySpeed, isTrue);
    final withGui = legacy.copyWith(lightMode: false);
    final restored = AppJson.fromJson<ClashForMeConfig>(AppJson.encode(withGui))!;
    expect(restored.lightMode, isFalse);
  });

}

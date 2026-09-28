import 'package:clash_for_flutter/app/bean/clash_for_me_config_bean.dart';
import 'package:clash_for_flutter/app/bean/config_bean.dart';
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
      url: 'https://clashwave.wenyun.qzz.io/sample.yaml',
      interval: 24,
    );
    final source = ClashForMeConfig(
      selectedFile: profile.file,
      profiles: [profile],
      mmdbUrl: 'https://clashwave.wenyun.qzz.io/country.mmdb',
      delayTestUrl: 'https://www.gstatic.com/generate_204',
      subscriptionUserAgent: 'ClashWave/test',
      tunIf: true,
    );

    final decoded = AppJson.fromJson<ClashForMeConfig>(AppJson.encode(source))!;
    final decodedProfile = decoded.profiles.single as ProfileURL;
    expect(decoded.selectedFile, 'sample.yaml');
    expect(decodedProfile.url, 'https://clashwave.wenyun.qzz.io/sample.yaml');
    expect(decodedProfile.interval, 24);
    expect(decoded.subscriptionUserAgent, 'ClashWave/test');
    expect(decoded.tunIf, isTrue);
  });
}

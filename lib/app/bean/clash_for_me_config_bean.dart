import 'dart:convert';
import 'dart:io';

import 'package:clash_for_flutter/app/bean/profile_base_bean.dart';
import 'package:clash_for_flutter/app/utils/app_json.dart';
import 'package:clash_for_flutter/app/utils/constants.dart';

/// 软件配置
class ClashForMeConfig {
  static final File _file = File(
    "${Constants.homeDir.path}${Constants.clashForMe}",
  );

  /// 选择的配置文件
  String? selectedFile;

  /// 源配置
  List<ProfileBase> profiles;

  /// mmdb 下载地址
  String mmdbUrl;
  String geodataBaseUrl;

  String get geositeUrl => '$geodataBaseUrl/geosite.dat';

  Map<String, String> get geoxUrls => {
    'mmdb': mmdbUrl,
    'geosite': geositeUrl,
    'geoip': '$geodataBaseUrl/geoip.dat',
    'asn': '$geodataBaseUrl/GeoLite2-ASN.mmdb',
  };

  /// 延迟测试地址
  String delayTestUrl;

  /// 是否以 Tun 模式运行
  bool? tunIf;

  ClashForMeConfig({
    this.selectedFile,
    required this.profiles,
    required this.mmdbUrl,
    this.geodataBaseUrl = DefaultConfigValue.geodataBaseUrl,
    required this.delayTestUrl,
    this.tunIf,
  });

  ClashForMeConfig copyWith({
    String? selectedFile,
    List<ProfileBase>? profiles,
    String? mmdbUrl,
    String? geodataBaseUrl,
    String? delayTestUrl,
    bool? tunIf,
  }) {
    var config = ClashForMeConfig(
      selectedFile: selectedFile ?? this.selectedFile,
      profiles: profiles ?? this.profiles,
      mmdbUrl: mmdbUrl ?? this.mmdbUrl,
      geodataBaseUrl: geodataBaseUrl ?? this.geodataBaseUrl,
      delayTestUrl: delayTestUrl ?? this.delayTestUrl,
      tunIf: tunIf ?? this.tunIf,
    );
    // 对当前选择的订阅进行优化
    var selectElements = config.profiles.where(
      (e) => e.file == config.selectedFile,
    );
    if (selectElements.isEmpty) {
      if (config.profiles.isEmpty) {
        config.selectedFile = null;
      } else {
        config.selectedFile = config.profiles.first.file;
      }
    }
    return config;
  }

  Future<void> saveFile() {
    return _file
        .create(recursive: true)
        .then((file) => file.writeAsString(AppJson.encode(this)));
  }

  factory ClashForMeConfig.defaultConfig() => ClashForMeConfig(
    profiles: [],
    mmdbUrl: DefaultConfigValue.mmdbUrl,
    delayTestUrl: DefaultConfigValue.delayTestUrl,
  );

  factory ClashForMeConfig.formFile() {
    var clashForMeFile = _file;
    if (clashForMeFile.existsSync()) {
      Map<String, dynamic> cfm = json.decode(clashForMeFile.readAsStringSync());

      // 对必填项赋予默认值
      cfm.putIfAbsent("mmdb-url", () => DefaultConfigValue.mmdbUrl);
      // Migrate the old default only; preserve user-supplied download URLs.
      if (cfm['mmdb-url'] ==
          'https://github.com/MetaCubeX/meta-rules-dat/releases/download/latest/country.mmdb') {
        cfm['mmdb-url'] = DefaultConfigValue.mmdbUrl;
      }
      cfm.putIfAbsent("delay-test-url", () => DefaultConfigValue.delayTestUrl);

      return AppJson.fromMap<ClashForMeConfig>(cfm)!;
    }
    return ClashForMeConfig.defaultConfig();
  }
}

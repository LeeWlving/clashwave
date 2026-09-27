import 'dart:io';

import 'package:clash_for_flutter/app/bean/tun_bean.dart';
import 'package:clash_for_flutter/app/enum/type_enum.dart';
import 'package:clash_for_flutter/app/utils/constants.dart';
import 'package:yaml_edit/yaml_edit.dart';

class Config {
  static final String _path =
      "${Constants.homeDir.path}${Constants.clashConfig}";

  int? mixedPort;
  int? redirPort;
  int? tproxyPort;
  bool? allowLan;
  Mode? mode;
  LogLevel? logLevel;
  bool? ipv6;
  Tun? tun;

  get tunEnable => tun?.enable;

  Config({
    this.mixedPort,
    this.redirPort,
    this.tproxyPort,
    this.allowLan,
    this.mode,
    this.logLevel,
    this.ipv6,
    this.tun,
  });

  Future<void> saveFile() async {
    final yaml = _loadYaml();
    if (redirPort != null) yaml.update(["redir-port"], redirPort);
    if (tproxyPort != null) yaml.update(["tproxy-port"], tproxyPort);
    if (mixedPort != null) yaml.update(["mixed-port"], mixedPort);
    if (allowLan != null) yaml.update(["allow-lan"], allowLan);
    if (mode != null) yaml.update(["mode"], mode!.value);
    if (logLevel != null) yaml.update(["log-level"], logLevel!.value);
    if (ipv6 != null) yaml.update(["ipv6"], ipv6);
    await _saveYaml(yaml);
  }

  /// Keeps Mihomo's Clash-compatible controller on the random loopback port
  /// selected for this app launch, without changing the user's other options.
  static Future<void> ensureController() async {
    final yaml = _loadYaml();
    yaml.update(["external-controller"], Constants.rustAddr);
    await _saveYaml(yaml);
  }

  static YamlEditor _loadYaml() {
    final file = File(_path);
    final source = file.existsSync() ? file.readAsStringSync() : '{}\n';
    return YamlEditor(source.trim().isEmpty ? '{}\n' : source);
  }

  static Future<void> _saveYaml(YamlEditor yaml) async {
    final file = await File(_path).create(recursive: true);
    await file.writeAsString('${yaml.toString()}\n');
  }

  Config copyWith({
    int? redirPort,
    int? tproxyPort,
    int? mixedPort,
    bool? allowLan,
    Mode? mode,
    LogLevel? logLevel,
    bool? ipv6,
  }) {
    return Config(
      redirPort: redirPort ?? this.redirPort,
      tproxyPort: tproxyPort ?? this.tproxyPort,
      mixedPort: mixedPort ?? this.mixedPort,
      allowLan: allowLan ?? this.allowLan,
      mode: mode ?? this.mode,
      logLevel: logLevel ?? this.logLevel,
      ipv6: ipv6 ?? this.ipv6,
    );
  }

  Config copy(Config? that) {
    that ??= this;
    return Config(
      redirPort: that.redirPort,
      tproxyPort: that.tproxyPort,
      mixedPort: that.mixedPort,
      allowLan: that.allowLan,
      mode: that.mode,
      logLevel: that.logLevel,
      ipv6: that.ipv6,
      tun: that.tun,
    );
  }

  static bool? fileExist() => File(_path).existsSync();

  factory Config.defaultConfig() => Config(mixedPort: 7890);
}

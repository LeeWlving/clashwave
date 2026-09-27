import 'dart:convert';

import 'package:clash_for_flutter/app/bean/clash_for_me_config_bean.dart';
import 'package:clash_for_flutter/app/bean/config_bean.dart';
import 'package:clash_for_flutter/app/bean/connection_bean.dart';
import 'package:clash_for_flutter/app/bean/group_bean.dart';
import 'package:clash_for_flutter/app/bean/history_bean.dart';
import 'package:clash_for_flutter/app/bean/log_bean.dart';
import 'package:clash_for_flutter/app/bean/net_speed.dart';
import 'package:clash_for_flutter/app/bean/profile_base_bean.dart';
import 'package:clash_for_flutter/app/bean/profile_file_bean.dart';
import 'package:clash_for_flutter/app/bean/profile_url_bean.dart';
import 'package:clash_for_flutter/app/bean/provider_bean.dart';
import 'package:clash_for_flutter/app/bean/proxies_bean.dart';
import 'package:clash_for_flutter/app/bean/proxy_bean.dart';
import 'package:clash_for_flutter/app/bean/proxy_providers_bean.dart';
import 'package:clash_for_flutter/app/bean/sub_userinfo_bean.dart';
import 'package:clash_for_flutter/app/bean/tun_bean.dart';
import 'package:clash_for_flutter/app/enum/type_enum.dart';

/// Explicit JSON codec for the Mihomo REST API and persisted app settings.
///
/// The old project used runtime reflection through dart_json_mapper. Explicit
/// parsing is compatible with current Dart releases and makes API drift fail
/// in one well-defined place.
class AppJson {
  const AppJson._();

  static T? fromJson<T>(Object? source) {
    final value = source is String ? jsonDecode(source) : source;
    return fromMap<T>(_asMap(value));
  }

  static T? fromMap<T>(Map<String, dynamic>? map) {
    if (map == null) return null;
    final Object? value;
    if (T == Proxies) {
      value = _proxies(map);
    } else if (T == Group) {
      value = _group(map);
    } else if (T == Proxy) {
      value = _proxy(map);
    } else if (T == Config) {
      value = _config(map);
    } else if (T == ProxyProviders) {
      value = _proxyProviders(map);
    } else if (T == NetSpeed) {
      value = _netSpeed(map);
    } else if (T == LogData) {
      value = _logData(map);
    } else if (T == Snapshot) {
      value = _snapshot(map);
    } else if (T == ClashForMeConfig) {
      value = _appConfig(map);
    } else if (T == ProfileURL) {
      value = _profile(map) as ProfileURL?;
    } else {
      throw UnsupportedError('No JSON decoder registered for $T');
    }
    return value as T?;
  }

  static String encode(Object value) => jsonEncode(toMap(value));

  static Map<String, dynamic> toMap(Object value) {
    if (value is Config) return _configToMap(value);
    if (value is ClashForMeConfig) return _appConfigToMap(value);
    if (value is ProfileBase) return _profileToMap(value);
    if (value is SubUserinfo) return _subUserinfoToMap(value);
    if (value is Tun) return {'enable': value.enable};
    throw UnsupportedError(
      'No JSON encoder registered for ${value.runtimeType}',
    );
  }

  static ProfileURL cloneProfileUrl(ProfileURL profile) => ProfileURL(
    file: profile.file,
    name: profile.name,
    time: profile.time,
    url: profile.url,
    interval: profile.interval,
    userinfo: profile.userinfo == null
        ? null
        : SubUserinfo(
            upload: profile.userinfo!.upload,
            download: profile.userinfo!.download,
            total: profile.userinfo!.total,
            expire: profile.userinfo!.expire,
          ),
  );

  static Proxies _proxies(Map<String, dynamic> map) {
    final raw = _asMap(map['proxies']) ?? const <String, dynamic>{};
    return Proxies(
      proxies: raw.map((name, value) {
        final proxy = _asMap(value) ?? <String, dynamic>{'name': name};
        return MapEntry(name, _proxyOrGroup(proxy));
      }),
    );
  }

  static Object _proxyOrGroup(Map<String, dynamic> map) {
    return GroupTypeValue.valueList.contains(_string(map['type']))
        ? _group(map)
        : _proxy(map);
  }

  static Group _group(Map<String, dynamic> map) {
    final group = Group(
      name: _string(map['name']),
      type: _enumByName(GroupType.values, map['type'], GroupType.Selector),
      all: _stringList(map['all']),
      now: _string(map['now']),
    );
    group.history = _historyList(map['history']);
    return group;
  }

  static Proxy _proxy(Map<String, dynamic> map) {
    final proxy = Proxy(
      name: _string(map['name']),
      type: _nullableString(map['type']),
    );
    proxy.history = _historyList(map['history']);
    return proxy;
  }

  static List<History>? _historyList(Object? value) {
    final list = _asList(value);
    if (list == null) return null;
    return list
        .map(_asMap)
        .whereType<Map<String, dynamic>>()
        .map((e) => History(time: _string(e['time']), delay: _int(e['delay'])))
        .toList();
  }

  static Config _config(Map<String, dynamic> map) => Config(
    mixedPort: _nullableInt(map['mixed-port']),
    redirPort: _nullableInt(map['redir-port']),
    tproxyPort: _nullableInt(map['tproxy-port']),
    allowLan: _nullableBool(map['allow-lan']),
    mode: _nullableEnumByName(Mode.values, map['mode']),
    logLevel: _nullableEnumByName(LogLevel.values, map['log-level']),
    ipv6: _nullableBool(map['ipv6']),
    tun: _tun(map['tun']),
  );

  static Map<String, dynamic> _configToMap(Config value) => {
    if (value.mixedPort != null) 'mixed-port': value.mixedPort,
    if (value.redirPort != null) 'redir-port': value.redirPort,
    if (value.tproxyPort != null) 'tproxy-port': value.tproxyPort,
    if (value.allowLan != null) 'allow-lan': value.allowLan,
    if (value.mode != null) 'mode': value.mode!.value,
    if (value.logLevel != null) 'log-level': value.logLevel!.value,
    if (value.ipv6 != null) 'ipv6': value.ipv6,
    if (value.tun != null) 'tun': {'enable': value.tun!.enable},
  };

  static ProxyProviders _proxyProviders(Map<String, dynamic> map) {
    final raw = _asMap(map['providers']) ?? const <String, dynamic>{};
    return ProxyProviders(
      providers: raw.map((name, value) {
        final data = _asMap(value) ?? <String, dynamic>{'name': name};
        return MapEntry(name, _provider(data));
      }),
    );
  }

  static Provider _provider(Map<String, dynamic> map) => Provider(
    name: _string(map['name']),
    proxies: (_asList(map['proxies']) ?? const [])
        .map(_asMap)
        .whereType<Map<String, dynamic>>()
        .map(_proxyOrGroup)
        .toList(),
    type: _string(map['type']),
    vehicleType: _enumByName(
      VehicleType.values,
      map['vehicleType'],
      VehicleType.Compatible,
    ),
    updatedAt: _nullableString(map['updatedAt']),
  );

  static NetSpeed _netSpeed(Map<String, dynamic> map) => NetSpeed()
    ..up = _int(map['up'])
    ..down = _int(map['down']);

  static LogData _logData(Map<String, dynamic> map) => LogData(
    type: _enumByName(LogLevel.values, map['type'], LogLevel.info),
    payload: _string(map['payload']),
  );

  static Snapshot _snapshot(Map<String, dynamic> map) => Snapshot(
    uploadTotal: _int(map['uploadTotal']),
    downloadTotal: _int(map['downloadTotal']),
    connections: (_asList(map['connections']) ?? const [])
        .map(_asMap)
        .whereType<Map<String, dynamic>>()
        .map(_connection)
        .toList(),
  );

  static Connection _connection(Map<String, dynamic> map) {
    final metadata = _asMap(map['metadata']) ?? const <String, dynamic>{};
    return Connection(
      id: _string(map['id']),
      upload: _int(map['upload']),
      download: _int(map['download']),
      start: _string(map['start']),
      chains: _stringList(map['chains']),
      rule: _string(map['rule']),
      rulePayload: _string(map['rulePayload']),
      metadata: Metadata(
        network: _string(metadata['network']),
        type: _string(metadata['type']),
        host: _string(metadata['host']),
        processPath: _string(metadata['processPath']),
        sourceIP: _string(metadata['sourceIP']),
        sourcePort: _string(metadata['sourcePort']),
        destinationIP: _string(metadata['destinationIP']),
        destinationPort: _string(metadata['destinationPort']),
        dnsMode: _string(metadata['dnsMode']),
        specialProxy: _string(metadata['specialProxy']),
      ),
    );
  }

  static ClashForMeConfig _appConfig(Map<String, dynamic> map) =>
      ClashForMeConfig(
        selectedFile: _nullableString(map['selected-file']),
        profiles: (_asList(map['profiles']) ?? const [])
            .map(_asMap)
            .whereType<Map<String, dynamic>>()
            .map(_profile)
            .whereType<ProfileBase>()
            .toList(),
        mmdbUrl: _string(map['mmdb-url']),
        delayTestUrl: _string(map['delay-test-url']),
        tunIf: _nullableBool(map['tun-if']),
      );

  static Map<String, dynamic> _appConfigToMap(ClashForMeConfig value) => {
    'selected-file': value.selectedFile,
    'profiles': value.profiles.map(_profileToMap).toList(),
    'mmdb-url': value.mmdbUrl,
    'delay-test-url': value.delayTestUrl,
    'tun-if': value.tunIf,
  };

  static ProfileBase? _profile(Map<String, dynamic> map) {
    final type = _enumByName(ProfileType.values, map['type'], ProfileType.URL);
    final file = _string(map['file']);
    final name = _string(map['name']);
    final time = DateTime.tryParse(_string(map['time'])) ?? DateTime.now();
    if (type == ProfileType.FILE) {
      return ProfileFile(
        file: file,
        name: name,
        time: time,
        path: _nullableString(map['path']),
      );
    }
    return ProfileURL(
      file: file,
      name: name,
      time: time,
      url: _string(map['url']),
      interval: _int(map['interval']),
      userinfo: _subUserinfoFromValue(map['sub-userinfo']),
    );
  }

  static Map<String, dynamic> _profileToMap(ProfileBase value) => {
    'file': value.file,
    'name': value.name,
    'type': value.type.value,
    'time': value.time.toIso8601String(),
    if (value is ProfileURL) ...{
      'url': value.url,
      'interval': value.interval,
      'sub-userinfo': value.userinfo == null
          ? null
          : _subUserinfoToMap(value.userinfo!),
    },
    if (value is ProfileFile) 'path': value.path,
  };

  static SubUserinfo _subUserinfo(Map<String, dynamic> map) => SubUserinfo(
    upload: _nullableInt(map['upload']),
    download: _nullableInt(map['download']),
    total: _nullableInt(map['total']),
    expire: _nullableInt(map['expire']),
  );

  static Tun? _tun(Object? value) {
    final map = _asMap(value);
    return map == null ? null : Tun(enable: _nullableBool(map['enable']));
  }

  static SubUserinfo? _subUserinfoFromValue(Object? value) {
    final map = _asMap(value);
    return map == null ? null : _subUserinfo(map);
  }

  static Map<String, dynamic> _subUserinfoToMap(SubUserinfo value) => {
    'upload': value.upload,
    'download': value.download,
    'total': value.total,
    'expire': value.expire,
  };

  static Map<String, dynamic>? _asMap(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((key, item) => MapEntry(key.toString(), item));
    }
    return null;
  }

  static List<dynamic>? _asList(Object? value) => value is List ? value : null;
  static String _string(Object? value) => value?.toString() ?? '';
  static String? _nullableString(Object? value) =>
      value == null ? null : value.toString();
  static int _int(Object? value) => _nullableInt(value) ?? 0;
  static int? _nullableInt(Object? value) =>
      value is num ? value.toInt() : int.tryParse('$value');
  static bool? _nullableBool(Object? value) => value is bool ? value : null;
  static List<String> _stringList(Object? value) =>
      (_asList(value) ?? const []).map(_string).toList();

  static E _enumByName<E extends Enum>(
    List<E> values,
    Object? value,
    E fallback,
  ) {
    return _nullableEnumByName(values, value) ?? fallback;
  }

  static E? _nullableEnumByName<E extends Enum>(List<E> values, Object? value) {
    final name = _nullableString(value);
    if (name == null) return null;
    for (final item in values) {
      if (item.name.toLowerCase() == name.toLowerCase()) return item;
    }
    return null;
  }
}

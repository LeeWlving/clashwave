import 'dart:io';

import 'package:flutter/services.dart';

/// Seed missing databases before Mihomo parses any GEOIP/GEOSITE rules.
class BundledGeodata {
  static const files = ['Country.mmdb', 'GeoSite.dat', 'GeoIP.dat'];

  static Future<void> install(Directory home, {AssetBundle? bundle}) async {
    await home.create(recursive: true);
    for (final name in files) {
      final destination = File('${home.path}/$name');
      if (await destination.exists() && await destination.length() > 0) {
        continue;
      }
      final data = await (bundle ?? rootBundle).load('assets/geodata/$name');
      if (data.lengthInBytes == 0) throw StateError('内置规则数据库为空：$name');
      final temporary = File('${destination.path}.bundled');
      await temporary.writeAsBytes(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        flush: true,
      );
      await temporary.rename(destination.path);
    }
  }
}

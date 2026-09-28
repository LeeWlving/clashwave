import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:clash_for_flutter/app/utils/constants.dart';

class ControllerCredentials {
  final String address;
  final String secret;

  const ControllerCredentials({required this.address, required this.secret});
}

/// Persists a stable loopback endpoint and a high-entropy Mihomo controller
/// token. A stable endpoint lets an OS-managed core outlive the GUI safely.
class ControllerAuth {
  const ControllerAuth._();

  static const _fileName = '.controller-auth.json';

  static Future<ControllerCredentials> loadOrCreate(Directory home) async {
    final file = File('${home.path}${Platform.pathSeparator}$_fileName');
    if (await file.exists()) {
      try {
        final map = jsonDecode(await file.readAsString());
        if (map is Map) {
          final port = map['port'];
          final secret = map['secret'];
          if (port is int &&
              port >= 1024 &&
              port <= 65535 &&
              secret is String &&
              secret.length >= 32) {
            return ControllerCredentials(
              address: '${Constants.localhost}:$port',
              secret: secret,
            );
          }
        }
      } catch (_) {
        // Replace malformed legacy state below.
      }
    }

    await home.create(recursive: true);
    final secure = Random.secure();
    final secret = base64Url
        .encode(List<int>.generate(32, (_) => secure.nextInt(256)))
        .replaceAll('=', '');
    final port = await _choosePort(secure);
    final partial = File('${file.path}.part');
    await partial.writeAsString(
      '${jsonEncode({'port': port, 'secret': secret})}\n',
      flush: true,
    );
    if (await file.exists()) await file.delete();
    await partial.rename(file.path);
    if (!Platform.isWindows) {
      await Process.run('chmod', ['600', file.path]);
    }
    return ControllerCredentials(
      address: '${Constants.localhost}:$port',
      secret: secret,
    );
  }

  static Future<int> _choosePort(Random secure) async {
    for (var attempt = 0; attempt < 20; attempt++) {
      final candidate = 20000 + secure.nextInt(20000);
      try {
        final socket = await ServerSocket.bind(
          InternetAddress.loopbackIPv4,
          candidate,
          shared: false,
        );
        await socket.close();
        return candidate;
      } on SocketException {
        // Try another high port.
      }
    }
    final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final port = socket.port;
    await socket.close();
    return port;
  }
}

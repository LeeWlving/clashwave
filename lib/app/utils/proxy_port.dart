import 'dart:io';

class ProxyPort {
  /// Do not displace another app's listener when the preferred port is busy.
  static Future<int> available(int preferred) async {
    ServerSocket reservation;
    try {
      reservation = await ServerSocket.bind(
        InternetAddress.loopbackIPv4,
        preferred,
      );
    } on SocketException {
      reservation = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    }
    final port = reservation.port;
    await reservation.close();
    return port;
  }
}

import 'dart:io';

import 'package:clash_for_flutter/app/utils/proxy_port.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'chooses a free port without displacing the occupied listener',
    () async {
      final occupied = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      try {
        final selected = await ProxyPort.available(occupied.port);
        expect(selected, isNot(occupied.port));
        final reservation = await ServerSocket.bind(
          InternetAddress.loopbackIPv4,
          selected,
        );
        await reservation.close();
        // The original listener must remain owned by the original process.
        await expectLater(
          ServerSocket.bind(InternetAddress.loopbackIPv4, occupied.port),
          throwsA(isA<SocketException>()),
        );
      } finally {
        await occupied.close();
      }
    },
  );

  test('preserves a preferred port when it is free', () async {
    final reservation = await ServerSocket.bind(
      InternetAddress.loopbackIPv4,
      0,
    );
    final preferred = reservation.port;
    await reservation.close();
    expect(await ProxyPort.available(preferred), preferred);
  });
}

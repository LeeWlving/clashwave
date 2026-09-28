import 'dart:io';

import 'package:clash_for_flutter/app/utils/controller_auth.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'persists stable high-entropy controller credentials atomically',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'clashwave-controller-auth-',
      );
      try {
        final first = await ControllerAuth.loadOrCreate(directory);
        final second = await ControllerAuth.loadOrCreate(directory);

        expect(first.address, second.address);
        expect(first.secret, second.secret);
        expect(first.secret.length, greaterThanOrEqualTo(32));
        expect(first.address, startsWith('127.0.0.1:'));
        expect(
          File(
            '${directory.path}${Platform.pathSeparator}.controller-auth.json',
          ).existsSync(),
          isTrue,
        );
        expect(
          File(
            '${directory.path}${Platform.pathSeparator}.controller-auth.json.part',
          ).existsSync(),
          isFalse,
        );
      } finally {
        await directory.delete(recursive: true);
      }
    },
  );
}

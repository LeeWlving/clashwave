import 'dart:async';
import 'dart:io';

import 'package:clash_for_flutter/app/source/request.dart';
import 'package:clash_for_flutter/app/utils/constants.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('cancels a download even when the server never sends headers', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final directory = await Directory.systemTemp.createTemp(
      'clashwave-download-',
    );
    final connected = Completer<void>();
    server.listen((request) => connected.complete());
    Constants.rustAddr = '127.0.0.1:${server.port}';
    final cancellation = CancelToken();
    try {
      final download = Request().downFile(
        urlPath: 'http://${Constants.rustAddr}/stalled',
        savePath: '${directory.path}/database.part',
        cancelToken: cancellation,
      );
      final assertion = expectLater(
        download,
        throwsA(
          isA<DioException>().having(
            (error) => error.type,
            'type',
            DioExceptionType.cancel,
          ),
        ),
      );
      await connected.future.timeout(const Duration(seconds: 5));
      cancellation.cancel('用户跳过下载');
      await assertion.timeout(const Duration(seconds: 5));
    } finally {
      await server.close(force: true);
      await directory.delete(recursive: true);
    }
  });
}

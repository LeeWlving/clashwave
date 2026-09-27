import 'dart:async';

import 'package:clash_for_flutter/app/startup_app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders loading before core completes, then opens the app', (
    tester,
  ) async {
    final ready = Completer<void>();
    await tester.pumpWidget(
      StartupApp(
        initialize: () => ready.future,
        builder: (_) => const MaterialApp(home: Text('Ready')),
      ),
    );
    expect(find.text('正在启动 ClashWave…'), findsOneWidget);
    expect(find.text('Ready'), findsNothing);
    ready.complete();
    await tester.pumpAndSettle();
    expect(find.text('Ready'), findsOneWidget);
  });

  testWidgets('missing core displays an error instead of a blank window', (
    tester,
  ) async {
    await tester.pumpWidget(
      StartupApp(
        initialize: () async => throw StateError('Mihomo core not found'),
        builder: (_) => const SizedBox(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('ClashWave 启动失败'), findsOneWidget);
    expect(find.textContaining('Mihomo core not found'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

import 'package:clash_for_flutter/app/component/macos_window_frame.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final platform in [TargetPlatform.macOS, TargetPlatform.windows]) {
    testWidgets('reserves native controls only on $platform', (tester) async {
      const contentKey = Key('content');
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: platform),
          home: const MacosWindowFrame(
            child: ColoredBox(key: contentKey, color: Colors.white),
          ),
        ),
      );
      expect(
        tester.getTopLeft(find.byKey(contentKey)).dy,
        platform == TargetPlatform.macOS ? MacosWindowFrame.titleBarHeight : 0,
      );
      expect(tester.getBottomRight(find.byKey(contentKey)).dy, 600);
    });
  }
}

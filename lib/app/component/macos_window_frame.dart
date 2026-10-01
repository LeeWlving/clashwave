import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

/// Hidden macOS title bars still overlay the native traffic-light buttons.
class MacosWindowFrame extends StatelessWidget {
  const MacosWindowFrame({super.key, required this.child});

  final Widget child;
  static const titleBarHeight = 32.0;

  @override
  Widget build(BuildContext context) {
    if (Theme.of(context).platform != TargetPlatform.macOS) return child;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: titleBarHeight,
          child: DragToMoveArea(
            child: ColoredBox(color: Theme.of(context).colorScheme.surface),
          ),
        ),
        Expanded(child: child),
      ],
    );
  }
}

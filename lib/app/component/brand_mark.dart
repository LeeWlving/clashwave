import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A small, code-native ClashWave mark: cat ears above one continuous wave.
/// It scales cleanly for both the sidebar and the connection hero.
class ClashWaveMark extends StatelessWidget {
  const ClashWaveMark({
    super.key,
    this.size = 72,
    this.active = true,
    this.showBackground = true,
  });

  final double size;
  final bool active;
  final bool showBackground;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = showBackground
        ? (active ? scheme.onPrimary : scheme.onSurfaceVariant)
        : (active ? scheme.primary : scheme.outline);
    return Semantics(
      image: true,
      label: active ? 'ClashWave 已连接' : 'ClashWave 未连接',
      child: CustomPaint(
        size: Size.square(size),
        painter: _ClashWaveMarkPainter(
          color: color,
          background: showBackground
              ? (active ? scheme.primary : scheme.surfaceContainerHigh)
              : Colors.transparent,
        ),
      ),
    );
  }
}

class _ClashWaveMarkPainter extends CustomPainter {
  const _ClashWaveMarkPainter({required this.color, required this.background});

  final Color color;
  final Color background;

  @override
  void paint(Canvas canvas, Size size) {
    final unit = math.min(size.width, size.height);
    final center = Offset(size.width / 2, size.height / 2);
    if (background.a > 0) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: center, width: unit, height: unit),
          Radius.circular(unit * 0.28),
        ),
        Paint()..color = background,
      );
    }

    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = unit * 0.065
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final cat = Path()
      ..moveTo(unit * 0.24, unit * 0.54)
      ..lineTo(unit * 0.28, unit * 0.27)
      ..lineTo(unit * 0.43, unit * 0.39)
      ..quadraticBezierTo(unit * 0.50, unit * 0.36, unit * 0.57, unit * 0.39)
      ..lineTo(unit * 0.72, unit * 0.27)
      ..lineTo(unit * 0.76, unit * 0.54);
    canvas.drawPath(cat, stroke);

    final wave = Path()
      ..moveTo(unit * 0.18, unit * 0.62)
      ..cubicTo(
        unit * 0.31,
        unit * 0.50,
        unit * 0.39,
        unit * 0.76,
        unit * 0.52,
        unit * 0.62,
      )
      ..cubicTo(
        unit * 0.64,
        unit * 0.49,
        unit * 0.72,
        unit * 0.72,
        unit * 0.82,
        unit * 0.60,
      );
    canvas.drawPath(wave, stroke);

    final eye = Paint()..color = color;
    canvas.drawCircle(Offset(unit * 0.40, unit * 0.51), unit * 0.027, eye);
    canvas.drawCircle(Offset(unit * 0.60, unit * 0.51), unit * 0.027, eye);
  }

  @override
  bool shouldRepaint(covariant _ClashWaveMarkPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.background != background;
  }
}

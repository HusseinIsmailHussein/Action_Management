import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Circular progress ring with [child] centered inside.
class TimerRing extends StatelessWidget {
  final double progress; // 0..1
  final Color color;
  final double size;
  final Widget child;
  const TimerRing({
    super.key,
    required this.progress,
    required this.color,
    required this.child,
    this.size = 250,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _RingPainter(progress, color),
          child: Center(child: child),
        ),
      );
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color color;
  _RingPainter(this.progress, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 14.0;
    final center = size.center(Offset.zero);
    final radius = (size.shortestSide - stroke) / 2;
    final p = progress < 0 ? 0.0 : (progress > 1 ? 1.0 : progress);

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = color.withValues(alpha: 0.14),
    );
    if (p > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        2 * math.pi * p,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.round
          ..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.progress != progress || old.color != color;
}

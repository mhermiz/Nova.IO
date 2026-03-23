import 'dart:math' as math;

import 'package:flutter/material.dart';

class FramePainter extends CustomPainter {
  FramePainter({
    required this.accent,
    required this.emphasizeEnhancement,
  });

  final Color accent;
  final bool emphasizeEnhancement;

  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          accent.withValues(alpha: emphasizeEnhancement ? 0.28 : 0.12),
          Colors.transparent,
          Colors.white.withValues(alpha: emphasizeEnhancement ? 0.08 : 0.03),
        ],
      ).createShader(Offset.zero & size);

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Offset.zero & size,
        const Radius.circular(28),
      ),
      fill,
    );

    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = emphasizeEnhancement ? 2.3 : 1.4
      ..color = accent.withValues(alpha: emphasizeEnhancement ? 0.55 : 0.22);

    final wave = Path()..moveTo(0, size.height * 0.76);
    for (double x = 0; x <= size.width; x += 12) {
      final progress = x / size.width;
      final amplitude = emphasizeEnhancement ? 22.0 : 14.0;
      final y =
          size.height * 0.68 +
          math.sin(progress * math.pi * 2.8) * amplitude +
          math.cos(progress * math.pi * 5.6) * 7;
      wave.lineTo(x, y);
    }

    canvas.drawPath(wave, stroke);

    final glow = Paint()
      ..color = Colors.white.withValues(
        alpha: emphasizeEnhancement ? 0.10 : 0.05,
      )
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18);

    canvas.drawCircle(
      Offset(size.width * 0.76, size.height * 0.30),
      emphasizeEnhancement ? 78 : 52,
      glow,
    );
  }

  @override
  bool shouldRepaint(covariant FramePainter oldDelegate) {
    return oldDelegate.accent != accent ||
        oldDelegate.emphasizeEnhancement != emphasizeEnhancement;
  }
}

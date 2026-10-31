import 'package:flutter/material.dart';

import '../theme.dart';

class CyberBackground extends StatelessWidget {
  const CyberBackground({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0.1, -0.55),
                radius: 1.25,
                colors: [Color(0xFF102D52), navy, Color(0xFF020711)],
                stops: [0, 0.55, 1],
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(painter: _CircuitPainter()),
          ),
        ),
        child,
      ],
    );
  }
}

class _CircuitPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.5, size.height * 0.29);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = neonBlue.withValues(alpha: 0.075);

    for (var i = 0; i < 8; i++) {
      final radius = size.width * (0.24 + i * 0.075);
      canvas.drawCircle(center, radius, paint);
    }

    final linePaint = Paint()
      ..color = neonCyan.withValues(alpha: 0.055)
      ..strokeWidth = 1;
    for (var i = 0; i < 7; i++) {
      final y = size.height * (0.10 + i * 0.105);
      canvas.drawLine(Offset(0, y), Offset(size.width * 0.17, y), linePaint);
      canvas.drawLine(Offset(size.width * 0.83, y), Offset(size.width, y), linePaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

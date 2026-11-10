import 'package:flutter/material.dart';

class GoogleGIcon extends StatelessWidget {
  final double size;

  const GoogleGIcon({super.key, this.size = 20});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: GoogleGPainter(),
    );
  }
}

class GoogleGPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 48.0;
    canvas.scale(scale, scale);

    final center = const Offset(24, 24);
    const radius = 22.0;

    final bluePaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.fill;

    final greenPaint = Paint()
      ..color = const Color(0xFF34A853)
      ..style = PaintingStyle.fill;

    final yellowPaint = Paint()
      ..color = const Color(0xFFFBBC05)
      ..style = PaintingStyle.fill;

    final redPaint = Paint()
      ..color = const Color(0xFFEA4335)
      ..style = PaintingStyle.fill;

    final outerRect = Rect.fromCircle(center: center, radius: radius);
    final innerRect = Rect.fromCircle(center: center, radius: 13.5);

    final bluePath = Path()
      ..moveTo(24, 19.5)
      ..lineTo(45, 19.5)
      ..arcTo(outerRect, 0, 0.785, false)
      ..lineTo(33, 28)
      ..lineTo(24, 28)
      ..close();
    canvas.drawPath(bluePath, bluePaint);

    final greenPath = Path()
      ..arcTo(outerRect, 0.785, 1.57, false)
      ..arcTo(innerRect, 2.355, -1.57, false)
      ..close();
    canvas.drawPath(greenPath, greenPaint);

    final yellowPath = Path()
      ..arcTo(outerRect, 2.355, 1.57, false)
      ..arcTo(innerRect, 3.925, -1.57, false)
      ..close();
    canvas.drawPath(yellowPath, yellowPaint);

    final redPath = Path()
      ..arcTo(outerRect, 3.925, 1.57, false)
      ..arcTo(innerRect, 5.495, -1.57, false)
      ..close();
    canvas.drawPath(redPath, redPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

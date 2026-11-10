import 'package:flutter/material.dart';
import '../constants/app_styles.dart';

class ParcelLogo extends StatelessWidget {
  final double fontSize;
  final double iconSize;

  const ParcelLogo({
    super.key,
    this.fontSize = 22,
    this.iconSize = 28,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [

        SizedBox(
          width: iconSize,
          height: iconSize,
          child: CustomPaint(
            painter: DeliveryTruckPinPainter(),
          ),
        ),
        const SizedBox(width: 8),

        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: 'Apace ',
                style: AppStyles.logoBlack(fontSize: fontSize),
              ),
              TextSpan(
                text: 'Parcel',
                style: AppStyles.logoOrange(fontSize: fontSize),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class DeliveryTruckPinPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 24.0;
    canvas.scale(scale, scale);

    final darkPaint = Paint()
      ..color = const Color(0xFF232B32)
      ..style = PaintingStyle.fill;

    final darkStroke = Paint()
      ..color = const Color(0xFF1E232A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final whitePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final pinPaint = Paint()
      ..color = const Color(0xFF9E3A40)
      ..style = PaintingStyle.fill;

    final boxRect = RRect.fromRectAndRadius(
      const Rect.fromLTWH(3, 9, 11, 10),
      const Radius.circular(2),
    );
    canvas.drawRRect(boxRect, whitePaint);
    canvas.drawRRect(boxRect, darkStroke);

    final linePaint = Paint()
      ..color = const Color(0xFFD1D5DB)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    canvas.drawLine(const Offset(5, 12.5), const Offset(12, 12.5), linePaint);
    canvas.drawLine(const Offset(5, 15.5), const Offset(12, 15.5), linePaint);

    final cabPath = Path()
      ..moveTo(14, 11)
      ..lineTo(17.5, 11)
      ..lineTo(20.5, 15)
      ..lineTo(20.5, 19)
      ..lineTo(14, 19)
      ..close();
    final cabPaint = Paint()..color = const Color(0xFF3F3D47);
    canvas.drawPath(cabPath, cabPaint);
    canvas.drawPath(cabPath, darkStroke);

    final windowPath = Path()
      ..moveTo(15, 12.5)
      ..lineTo(17, 12.5)
      ..lineTo(19, 15)
      ..lineTo(15, 15)
      ..close();
    canvas.drawPath(windowPath, whitePaint);

    final wheelLeft = const Offset(6.5, 19.5);
    final wheelRight = const Offset(17.5, 19.5);
    canvas.drawCircle(wheelLeft, 2.4, darkPaint);
    canvas.drawCircle(wheelRight, 2.4, darkPaint);
    canvas.drawCircle(wheelLeft, 0.9, whitePaint);
    canvas.drawCircle(wheelRight, 0.9, whitePaint);

    final pinPath = Path()
      ..moveTo(6, 1)
      ..cubicTo(3.8, 1, 2.2, 2.6, 2.2, 4.8)
      ..cubicTo(2.2, 7.5, 6, 11, 6, 11)
      ..cubicTo(6, 11, 9.8, 7.5, 9.8, 4.8)
      ..cubicTo(9.8, 2.6, 8.2, 1, 6, 1)
      ..close();
    canvas.drawPath(pinPath, pinPaint);
    canvas.drawPath(pinPath, darkStroke);

    canvas.drawCircle(const Offset(6, 4.8), 1.5, whitePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

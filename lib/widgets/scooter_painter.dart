import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class ScooterAnimationView extends StatefulWidget {
  final double progress;
  final bool isLooping;

  const ScooterAnimationView({
    super.key,
    this.progress = 0.0,
    this.isLooping = true,
  });

  @override
  State<ScooterAnimationView> createState() => _ScooterAnimationViewState();
}

class _ScooterAnimationViewState extends State<ScooterAnimationView>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = widget.isLooping ? _controller.value : widget.progress;
        return CustomPaint(
          size: const Size(double.infinity, 380),
          painter: RoadAndScooterPainter(
            animationTime: t,
          ),
        );
      },
    );
  }
}

class RoadAndScooterPainter extends CustomPainter {
  final double animationTime;

  RoadAndScooterPainter({required this.animationTime});

  double _getRoadCenterX(double y, double height, double width) {
    final centerX = width / 2;

    final normalizedY = y / height;
    final phase = animationTime * 2 * math.pi;

    final bend = math.sin((normalizedY * 2.2 - phase)) * 48.0 +
        math.sin((normalizedY * 1.1 + phase * 0.5)) * 18.0;

    return centerX + bend;
  }

  double _getTangentAngle(double y, double height, double width) {
    const delta = 3.0;
    final x1 = _getRoadCenterX(y - delta, height, width);
    final x2 = _getRoadCenterX(y + delta, height, width);
    final dx = x2 - x1;
    final dy = delta * 2;

    return math.atan2(dx, dy);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width;
    final height = size.height;
    final scooterY = height * 0.52;

    _drawCityGrid(canvas, size);

    _drawRoad(canvas, size);

    final scooterX = _getRoadCenterX(scooterY, height, width);
    final tiltAngle = _getTangentAngle(scooterY, height, width);

    final engineWobble = math.sin(animationTime * 40 * math.pi) * 0.015;

    canvas.save();
    canvas.translate(scooterX, scooterY);

    canvas.rotate(-tiltAngle + engineWobble);

    _drawScooter(canvas);
    canvas.restore();
  }

  void _drawCityGrid(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.gridLineGrey
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;

    final phaseOffset = (animationTime * size.height * 0.8) % (size.height / 2);

    for (double y = -size.height * 0.2; y < size.height * 1.2; y += 110) {
      final currentY = y + phaseOffset;
      if (currentY < 40 || currentY > size.height - 40) continue;

      final roadX = _getRoadCenterX(currentY, size.height, size.width);

      final pathLeft = Path()
        ..moveTo(roadX - 35, currentY)
        ..lineTo(roadX - 85, currentY - 35)
        ..lineTo(roadX - 85, currentY + 60);
      canvas.drawPath(pathLeft, paint);

      final pathRight = Path()
        ..moveTo(roadX + 35, currentY + 20)
        ..lineTo(roadX + 90, currentY + 20)
        ..lineTo(roadX + 90, currentY + 90);
      canvas.drawPath(pathRight, paint);
    }
  }

  void _drawRoad(Canvas canvas, Size size) {
    const roadWidth = 64.0;
    final leftPath = Path();
    final rightPath = Path();
    final roadPoly = Path();

    const step = 4.0;
    bool first = true;

    for (double y = 0; y <= size.height; y += step) {
      final cx = _getRoadCenterX(y, size.height, size.width);
      final lx = cx - roadWidth / 2;
      final rx = cx + roadWidth / 2;

      if (first) {
        leftPath.moveTo(lx, y);
        rightPath.moveTo(rx, y);
        roadPoly.moveTo(lx, y);
        first = false;
      } else {
        leftPath.lineTo(lx, y);
        rightPath.lineTo(rx, y);
        roadPoly.lineTo(lx, y);
      }
    }

    for (double y = size.height; y >= 0; y -= step) {
      final cx = _getRoadCenterX(y, size.height, size.width);
      final rx = cx + roadWidth / 2;
      roadPoly.lineTo(rx, y);
    }
    roadPoly.close();

    final roadPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.transparent,
          Color(0x33D8D9DE),
          AppColors.roadGrey,
          AppColors.roadGrey,
          Color(0x33D8D9DE),
          Colors.transparent,
        ],
        stops: [0.0, 0.15, 0.35, 0.65, 0.85, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawPath(roadPoly, roadPaint);

    final centerDashes = Paint()
      ..color = Colors.white.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    for (double y = 40; y < size.height - 40; y += 22) {
      final cy = y + (animationTime * 44) % 22;
      if (cy > size.height - 50) continue;
      final cx = _getRoadCenterX(cy, size.height, size.width);
      canvas.drawLine(Offset(cx, cy), Offset(cx, cy + 10), centerDashes);
    }
  }

  void _drawScooter(Canvas canvas) {

    const scale = 1.05;
    canvas.scale(scale, scale);

    final shadowPaint = Paint()
      ..color = const Color(0x28000000)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5.0);
    canvas.drawOval(
      const Rect.fromLTWH(-16, -34, 32, 78),
      shadowPaint,
    );

    final darkOutline = Paint()
      ..color = const Color(0xFF1E232A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final redFill = Paint()
      ..color = const Color(0xFFE53935)
      ..style = PaintingStyle.fill;

    final whiteFill = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final darkBodyFill = Paint()
      ..color = const Color(0xFF263238)
      ..style = PaintingStyle.fill;

    final frontWheel = RRect.fromRectAndRadius(
      const Rect.fromLTWH(-4.5, -42, 9, 14),
      const Radius.circular(4.5),
    );
    canvas.drawRRect(frontWheel, darkBodyFill);
    canvas.drawRRect(frontWheel, darkOutline);

    final frontCowl = RRect.fromRectAndRadius(
      const Rect.fromLTWH(-9, -32, 18, 16),
      const Radius.circular(8),
    );
    canvas.drawRRect(frontCowl, redFill);
    canvas.drawRRect(frontCowl, darkOutline);

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-4.5, -31, 9, 5),
        const Radius.circular(2.5),
      ),
      whiteFill,
    );

    final barPaint = Paint()
      ..color = const Color(0xFF1E232A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(-26, -24), const Offset(26, -24), barPaint);

    final leftMirror = RRect.fromRectAndRadius(
      const Rect.fromLTWH(-30, -28, 8, 8),
      const Radius.circular(3),
    );
    final rightMirror = RRect.fromRectAndRadius(
      const Rect.fromLTWH(22, -28, 8, 8),
      const Radius.circular(3),
    );
    canvas.drawRRect(leftMirror, whiteFill);
    canvas.drawRRect(leftMirror, darkOutline);
    canvas.drawRRect(rightMirror, whiteFill);
    canvas.drawRRect(rightMirror, darkOutline);

    final rearFrame = RRect.fromRectAndRadius(
      const Rect.fromLTWH(-15, 12, 30, 24),
      const Radius.circular(7),
    );
    canvas.drawRRect(rearFrame, redFill);
    canvas.drawRRect(rearFrame, darkOutline);

    final parcelBox = RRect.fromRectAndRadius(
      const Rect.fromLTWH(-12.5, 15, 25, 21),
      const Radius.circular(6),
    );
    canvas.drawRRect(parcelBox, whiteFill);
    canvas.drawRRect(parcelBox, darkOutline);

    final midBody = RRect.fromRectAndRadius(
      const Rect.fromLTWH(-12, -8, 24, 24),
      const Radius.circular(10),
    );
    canvas.drawRRect(midBody, redFill);
    canvas.drawRRect(midBody, darkOutline);

    final leftArmPath = Path()
      ..moveTo(-11, -8)
      ..cubicTo(-24, -14, -26, -18, -24, -24);
    final armPaint = Paint()
      ..color = const Color(0xFFE53935)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.2
      ..strokeCap = StrokeCap.round;
    final armOutline = Paint()
      ..color = const Color(0xFF1E232A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8.8
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(leftArmPath, armOutline);
    final rightArmPath = Path()
      ..moveTo(11, -8)
      ..cubicTo(24, -14, 26, -18, 24, -24);
    canvas.drawPath(rightArmPath, armOutline);

    canvas.drawPath(leftArmPath, armPaint);
    canvas.drawPath(rightArmPath, armPaint);

    final torso = RRect.fromRectAndRadius(
      const Rect.fromLTWH(-12, -18, 24, 20),
      const Radius.circular(9),
    );
    canvas.drawRRect(torso, darkBodyFill);
    canvas.drawRRect(torso, darkOutline);

    final helmet = Rect.fromCenter(
      center: const Offset(0, -1),
      width: 17,
      height: 18,
    );
    canvas.drawOval(helmet, whiteFill);
    canvas.drawOval(helmet, darkOutline);
  }

  @override
  bool shouldRepaint(covariant RoadAndScooterPainter oldDelegate) {
    return oldDelegate.animationTime != animationTime;
  }
}

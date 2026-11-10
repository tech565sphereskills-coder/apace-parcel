import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class AnimatedParcelIllustration extends StatefulWidget {
  final double size;

  const AnimatedParcelIllustration({
    super.key,
    this.size = 200,
  });

  @override
  State<AnimatedParcelIllustration> createState() =>
      _AnimatedParcelIllustrationState();
}

class _AnimatedParcelIllustrationState extends State<AnimatedParcelIllustration>
    with TickerProviderStateMixin {
  late AnimationController _floatController;
  late AnimationController _sparkleController;

  @override
  void initState() {
    super.initState();

    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat();

    _sparkleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat();
  }

  @override
  void dispose() {
    _floatController.dispose();
    _sparkleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final boxSize = widget.size;

    return AnimatedBuilder(
      animation: Listenable.merge([_floatController, _sparkleController]),
      builder: (context, child) {
        final floatProgress = _floatController.value;
        final sparkleProgress = _sparkleController.value;

        final floatOffset = math.sin(floatProgress * 2 * math.pi) * 8.5;

        final tiltAngle = math.sin(floatProgress * 2 * math.pi + 0.4) * 0.028;

        final normalizedHeight = (floatOffset + 8.5) / 17.0;
        final shadowScale = 0.88 + (0.24 * normalizedHeight);
        final shadowOpacity = 0.22 + (0.16 * normalizedHeight);

        return SizedBox(
          width: boxSize * 1.15,
          height: boxSize * 1.15,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [

              Container(
                width: boxSize * 0.85,
                height: boxSize * 0.85,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.primaryOrange.withValues(alpha: 0.14),
                      AppColors.headerGradientEnd.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),

              Positioned(
                bottom: 12 - (floatOffset * 0.25),
                child: Transform.scale(
                  scaleX: shadowScale,
                  scaleY: shadowScale * 0.40,
                  child: Container(
                    width: boxSize * 0.62,
                    height: 28,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(40),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF6F3B1A).withValues(alpha: shadowOpacity),
                          blurRadius: 18,
                          spreadRadius: 2,
                        ),
                        BoxShadow(
                          color: const Color(0x33000000).withValues(alpha: shadowOpacity * 0.5),
                          blurRadius: 12,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              Positioned(
                bottom: 22 - floatOffset,
                child: Transform.rotate(
                  angle: tiltAngle,
                  child: Image.asset(
                    'assets/images/parcel_hd.png',
                    width: boxSize,
                    height: boxSize,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                  ),
                ),
              ),

              Positioned(
                top: 24 + math.sin(sparkleProgress * 2 * math.pi) * 4,
                right: 18 + math.cos(sparkleProgress * 2 * math.pi) * 3,
                child: _buildSparkle(
                  scale: 0.6 + 0.4 * math.sin(sparkleProgress * 2 * math.pi).abs(),
                  rotation: sparkleProgress * math.pi,
                  color: const Color(0xFFFF944D),
                  size: 20,
                ),
              ),

              Positioned(
                bottom: 50 + math.cos((sparkleProgress + 0.5) * 2 * math.pi) * 4,
                left: 14 + math.sin((sparkleProgress + 0.5) * 2 * math.pi) * 3,
                child: _buildSparkle(
                  scale: 0.5 + 0.45 * math.cos((sparkleProgress + 0.3) * 2 * math.pi).abs(),
                  rotation: -sparkleProgress * math.pi * 0.8,
                  color: const Color(0xFFFFAE66),
                  size: 16,
                ),
              ),

              Positioned(
                top: 48 - (sparkleProgress * 18),
                left: 36 + math.sin(sparkleProgress * 2 * math.pi) * 6,
                child: Opacity(
                  opacity: (1.0 - sparkleProgress).clamp(0.0, 1.0) * 0.7,
                  child: Container(
                    width: 5,
                    height: 5,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primaryOrange,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSparkle({
    required double scale,
    required double rotation,
    required Color color,
    required double size,
  }) {
    return Transform.rotate(
      angle: rotation,
      child: Transform.scale(
        scale: scale,
        child: SizedBox(
          width: size,
          height: size,
          child: CustomPaint(
            painter: _FourPointStarPainter(color: color),
          ),
        ),
      ),
    );
  }
}

class _FourPointStarPainter extends CustomPainter {
  final Color color;

  _FourPointStarPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final cx = size.width / 2;
    final cy = size.height / 2;
    final rOuter = size.width / 2;
    final rInner = size.width * 0.18;

    final path = Path();
    path.moveTo(cx, cy - rOuter);
    path.quadraticBezierTo(cx, cy, cx + rInner, cy - rInner);
    path.lineTo(cx + rOuter, cy);
    path.quadraticBezierTo(cx, cy, cx + rInner, cy + rInner);
    path.lineTo(cx, cy + rOuter);
    path.quadraticBezierTo(cx, cy, cx - rInner, cy + rInner);
    path.lineTo(cx - rOuter, cy);
    path.quadraticBezierTo(cx, cy, cx - rInner, cy - rInner);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _FourPointStarPainter oldDelegate) =>
      oldDelegate.color != color;
}

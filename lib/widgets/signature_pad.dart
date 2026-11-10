import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

class SignaturePad extends StatefulWidget {
  final ValueChanged<List<Offset?>> onSignatureChanged;
  final VoidCallback onClear;

  const SignaturePad({
    super.key,
    required this.onSignatureChanged,
    required this.onClear,
  });

  @override
  State<SignaturePad> createState() => SignaturePadState();
}

class SignaturePadState extends State<SignaturePad> {
  final List<Offset?> _points = [];
  final GlobalKey _paintKey = GlobalKey();

  bool get hasStrokes => _points.any((p) => p != null);

  Future<Uint8List?> capturePngBytes() async {
    try {
      final boundary =
          _paintKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;
      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 160,
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFCBD5E1), width: 1.5),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: RepaintBoundary(
              key: _paintKey,
              child: Container(
                color: const Color(0xFFF8FAFC),
                child: GestureDetector(
                  onPanUpdate: (details) {
                    final RenderBox renderBox = context.findRenderObject() as RenderBox;
                    final localPosition = renderBox.globalToLocal(details.globalPosition);
                    if (localPosition.dx >= 0 &&
                        localPosition.dx <= renderBox.size.width &&
                        localPosition.dy >= 0 &&
                        localPosition.dy <= renderBox.size.height) {
                      setState(() {
                        _points.add(localPosition);
                      });
                      widget.onSignatureChanged(_points);
                    }
                  },
                  onPanEnd: (_) {
                    setState(() {
                      _points.add(null);
                    });
                    widget.onSignatureChanged(_points);
                  },
                  child: CustomPaint(
                    painter: _SignaturePainter(points: _points),
                    size: Size.infinite,
                  ),
                ),
              ),
            ),
          ),
          if (_points.isEmpty)
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.draw_rounded, size: 28, color: Color(0xFF94A3B8)),
                  SizedBox(height: 6),
                  Text(
                    'Sign with finger inside this box',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF94A3B8)),
                  ),
                ],
              ),
            ),
          Positioned(
            right: 10,
            bottom: 10,
            child: TextButton.icon(
              onPressed: () {
                setState(() => _points.clear());
                widget.onClear();
              },
              icon: const Icon(Icons.refresh_rounded, size: 14, color: Color(0xFF64748B)),
              label: const Text('Clear', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF64748B))),
              style: TextButton.styleFrom(
                backgroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SignaturePainter extends CustomPainter {
  final List<Offset?> points;

  _SignaturePainter({required this.points});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF0F172A)
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3.0;

    for (int i = 0; i < points.length - 1; i++) {
      if (points[i] != null && points[i + 1] != null) {
        canvas.drawLine(points[i]!, points[i + 1]!, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SignaturePainter oldDelegate) => true;
}

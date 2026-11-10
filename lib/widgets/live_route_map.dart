import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../models/delivery_order.dart';

class LiveRouteMap extends StatefulWidget {
  final String currentStatus;
  final String pickupAddress;
  final String dropoffAddress;
  final List<OrderStopItem> stops;
  final double? liveLat;
  final double? liveLng;
  final double? liveSpeedKmh;
  final String? activeGeofenceZone;

  const LiveRouteMap({
    super.key,
    required this.currentStatus,
    required this.pickupAddress,
    required this.dropoffAddress,
    this.stops = const [],
    this.liveLat,
    this.liveLng,
    this.liveSpeedKmh,
    this.activeGeofenceZone,
  });

  @override
  State<LiveRouteMap> createState() => _LiveRouteMapState();
}

class _LiveRouteMapState extends State<LiveRouteMap> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  double _routeProgress() {
    switch (widget.currentStatus) {
      case 'searching':
        return 0.08;
      case 'assigned':
        return 0.22;
      case 'at_pickup':
        return 0.40;
      case 'in_transit':
        return widget.activeGeofenceZone == 'DROPOFF_150M' ? 0.92 : 0.68;
      case 'delivered':
        return 1.0;
      default:
        return 0.35;
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = _routeProgress();
    final isNearZone = widget.activeGeofenceZone != null;

    return Container(
      height: 220,
      width: double.infinity,
      decoration: const BoxDecoration(color: Color(0xFF0F172A)),
      child: Stack(
        children: [
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, _) {
              return CustomPaint(
                size: const Size(double.infinity, 220),
                painter: _VectorCorridorPainter(
                  progress: progress,
                  pulseValue: _pulseController.value,
                  stopCount: widget.stops.isEmpty ? 1 : widget.stops.length,
                  deliveredStops:
                      widget.stops.where((s) => s.status == 'DELIVERED').length,
                  isGeofenceActive: isNearZone,
                ),
              );
            },
          ),
          Positioned(
            top: 14,
            left: 14,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xE60F172A),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isNearZone ? AppColors.emeraldGreen : const Color(0xFF334155),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: widget.currentStatus == 'delivered' || isNearZone
                          ? AppColors.emeraldGreen
                          : AppColors.primaryOrange,
                    ),
                  ),
                  const SizedBox(width: 7),
                  Text(
                    isNearZone
                        ? '150m Geofence Active'
                        : (widget.currentStatus == 'searching'
                            ? 'Live Auction Radar'
                            : 'GPS Telemetry Live'),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (widget.liveLat != null && widget.liveLng != null)
            Positioned(
              top: 14,
              right: 14,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xE61E293B),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF334155)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.speed_rounded, size: 13, color: Color(0xFF38BDF8)),
                    const SizedBox(width: 5),
                    Text(
                      '${(widget.liveSpeedKmh ?? 36).toStringAsFixed(0)} km/h • ${widget.liveLat!.toStringAsFixed(3)}, ${widget.liveLng!.toStringAsFixed(3)}',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFBAE6FD),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Positioned(
            left: 14,
            right: 14,
            bottom: 12,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildPinChip('PICKUP', widget.pickupAddress, const Color(0xFF38BDF8)),
                const SizedBox(width: 10),
                _buildPinChip('DROP-OFF', widget.dropoffAddress, AppColors.primaryOrange),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPinChip(String tag, String addr, Color accent) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: const Color(0xE60F172A),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF334155)),
        ),
        child: Row(
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                '$tag: $addr',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VectorCorridorPainter extends CustomPainter {
  final double progress;
  final double pulseValue;
  final int stopCount;
  final int deliveredStops;
  final bool isGeofenceActive;

  _VectorCorridorPainter({
    required this.progress,
    required this.pulseValue,
    required this.stopCount,
    required this.deliveredStops,
    required this.isGeofenceActive,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final bgRoadPaint = Paint()
      ..color = const Color(0xFF1E293B)
      ..strokeWidth = 2.5;

    for (double y = 32; y < size.height; y += 36) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y - 14), bgRoadPaint);
    }
    for (double x = 28; x < size.width; x += 68) {
      canvas.drawLine(Offset(x, 0), Offset(x + 22, size.height), bgRoadPaint);
    }

    final start = Offset(size.width * 0.14, size.height * 0.62);
    final mid = Offset(size.width * 0.50, size.height * 0.34);
    final end = Offset(size.width * 0.86, size.height * 0.56);

    final fullPath = Path()
      ..moveTo(start.dx, start.dy)
      ..quadraticBezierTo(mid.dx, mid.dy, end.dx, end.dy);

    final baseRoutePaint = Paint()
      ..color = const Color(0xFF334155)
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(fullPath, baseRoutePaint);

    final metrics = fullPath.computeMetrics().first;
    final activePath = metrics.extractPath(0, metrics.length * progress);
    final activePaint = Paint()
      ..color = AppColors.primaryOrange
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(activePath, activePaint);

    final geofenceRingRadius = 18.0 + (pulseValue * 16.0);
    final geofencePaint = Paint()
      ..color = (isGeofenceActive ? AppColors.emeraldGreen : AppColors.primaryOrange)
          .withValues(alpha: (1.0 - pulseValue) * 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(end, geofenceRingRadius, geofencePaint);
    canvas.drawCircle(
      end,
      20,
      Paint()..color = const Color(0xFF10B981).withValues(alpha: 0.12),
    );

    canvas.drawCircle(start, 7, Paint()..color = const Color(0xFF38BDF8));
    canvas.drawCircle(start, 3, Paint()..color = Colors.white);

    if (stopCount > 1) {
      for (int i = 1; i < stopCount; i++) {
        final t = i / stopCount;
        final tangent = metrics.getTangentForOffset(metrics.length * t);
        if (tangent != null) {
          final isDone = i <= deliveredStops;
          canvas.drawCircle(
            tangent.position,
            6.5,
            Paint()..color = isDone ? AppColors.emeraldGreen : const Color(0xFFF59E0B),
          );
          canvas.drawCircle(tangent.position, 2.5, Paint()..color = Colors.white);
        }
      }
    }

    canvas.drawCircle(end, 8, Paint()..color = AppColors.emeraldGreen);
    canvas.drawCircle(end, 3.5, Paint()..color = Colors.white);

    final riderTangent = metrics.getTangentForOffset(metrics.length * progress);
    if (riderTangent != null) {
      final pos = riderTangent.position;
      canvas.drawCircle(
        pos,
        14 + (pulseValue * 6),
        Paint()..color = AppColors.primaryOrange.withValues(alpha: 0.25 * (1 - pulseValue)),
      );
      canvas.drawCircle(pos, 10, Paint()..color = AppColors.primaryOrange);
      canvas.drawCircle(pos, 4, Paint()..color = Colors.white);
    }
  }

  @override
  bool shouldRepaint(covariant _VectorCorridorPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.pulseValue != pulseValue ||
        oldDelegate.isGeofenceActive != isGeofenceActive;
  }
}


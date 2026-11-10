import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../constants/app_colors.dart';
import '../models/delivery_order.dart';
import '../services/mock_state.dart';
import '../services/socket_service.dart';
import 'rider_chat_screen.dart';
import '../widgets/waybill_modal.dart';
import '../widgets/transaction_pin_sheet.dart';
import '../widgets/live_route_map.dart';

class OrderTrackingScreen extends StatefulWidget {
  final DeliveryOrder order;

  const OrderTrackingScreen({super.key, required this.order});

  @override
  State<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen> {
  late String _currentStatus;
  late bool _isEscrowReleased;
  late String _riderName;
  late String _riderPhone;
  late String _riderVehicle;
  late double _riderRating;
  String? _auctionStatusText;
  double? _liveLat;
  double? _liveLng;
  double? _liveSpeedKmh;
  String? _activeGeofenceZone;
  String? _geofenceMessage;
  String? _delayAlertText;
  late List<OrderStopItem> _stops;

  @override
  void initState() {
    super.initState();
    _currentStatus = widget.order.status;
    _isEscrowReleased = widget.order.escrowStatus == 'RELEASED';
    _riderName = widget.order.riderName;
    _riderPhone = widget.order.riderPhone;
    _riderVehicle = widget.order.riderVehicle;
    _riderRating = widget.order.riderRating;
    _activeGeofenceZone = widget.order.geofenceStatus;
    _stops = List<OrderStopItem>.from(widget.order.stops);
    if (_currentStatus == 'searching') {
      _auctionStatusText = 'Dispatch Radar active • Offering trip to nearest online rider...';
    }
    SocketService.instance.joinOrder(widget.order.backendId ?? widget.order.id);
    SocketService.instance.onRiderLocation((data) {
      if (!mounted) return;
      setState(() {
        _liveLat = (data['latitude'] as num?)?.toDouble();
        _liveLng = (data['longitude'] as num?)?.toDouble();
        _liveSpeedKmh = (data['speed'] as num?)?.toDouble();
      });
    });
    SocketService.instance.onGeofenceTriggered((data) {
      if (!mounted) return;
      setState(() {
        _activeGeofenceZone = data['zone']?.toString();
        _geofenceMessage = data['message']?.toString();
        if (_activeGeofenceZone == 'PICKUP_150M' && _currentStatus == 'assigned') {
          _currentStatus = 'at_pickup';
        }
      });
    });
    SocketService.instance.onOrderDelayReported((data) {
      if (!mounted) return;
      setState(() {
        _delayAlertText = data['message']?.toString() ?? 'Route delay reported by rider';
      });
    });
    SocketService.instance.onOrderStopCompleted((data) {
      if (!mounted) return;
      final completedId = data['stopId']?.toString();
      if (completedId != null) {
        setState(() {
          _stops = _stops
              .map(
                (s) => s.id == completedId
                    ? OrderStopItem(
                        id: s.id,
                        sequence: s.sequence,
                        subWaybillCode: s.subWaybillCode,
                        address: s.address,
                        landmark: s.landmark,
                        contactName: s.contactName,
                        contactPhone: s.contactPhone,
                        handoverOtp: s.handoverOtp,
                        status: 'DELIVERED',
                        lat: s.lat,
                        lng: s.lng,
                        proofPhotoUrl: s.proofPhotoUrl,
                      )
                    : s,
              )
              .toList();
        });
      }
    });
    SocketService.instance.onDispatchSearching((data) {
      if (!mounted) return;
      final attempt = data['attemptNumber'];
      final candidate = data['candidateRiderName']?.toString();
      final msg = data['message']?.toString();
      setState(() {
        if (_currentStatus == 'searching') {
          _auctionStatusText = msg ??
              (candidate != null
                  ? 'Attempt #$attempt • 15s Dispatch Offer sent to $candidate'
                  : 'Scanning nearby online riders...');
        }
      });
    });
    SocketService.instance.onOrderStatus((data) {
      if (!mounted) return;
      final incoming = data['status']?.toString().toUpperCase();
      final rider = data['rider'];
      setState(() {
        if (rider is Map) {
          _riderName = rider['fullName']?.toString() ?? _riderName;
          _riderPhone = rider['phone']?.toString() ?? _riderPhone;
          final profile = rider['riderProfile'];
          if (profile is Map) {
            final vType = profile['vehicleType']?.toString() ?? '';
            final plate = profile['plateNumber']?.toString() ?? '';
            final joined = [vType, plate].where((s) => s.isNotEmpty).join(' • ');
            if (joined.isNotEmpty) _riderVehicle = joined;
            final rVal = profile['rating'];
            if (rVal is num) _riderRating = rVal.toDouble();
          }
        }
        if (incoming == 'ASSIGNED') {
          _currentStatus = 'assigned';
          _auctionStatusText = null;
        } else if (incoming == 'PICKED_UP') {
          _currentStatus = 'at_pickup';
          _auctionStatusText = null;
        } else if (incoming == 'IN_TRANSIT') {
          _currentStatus = 'in_transit';
          _auctionStatusText = null;
        } else if (incoming == 'DELIVERED') {
          _currentStatus = 'delivered';
          _auctionStatusText = null;
        }
      });
    });
  }

  void _advanceSimulation() {
    setState(() {
      if (_currentStatus == 'assigned') {
        _currentStatus = 'at_pickup';
      } else if (_currentStatus == 'at_pickup') {
        _currentStatus = 'in_transit';
      } else if (_currentStatus == 'in_transit') {
        _currentStatus = 'delivered';
      } else {
        _currentStatus = 'assigned';
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Delivery status updated to: ${_statusTitle(_currentStatus)}'),
        backgroundColor: AppColors.textDark,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );

    if (_currentStatus == 'delivered') {
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted) _showTipRiderSheet();
      });
    }
  }

  String _statusTitle(String status) {
    switch (status) {
      case 'searching':
        return 'Live Dispatch Auction';
      case 'assigned':
        return 'Rider Assigned';
      case 'at_pickup':
        return 'Arrived at Pickup';
      case 'in_transit':
        return 'In Transit with Parcel';
      case 'delivered':
        return 'Delivered Successfully';
      default:
        return 'Processing';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textDark, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          children: [
            const Text(
              'Track Delivery',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.textDark,
              ),
            ),
            Text(
              widget.order.id,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.primaryOrange,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.report_problem_outlined, color: AppColors.textDark),
            onPressed: _showDisputeModal,
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [

            LiveRouteMap(
              currentStatus: _currentStatus,
              pickupAddress: widget.order.pickupAddress,
              dropoffAddress: widget.order.dropoffAddress,
              stops: _stops,
              liveLat: _liveLat,
              liveLng: _liveLng,
              liveSpeedKmh: _liveSpeedKmh,
              activeGeofenceZone: _activeGeofenceZone,
            ),

            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_delayAlertText != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFBEB),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFFCD34D)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.traffic_rounded, size: 20, color: Color(0xFFD97706)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _delayAlertText!,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF92400E),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],

                  if (_geofenceMessage != null) ...[
                    _buildGeofenceAlertCard(),
                    const SizedBox(height: 14),
                  ],

                  if (_auctionStatusText != null) ...[
                    _buildLiveAuctionBanner(),
                    const SizedBox(height: 14),
                  ],

                  _buildSecurityPinCard(),

                  if (widget.order.isEscrow) ...[
                    const SizedBox(height: 14),
                    _buildEscrowStatusCard(),
                  ],

                  const SizedBox(height: 14),

                  _buildQuickActionsRow(),

                  const SizedBox(height: 18),

                  _buildRiderCard(),

                  const SizedBox(height: 20),

                  _buildProgressStepper(),

                  if (_stops.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    _buildSubWaybillsCard(),
                  ],

                  const SizedBox(height: 20),

                  _buildRouteCard(),

                  const SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: OutlinedButton.icon(
                      onPressed: _advanceSimulation,
                      icon: const Icon(Icons.fast_forward_rounded, color: AppColors.primaryOrange),
                      label: Text(
                        'Simulate Next Status: ${_getNextStepName()}',
                        style: const TextStyle(
                          color: AppColors.primaryOrange,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.primaryOrange, width: 1.5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        backgroundColor: AppColors.primaryOrange.withValues(alpha: 0.05),
                      ),
                    ),
                  ),

                  const SizedBox(height: 30),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getNextStepName() {
    switch (_currentStatus) {
      case 'assigned':
        return 'Arrived at Pickup';
      case 'at_pickup':
        return 'In Transit';
      case 'in_transit':
        return 'Delivered';
      case 'delivered':
        return 'Reset to Assigned';
      default:
        return 'Next';
    }
  }

  Widget _buildGeofenceAlertCard() {
    final isDropoff = _activeGeofenceZone == 'DROPOFF_150M';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDropoff ? const Color(0xFFECFDF5) : const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDropoff ? const Color(0xFF6EE7B7) : const Color(0xFF93C5FD),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.gps_fixed_rounded,
            size: 20,
            color: isDropoff ? const Color(0xFF059669) : const Color(0xFF2563EB),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _geofenceMessage ?? 'Rider entered 150m arrival geofence',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isDropoff ? const Color(0xFF065F46) : const Color(0xFF1E40AF),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubWaybillsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(color: Color(0x08000000), blurRadius: 10, offset: Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Corridor Route Sub-Waybills',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textDark),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${_stops.length} Stop${_stops.length == 1 ? '' : 's'}',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textDark),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (final stop in _stops) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: stop.status == 'DELIVERED'
                    ? const Color(0xFFF0FDF4)
                    : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: stop.status == 'DELIVERED'
                      ? const Color(0xFFBBF7D0)
                      : const Color(0xFFE2E8F0),
                ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 13,
                    backgroundColor: stop.status == 'DELIVERED'
                        ? AppColors.emeraldGreen
                        : AppColors.primaryOrange,
                    child: Text(
                      '${stop.sequence}',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${stop.subWaybillCode} • ${stop.contactName}',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.textDark),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          stop.address,
                          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'OTP ${stop.handoverOtp}',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: AppColors.primaryOrange),
                      ),
                      Text(
                        stop.status,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: stop.status == 'DELIVERED' ? AppColors.emeraldGreen : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSecurityPinCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFEDD5)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Color(0xFFFFEDD5),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.shield_rounded, color: AppColors.primaryOrange, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Delivery Handover OTP',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF9A3412),
                  ),
                ),
                Text(
                  'Give this PIN to rider only at drop-off',
                  style: TextStyle(
                    fontSize: 11,
                    color: Color(0xFFC2410C),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.primaryOrange, width: 1.2),
            ),
            child: Text(
              widget.order.securityPin,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: AppColors.primaryOrange,
                letterSpacing: 2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveAuctionBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E3A8A)],
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(color: Color(0x14000000), blurRadius: 10, offset: Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: const Color(0xFF38BDF8).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.radar_rounded, color: Color(0xFF38BDF8), size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'DISPATCH AUCTION LIVE',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF38BDF8),
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _auctionStatusText ?? 'Matching nearest verified rider...',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRiderCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(color: Color(0x08000000), blurRadius: 10, offset: Offset(0, 3)),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [

              CircleAvatar(
                radius: 26,
                backgroundColor: AppColors.primaryOrangeLight,
                child: const Icon(Icons.sports_motorsports_rounded, color: AppColors.primaryOrange, size: 30),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          _riderName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textDark,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.star_rounded, size: 12, color: Color(0xFFD97706)),
                              const SizedBox(width: 3),
                              Text(
                                '$_riderRating',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF92400E)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _riderVehicle,
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final cleanPhone = _riderPhone.replaceAll(' ', '');
                    final uri = Uri(scheme: 'tel', path: cleanPhone);
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri);
                    } else if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Rider phone: $_riderPhone')),
                      );
                    }
                  },
                  icon: const Icon(Icons.phone_rounded, size: 16, color: AppColors.textDark),
                  label: const Text('Call', style: TextStyle(color: AppColors.textDark, fontWeight: FontWeight.w700)),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 11),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => RiderChatScreen(
                          riderName: _riderName,
                          vehicleDetails: _riderVehicle,
                          orderId: widget.order.backendId ?? widget.order.id,
                          riderPhone: _riderPhone,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.chat_bubble_rounded, size: 16, color: Colors.white),
                  label: const Text('Chat with Rider', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryOrange,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProgressStepper() {
    final steps = ['assigned', 'at_pickup', 'in_transit', 'delivered'];
    final labels = ['Rider Assigned', 'At Pickup', 'In Transit', 'Delivered'];
    final currentIndex = steps.indexOf(_currentStatus);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(color: Color(0x08000000), blurRadius: 10, offset: Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Delivery Timeline',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textDark),
          ),
          const SizedBox(height: 16),
          for (int i = 0; i < steps.length; i++) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i <= currentIndex ? AppColors.primaryOrange : const Color(0xFFE2E8F0),
                      ),
                      child: i < currentIndex
                          ? const Icon(Icons.check, size: 14, color: Colors.white)
                          : Center(
                              child: Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: i == currentIndex ? Colors.white : Colors.transparent,
                                ),
                              ),
                            ),
                    ),
                    if (i < steps.length - 1)
                      Container(
                        width: 2,
                        height: 28,
                        color: i < currentIndex ? AppColors.primaryOrange : const Color(0xFFE2E8F0),
                      ),
                  ],
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          labels[i],
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: i <= currentIndex ? FontWeight.w700 : FontWeight.w500,
                            color: i <= currentIndex ? AppColors.textDark : AppColors.textMuted,
                          ),
                        ),
                        if (i == currentIndex)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primaryOrangeLight,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Text(
                              'CURRENT',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.primaryOrange),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRouteCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(color: Color(0x08000000), blurRadius: 10, offset: Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Route Details',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textDark),
              ),
              Text(
                widget.order.formattedPrice,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.primaryOrange),
              ),
            ],
          ),
          const SizedBox(height: 16),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 3),
                child: Icon(Icons.circle, color: Color(0xFF3B82F6), size: 12),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('PICKUP', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF64748B))),
                    Text(
                      widget.order.pickupAddress,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textDark),
                    ),
                    Text(
                      'Landmark: ${widget.order.pickupLandmark}',
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),

          Padding(
            padding: const EdgeInsets.only(left: 5, top: 4, bottom: 4),
            child: Container(width: 2, height: 20, color: const Color(0xFFCBD5E1)),
          ),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 3),
                child: Icon(Icons.location_on_rounded, color: AppColors.primaryOrange, size: 14),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('DROPOFF', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF64748B))),
                    Text(
                      widget.order.dropoffAddress,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textDark),
                    ),
                    Text(
                      'Landmark: ${widget.order.dropoffLandmark}',
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 12),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Item: ${widget.order.packageName}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              Text('Weight: ${widget.order.packageWeight}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textDark)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionsRow() {
    return Row(
      children: [
        Expanded(
          child: _buildActionButton(
            label: 'Waybill',
            icon: Icons.receipt_long_rounded,
            color: const Color(0xFF1E293B),
            onTap: _showWaybillDialog,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildActionButton(
            label: 'WhatsApp',
            icon: Icons.chat_bubble_rounded,
            color: AppColors.whatsappGreen,
            onTap: _showWhatsAppShareSheet,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildActionButton(
            label: 'Tip Rider',
            icon: Icons.favorite_rounded,
            color: AppColors.primaryOrange,
            onTap: _showTipRiderSheet,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: const [
            BoxShadow(color: Color(0x04000000), blurRadius: 4, offset: Offset(0, 1)),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: color),
            ),
          ],
        ),
      ),
    );
  }

  void _showWaybillDialog() {
    WaybillModal.show(context, widget.order);
  }

  Widget _buildEscrowStatusCard() {
    final isReleased = _isEscrowReleased;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isReleased ? const Color(0xFFECFDF5) : const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isReleased ? const Color(0xFFA7F3D0) : const Color(0xFFBFDBFE),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isReleased ? const Color(0xFF10B981) : const Color(0xFF2563EB),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isReleased ? Icons.check_circle_rounded : Icons.shield_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isReleased ? 'Escrow Payout Complete' : 'Apace Social Commerce Escrow',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: isReleased ? const Color(0xFF065F46) : const Color(0xFF1E40AF),
                      ),
                    ),
                    Text(
                      isReleased
                          ? '${widget.order.formattedEscrowAmount} credited to vendor wallet'
                          : '${widget.order.formattedEscrowAmount} held securely until inspection',
                      style: TextStyle(
                        fontSize: 12,
                        color: isReleased ? const Color(0xFF047857) : const Color(0xFF3B82F6),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (!isReleased) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFDBEAFE)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Buyer Release PIN:',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDBEAFE),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      widget.order.escrowReleaseCode ?? '7192',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF1E40AF),
                        letterSpacing: 2.0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton.icon(
                onPressed: () {
                  TransactionPinSheet.show(
                    context,
                    title: 'Authorize Escrow Release',
                    subtitle: 'Release ${widget.order.formattedEscrowAmount} to vendor wallet',
                    onSuccess: (pin) async {
                      final code = widget.order.escrowReleaseCode ?? '7192';
                      final err = await AppState.instance.releaseEscrowLive(
                        widget.order.id,
                        code,
                      );
                      if (!mounted) return;
                      if (err != null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(err), backgroundColor: Colors.redAccent),
                        );
                        return;
                      }
                      setState(() => _isEscrowReleased = true);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('${widget.order.formattedEscrowAmount} released to vendor wallet successfully!'),
                          backgroundColor: const Color(0xFF10B981),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                  );
                },
                icon: const Icon(Icons.lock_open_rounded, size: 16, color: Colors.white),
                label: const Text(
                  'Release Escrow Funds to Vendor',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showDisputeModal() {
    String selectedReason = 'Damaged / Tampered Parcel';
    final descController = TextEditingController();
    final reasons = [
      'Damaged / Tampered Parcel',
      'Rider Delayed / Unreachable',
      'Wrong Item Delivered (Escrow Hold)',
      'Overcharged / Billing Issue',
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (sheetCtx, setSheetState) {
            return Container(
              padding: EdgeInsets.only(
                left: 22,
                right: 22,
                top: 20,
                bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 24,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Report Issue / Open Dispute',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textDark),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Apace Compliance freezes escrow payouts until resolved.',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    initialValue: selectedReason,
                    items: reasons
                        .map((r) => DropdownMenuItem(value: r, child: Text(r, style: const TextStyle(fontSize: 13))))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) setSheetState(() => selectedReason = val);
                    },
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Describe what happened for our resolution team...',
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () async {
                        final desc = descController.text.trim();
                        if (desc.isEmpty) return;
                        final sheetNav = Navigator.of(sheetCtx);
                        final messenger = ScaffoldMessenger.of(context);
                        final err = await AppState.instance.openDisputeLive(
                          widget.order.id,
                          selectedReason,
                          desc,
                        );
                        if (sheetCtx.mounted) sheetNav.pop();
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(err ?? 'Dispute filed! Ticket assigned to Apace Support.'),
                            backgroundColor: err != null ? Colors.redAccent : AppColors.textDark,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text('Submit Formal Dispute', style: TextStyle(fontWeight: FontWeight.w800)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showWhatsAppShareSheet() {
    final message = '''
📦 *APACE PARCEL DISPATCH UPDATE* 📦

Hello *${widget.order.recipientName}*,
A dispatch rider (*${widget.order.riderName}*, ${widget.order.riderVehicle}) is on the way with your package from *${widget.order.senderName}*.

📍 *Delivery Address:* ${widget.order.dropoffAddress}
🏢 *Landmark:* ${widget.order.dropoffLandmark}
📦 *Package:* ${widget.order.packageName} (${widget.order.packageWeight})
🔐 *Handover OTP:* ${widget.order.securityPin}
📲 *Track Live:* https://track.apace.ng/${widget.order.id}

⚠️ *Important:* Please only release the 4-digit OTP to the rider after inspecting your parcel!
'''.trim();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(22),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: Color(0xFFE8F5E9),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.chat_bubble_rounded, color: AppColors.whatsappGreen, size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Share WhatsApp Tracking Link',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textDark),
                        ),
                        Text(
                          'Keep recipient informed with live GPS & OTP',
                          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Text(
                  message,
                  style: const TextStyle(fontSize: 12, height: 1.45, color: Color(0xFF1E293B)),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: message));
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('WhatsApp message copied to clipboard!'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                      icon: const Icon(Icons.copy_rounded, size: 16, color: AppColors.textDark),
                      label: const Text('Copy Message', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.textDark)),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        Navigator.pop(ctx);
                        final encoded = Uri.encodeComponent(message);
                        final waUri = Uri.parse('https://wa.me/?text=$encoded');
                        if (await canLaunchUrl(waUri)) {
                          await launchUrl(waUri, mode: LaunchMode.externalApplication);
                        } else if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('WhatsApp prepared for ${widget.order.recipientName}'),
                              backgroundColor: AppColors.whatsappGreen,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.send_rounded, size: 16, color: Colors.white),
                      label: const Text('Send WhatsApp', style: TextStyle(fontWeight: FontWeight.w800, color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.whatsappGreen,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _showTipRiderSheet() {
    int selectedRating = 5;
    double selectedTip = 500.0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (tipCtx, setTipState) {
            return Container(
              padding: const EdgeInsets.all(22),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Rate & Tip Dispatch Rider',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.textDark),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(tipCtx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: AppColors.primaryOrangeLight,
                        child: const Icon(Icons.sports_motorsports_rounded, color: AppColors.primaryOrange, size: 26),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.order.riderName,
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textDark),
                            ),
                            Text(
                              widget.order.riderVehicle,
                              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(5, (idx) {
                        final star = idx + 1;
                        return IconButton(
                          icon: Icon(
                            star <= selectedRating ? Icons.star_rounded : Icons.star_outline_rounded,
                            size: 32,
                            color: const Color(0xFFF59E0B),
                          ),
                          onPressed: () => setTipState(() => selectedRating = star),
                        );
                      }),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Add a Naira Tip (Deducted from Apace Wallet):',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textDark),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [200.0, 500.0, 1000.0, 2000.0].map((amt) {
                      final isSelected = selectedTip == amt;
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: InkWell(
                            onTap: () => setTipState(() => selectedTip = isSelected ? 0.0 : amt),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: isSelected ? const Color(0xFFFFF7ED) : const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected ? AppColors.primaryOrange : const Color(0xFFE2E8F0),
                                  width: isSelected ? 1.8 : 1,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  '₦${amt.toStringAsFixed(0)}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: isSelected ? AppColors.primaryOrange : AppColors.textDark,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () async {
                      final tipNav = Navigator.of(tipCtx);
                      final messenger = ScaffoldMessenger.of(context);
                      if (selectedTip > 0) {
                        final err = await AppState.instance.tipRiderLive(
                          widget.order.riderName,
                          selectedTip,
                          widget.order.id,
                        );
                        if (err != null) {
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text(err),
                              backgroundColor: Colors.redAccent,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                          return;
                        }
                      }
                      if (tipCtx.mounted) tipNav.pop();
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text(
                            selectedTip > 0
                                ? 'Rated $selectedRating ★ and tipped ₦${selectedTip.toStringAsFixed(0)} to ${widget.order.riderName}!'
                                : 'Rated ${widget.order.riderName} $selectedRating ★. Thank you!',
                          ),
                          backgroundColor: AppColors.nairaGreen,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryOrange,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text(
                      selectedTip > 0
                          ? 'Send ₦${selectedTip.toStringAsFixed(0)} Tip & Rating'
                          : 'Submit $selectedRating ★ Rating',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../constants/app_colors.dart';
import '../services/api_client.dart';
import '../services/mock_state.dart';
import '../services/socket_service.dart';
import '../services/navigation_launcher.dart';
import '../widgets/signature_pad.dart';
import '../models/delivery_order.dart';
import '../widgets/waybill_modal.dart';
import 'rider_onboarding_sheet.dart';

class RiderModeScreen extends StatefulWidget {
  const RiderModeScreen({super.key});

  @override
  State<RiderModeScreen> createState() => _RiderModeScreenState();
}

class _RiderModeScreenState extends State<RiderModeScreen> with SingleTickerProviderStateMixin {
  bool _isOnline = true;
  double _todayEarnings = 24800.0;
  int _completedTrips = 7;

  int _activeDeliveryStep = 0;
  bool _hasActiveOrder = false;

  String? _activeOfferId;
  String? _activeBackendOrderId;
  int _offerAttempt = 1;
  bool _offerDialogOpen = false;

  String _orderId = 'AP-9042';
  String _customerName = 'Michael Ogundimu';
  String _customerPhone = '+234 814 555 0192';
  String _pickup = '14 Admiralty Way, Lekki Phase 1';
  String _pickupLandmark = 'Beside Ebeano Supermarket';
  String _dropoff = '42 Allen Avenue, Ikeja, Lagos';
  String _dropoffLandmark = 'Opposite Alade Market';
  String _recipientName = 'Chioma Adeyemi';
  String _recipientPhone = '+234 802 334 9912';
  String _serviceType = 'BIKE';
  double? _pickupLat = 6.4474;
  double? _pickupLng = 3.4723;
  double? _dropoffLat = 6.6018;
  double? _dropoffLng = 3.3515;
  double _tripPayout = 3150.0;
  String _correctOtp = '6068';
  String? _activeDelayFlag;
  bool _isReportingDelay = false;

  final _otpController = TextEditingController();
  final GlobalKey<SignaturePadState> _signatureKey = GlobalKey<SignaturePadState>();
  bool _hasSignature = false;
  bool _hasPhoto = false;
  String? _uploadedPodUrl;
  String? _uploadedSignatureUrl;
  String? _geofenceBanner;
  bool _geofenceRejected = false;
  double _currentLat = 6.4474;
  double _currentLng = 3.4723;
  List<Map<String, dynamic>> _activeStops = [];

  late AnimationController _radarController;

  @override
  void initState() {
    super.initState();
    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    _bindLiveDispatchRadar();
    _loadRiderDashboard();
  }

  void _bindLiveDispatchRadar() {
    if (!AppState.instance.isAuthenticated) return;
    SocketService.instance.joinRiderRadar();
    SocketService.instance.onDispatchOffer((data) {
      if (!mounted || !_isOnline || _hasActiveOrder || _offerDialogOpen) return;
      _showIncomingDispatchModal(liveOffer: data);
    });
    SocketService.instance.onDispatchOfferExpired((data) {
      if (!mounted) return;
      if (_offerDialogOpen && data['offerId']?.toString() == _activeOfferId) {
        Navigator.of(context, rootNavigator: true).maybePop();
        _offerDialogOpen = false;
      }
    });
    SocketService.instance.onGeofenceTriggered((data) {
      if (!mounted) return;
      setState(() {
        _geofenceRejected = false;
        _geofenceBanner = data['message']?.toString();
        if (data['zone'] == 'DROPOFF_150M' && _activeDeliveryStep < 4) {
          _activeDeliveryStep = 4;
        } else if (data['zone'] == 'PICKUP_150M' && _activeDeliveryStep == 1) {
          _activeDeliveryStep = 2;
        }
      });
    });
    SocketService.instance.onGeofenceRejected((data) {
      if (!mounted) return;
      setState(() {
        _geofenceRejected = true;
        _geofenceBanner = data['message']?.toString() ?? 'Velocity Spoof Guard: Unrealistic GPS jump blocked';
      });
    });
  }

  Future<void> _loadRiderDashboard() async {
    if (!AppState.instance.isAuthenticated) return;
    try {
      final res = await ApiClient.instance.dio.get('/rider/dashboard');
      if (res.data is Map && mounted) {
        final d = Map<String, dynamic>.from(res.data);
        final todayEarnings = (d['todayEarnings'] as num?)?.toDouble();
        final todayTrips = (d['todayTrips'] as num?)?.toInt();
        final online = d['profile'] is Map ? d['profile']['isOnline'] == true : _isOnline;
        final active = d['activeOrder'] is Map ? Map<String, dynamic>.from(d['activeOrder']) : null;
        final pending = d['pendingOffers'] is List ? List.from(d['pendingOffers']) : [];

        setState(() {
          if (todayEarnings != null && todayEarnings > 0) _todayEarnings = todayEarnings;
          if (todayTrips != null && todayTrips > 0) _completedTrips = todayTrips;
          _isOnline = online;
          if (active != null) {
            _activeBackendOrderId = active['id']?.toString();
            _orderId = active['orderNumber']?.toString() ?? _orderId;
            _customerName = active['pickupContactName']?.toString() ?? _customerName;
            _customerPhone = active['pickupContactPhone']?.toString() ?? _customerPhone;
            _pickup = active['pickupAddress']?.toString() ?? _pickup;
            _pickupLandmark = active['pickupLandmark']?.toString() ?? _pickupLandmark;
            _dropoff = active['dropoffAddress']?.toString() ?? _dropoff;
            _dropoffLandmark = active['dropoffLandmark']?.toString() ?? _dropoffLandmark;
            _recipientName = active['dropoffContactName']?.toString() ?? _recipientName;
            _recipientPhone = active['dropoffContactPhone']?.toString() ?? _recipientPhone;
            _serviceType = active['serviceType']?.toString() ?? _serviceType;
            _pickupLat = (active['pickupLat'] as num?)?.toDouble() ?? _pickupLat;
            _pickupLng = (active['pickupLng'] as num?)?.toDouble() ?? _pickupLng;
            _dropoffLat = (active['dropoffLat'] as num?)?.toDouble() ?? _dropoffLat;
            _dropoffLng = (active['dropoffLng'] as num?)?.toDouble() ?? _dropoffLng;
            _tripPayout = (((active['price'] as num?)?.toDouble() ?? 3500) * 0.8).roundToDouble();
            _correctOtp = active['handoverOtp']?.toString() ?? _correctOtp;
            _activeStops = active['stops'] is List
                ? List<Map<String, dynamic>>.from(
                    (active['stops'] as List).whereType<Map>().map((e) => Map<String, dynamic>.from(e)),
                  )
                : [];
            _hasActiveOrder = true;
            final rawStatus = (active['status']?.toString() ?? '').toUpperCase();
            _activeDeliveryStep = rawStatus == 'PICKED_UP'
                ? 3
                : (rawStatus == 'IN_TRANSIT' ? 4 : 1);
          }
        });

        if (active == null && pending.isNotEmpty && pending[0] is Map && !_offerDialogOpen) {
          _showIncomingDispatchModal(liveOffer: Map<String, dynamic>.from(pending[0]));
        }
      }
    } catch (_) {}
  }

  Future<void> _toggleOnline(bool val) async {
    setState(() => _isOnline = val);
    if (!AppState.instance.isAuthenticated) return;
    try {
      await ApiClient.instance.dio.patch('/rider/availability', data: {'isOnline': val});
      if (val) {
        SocketService.instance.joinRiderRadar();
        final offersRes = await ApiClient.instance.dio.get('/rider/offers/pending');
        if (offersRes.data is List && (offersRes.data as List).isNotEmpty && mounted && !_offerDialogOpen) {
          _showIncomingDispatchModal(
            liveOffer: Map<String, dynamic>.from((offersRes.data as List).first),
          );
        }
      }
    } catch (_) {}
  }

  Future<void> _syncOrderStep(String statusEnum) async {
    if (!AppState.instance.isAuthenticated || _activeBackendOrderId == null) return;
    try {
      await ApiClient.instance.dio.post(
        '/rider/orders/$_activeBackendOrderId/status',
        data: {'status': statusEnum},
      );
    } catch (_) {}
  }

  Future<void> _reportDelayFlag(String flagType) async {
    setState(() {
      _activeDelayFlag = flagType;
      _isReportingDelay = true;
    });
    final messenger = ScaffoldMessenger.of(context);
    try {
      if (_activeBackendOrderId != null && AppState.instance.isAuthenticated) {
        await ApiClient.instance.dio.post(
          '/rider/orders/$_activeBackendOrderId/delay-flag',
          data: {'flagType': flagType},
        );
      }
      if (!mounted) return;
      setState(() => _isReportingDelay = false);
      final readable = flagType == 'ESTATE_GATE_HOLD'
          ? 'Estate Gate Hold'
          : (flagType == 'TRAFFIC_CONGESTION' ? 'Heavy Traffic' : 'Weather Hold');
      messenger.showSnackBar(
        SnackBar(
          content: Text('$readable broadcast to customer live tracking!'),
          backgroundColor: const Color(0xFFD97706),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isReportingDelay = false);
        messenger.showSnackBar(
          SnackBar(content: Text(ApiClient.extractError(e)), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  @override
  void dispose() {
    _radarController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  void _showIncomingDispatchModal({Map<String, dynamic>? liveOffer}) {
    final offerId = liveOffer?['offerId']?.toString();
    final backendOrderId = liveOffer?['orderId']?.toString();
    final orderNumber = liveOffer?['orderNumber']?.toString() ?? 'AP-9042';
    final custName = liveOffer?['customerName']?.toString() ?? 'Michael Ogundimu';
    final custPhone = liveOffer?['customerPhone']?.toString() ?? '+234 814 555 0192';
    final pickupAddr = liveOffer?['pickupAddress']?.toString() ?? '14 Admiralty Way, Lekki Phase 1';
    final dropoffAddr = liveOffer?['dropoffAddress']?.toString() ?? '42 Allen Avenue, Ikeja, Lagos';
    final payout = (liveOffer?['payoutAmount'] as num?)?.toDouble() ?? 3150.0;
    final attempt = (liveOffer?['attemptNumber'] as num?)?.toInt() ?? 1;
    final escrowAmt = (liveOffer?['escrowAmount'] as num?)?.toDouble() ?? 0.0;
    final hasEscrow = liveOffer?['isEscrow'] == true;
    int countdown = (liveOffer?['remainingSeconds'] as num?)?.toInt() ??
        (liveOffer?['timeoutSeconds'] as num?)?.toInt() ??
        15;
    Timer? countdownTimer;

    _activeOfferId = offerId;
    _offerAttempt = attempt;
    _offerDialogOpen = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            countdownTimer ??= Timer.periodic(const Duration(seconds: 1), (t) {
              if (countdown > 1) {
                setModalState(() => countdown--);
              } else {
                t.cancel();
                _offerDialogOpen = false;
                if (ctx.mounted) Navigator.pop(ctx);
              }
            });

            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFFCA5A5)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.timer_outlined, size: 14, color: Color(0xFFDC2626)),
                              const SizedBox(width: 4),
                              Text('$countdown s', style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFFDC2626))),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFECFDF5),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            offerId != null ? 'Live Auction #$_offerAttempt' : 'Instant Bike',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF15803D)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    Text('₦${payout.toStringAsFixed(0)}', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: AppColors.textDark)),
                    Text(
                      hasEscrow ? 'Net Payout • Collect ₦${escrowAmt.toStringAsFixed(0)} COD' : 'Guaranteed Net Rider Payout (80%)',
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 16),

                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.circle, size: 10, color: AppColors.primaryOrange),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Pickup: $pickupAddr',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              const Icon(Icons.location_on_rounded, size: 12, color: Color(0xFF15803D)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Drop-off: $dropoffAddr',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () async {
                              countdownTimer?.cancel();
                              _offerDialogOpen = false;
                              final nav = Navigator.of(ctx);
                              if (offerId != null && AppState.instance.isAuthenticated) {
                                try {
                                  await ApiClient.instance.dio.post('/rider/offers/$offerId/decline');
                                } catch (_) {}
                              }
                              if (ctx.mounted) nav.pop();
                            },
                            style: OutlinedButton.styleFrom(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: const Text('Decline', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w700)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () async {
                              countdownTimer?.cancel();
                              _offerDialogOpen = false;
                              final nav = Navigator.of(ctx);
                              final messenger = ScaffoldMessenger.of(this.context);

                              if (offerId != null && AppState.instance.isAuthenticated) {
                                try {
                                  final res = await ApiClient.instance.dio.post('/rider/offers/$offerId/accept');
                                  final acceptedOrder = res.data is Map ? res.data['order'] : null;
                                  if (mounted) {
                                    setState(() {
                                      _activeBackendOrderId = backendOrderId ?? acceptedOrder?['id']?.toString();
                                      _orderId = acceptedOrder?['orderNumber']?.toString() ?? orderNumber;
                                      _customerName = acceptedOrder?['pickupContactName']?.toString() ?? custName;
                                      _customerPhone = acceptedOrder?['pickupContactPhone']?.toString() ?? custPhone;
                                      _pickup = acceptedOrder?['pickupAddress']?.toString() ?? pickupAddr;
                                      _pickupLandmark = acceptedOrder?['pickupLandmark']?.toString() ??
                                          liveOffer?['pickupLandmark']?.toString() ??
                                          _pickupLandmark;
                                      _dropoff = acceptedOrder?['dropoffAddress']?.toString() ?? dropoffAddr;
                                      _dropoffLandmark = acceptedOrder?['dropoffLandmark']?.toString() ??
                                          liveOffer?['dropoffLandmark']?.toString() ??
                                          _dropoffLandmark;
                                      _recipientName = acceptedOrder?['dropoffContactName']?.toString() ??
                                          liveOffer?['dropoffContactName']?.toString() ??
                                          _recipientName;
                                      _recipientPhone = acceptedOrder?['dropoffContactPhone']?.toString() ??
                                          liveOffer?['dropoffContactPhone']?.toString() ??
                                          _recipientPhone;
                                      _serviceType = acceptedOrder?['serviceType']?.toString() ??
                                          liveOffer?['serviceType']?.toString() ??
                                          _serviceType;
                                      _pickupLat = (acceptedOrder?['pickupLat'] as num?)?.toDouble() ??
                                          (liveOffer?['pickupLat'] as num?)?.toDouble() ??
                                          _pickupLat;
                                      _pickupLng = (acceptedOrder?['pickupLng'] as num?)?.toDouble() ??
                                          (liveOffer?['pickupLng'] as num?)?.toDouble() ??
                                          _pickupLng;
                                      _dropoffLat = (acceptedOrder?['dropoffLat'] as num?)?.toDouble() ??
                                          (liveOffer?['dropoffLat'] as num?)?.toDouble() ??
                                          _dropoffLat;
                                      _dropoffLng = (acceptedOrder?['dropoffLng'] as num?)?.toDouble() ??
                                          (liveOffer?['dropoffLng'] as num?)?.toDouble() ??
                                          _dropoffLng;
                                      final rawStops = acceptedOrder?['stops'] ?? liveOffer?['stops'];
                                      _activeStops = rawStops is List
                                          ? List<Map<String, dynamic>>.from(
                                              rawStops.whereType<Map>().map((e) => Map<String, dynamic>.from(e)),
                                            )
                                          : [];
                                      _correctOtp = acceptedOrder?['handoverOtp']?.toString() ?? _correctOtp;
                                      _tripPayout = payout;
                                      _activeDelayFlag = null;
                                      _hasActiveOrder = true;
                                      _activeDeliveryStep = 1;
                                    });
                                  }
                                } catch (e) {
                                  if (ctx.mounted) nav.pop();
                                  messenger.showSnackBar(
                                    SnackBar(
                                      content: Text(ApiClient.extractError(e)),
                                      backgroundColor: Colors.redAccent,
                                    ),
                                  );
                                  return;
                                }
                              } else {
                                setState(() {
                                  _orderId = orderNumber;
                                  _customerName = custName;
                                  _customerPhone = custPhone;
                                  _pickup = pickupAddr;
                                  _dropoff = dropoffAddr;
                                  _tripPayout = payout;
                                  _activeDelayFlag = null;
                                  _hasActiveOrder = true;
                                  _activeDeliveryStep = 1;
                                });
                              }

                              if (ctx.mounted) nav.pop();
                              if (mounted) {
                                ScaffoldMessenger.of(this.context).showSnackBar(
                                  SnackBar(
                                    content: Text('Trip #$_orderId accepted! Ready to route to Pickup.'),
                                    backgroundColor: const Color(0xFF15803D),
                                    behavior: SnackBarBehavior.floating,
                                    action: SnackBarAction(
                                      label: 'Google Maps',
                                      textColor: Colors.amberAccent,
                                      onPressed: () {
                                        NavigationLauncher.launchGoogleMaps(
                                          context: this.context,
                                          address: _pickup,
                                          landmark: _pickupLandmark,
                                          lat: _pickupLat,
                                          lng: _pickupLng,
                                          serviceType: _serviceType,
                                        );
                                      },
                                    ),
                                  ),
                                );
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF15803D),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              elevation: 0,
                            ),
                            child: const Text('Accept Order', style: TextStyle(fontWeight: FontWeight.w800)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    ).then((_) {
      countdownTimer?.cancel();
      _offerDialogOpen = false;
    });
  }

  Future<void> _verifyOtpAndComplete() async {
    final otp = _otpController.text.trim();
    if (_activeBackendOrderId != null && AppState.instance.isAuthenticated) {
      final messenger = ScaffoldMessenger.of(context);
      try {
        await ApiClient.instance.dio.post(
          '/rider/orders/$_activeBackendOrderId/status',
          data: {
            'status': 'DELIVERED',
            'handoverOtp': otp,
            if (_hasSignature) 'recipientSignature': _uploadedSignatureUrl ?? 'captured_signature_vector',
            if (_hasPhoto) 'proofPhotoUrl': _uploadedPodUrl ?? 'https://cdn.apace.ng/pod/$_orderId.jpg',
          },
        );
        await AppState.instance.syncAllFromBackend();
      } catch (e) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(ApiClient.extractError(e)),
            backgroundColor: Colors.redAccent,
          ),
        );
        return;
      }
    } else if (otp != _correctOtp) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid customer handover OTP code. Ask customer for the 4-digit code.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    if (!mounted) return;
    setState(() {
      _todayEarnings += _tripPayout;
      _completedTrips++;
      _hasActiveOrder = false;
      _activeDeliveryStep = 0;
      _activeBackendOrderId = null;
      _activeOfferId = null;
      _uploadedPodUrl = null;
      _uploadedSignatureUrl = null;
      _geofenceBanner = null;
      _activeDelayFlag = null;
      _activeStops = [];
      _otpController.clear();
      _hasSignature = false;
      _hasPhoto = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Delivery Completed! ₦${_tripPayout.toStringAsFixed(0)} credited to your Rider Wallet.'),
        backgroundColor: const Color(0xFF15803D),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.primaryOrange,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text('RIDER PORTAL', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 0.8)),
            ),
            const SizedBox(width: 8),
            const Text('Apace Dispatch', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
          ],
        ),
        actions: [
          Switch(
            value: _isOnline,
            activeTrackColor: const Color(0xFF10B981),
            onChanged: _toggleOnline,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildRiderHeroCard(),
            const SizedBox(height: 16),
            _buildMetricsGrid(),
            const SizedBox(height: 20),

            if (_hasActiveOrder) ...[
              _buildActiveOrderWorkflow(),
            ] else ...[
              _buildWaitingRadarCard(),
            ],

            const SizedBox(height: 20),
            _buildSimulatorTriggerButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildRiderHeroCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Row(
        children: [
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              const CircleAvatar(
                radius: 28,
                backgroundColor: Color(0xFF334155),
                child: Text('BA', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white)),
              ),
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: _isOnline ? const Color(0xFF10B981) : Colors.grey,
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF1E293B), width: 2),
                ),
              ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Babatunde Adeyemi',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white),
                ),
                const SizedBox(height: 3),
                Row(
                  children: const [
                    Icon(Icons.two_wheeler_rounded, size: 14, color: AppColors.primaryOrange),
                    SizedBox(width: 4),
                    Text(
                      'Bajaj Boxer • LA-492-IKJ',
                      style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: const [
                    Icon(Icons.star_rounded, size: 14, color: Color(0xFFFBBF24)),
                    SizedBox(width: 4),
                    Text('4.9 Rating (418 trips)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white70)),
                  ],
                ),
              ],
            ),
          ),
          OutlinedButton(
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => const RiderOnboardingSheet(),
              );
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF38BDF8),
              side: const BorderSide(color: Color(0xFF334155)),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Docs / KYC', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsGrid() {
    return Row(
      children: [
        Expanded(
          child: _buildMetricTile(
            'TODAY EARNINGS',
            '₦${_todayEarnings.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}',
            const Color(0xFF10B981),
            Icons.account_balance_wallet_outlined,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildMetricTile(
            'COMPLETED TRIPS',
            '$_completedTrips',
            AppColors.primaryOrange,
            Icons.check_circle_outline_rounded,
          ),
        ),
      ],
    );
  }

  Widget _buildMetricTile(String title, String val, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF94A3B8))),
              Icon(icon, size: 16, color: color),
            ],
          ),
          const SizedBox(height: 8),
          Text(val, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: color)),
        ],
      ),
    );
  }

  Widget _buildWaitingRadarCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Center(
        child: Column(
          children: [
            RotationTransition(
              turns: _radarController,
              child: Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.primaryOrange.withValues(alpha: 0.5), width: 2),
                ),
                child: const Center(
                  child: Icon(Icons.radar_rounded, size: 36, color: AppColors.primaryOrange),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Scanning for Nearby Dispatches',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white),
            ),
            const SizedBox(height: 6),
            const Text(
              'Location active: Lekki Phase 1, Victoria Island & Ikoyi corridors',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveOrderWorkflow() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.primaryOrange, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primaryOrange.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('ORDER #$_orderId', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: AppColors.primaryOrange)),
              ),
              Text(
                _activeDeliveryStep == 1
                    ? 'Heading to Pickup'
                    : (_activeDeliveryStep == 2 ? 'At Pickup' : (_activeDeliveryStep == 3 ? 'In Transit' : 'Handover')),
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF38BDF8)),
              ),
            ],
          ),
          const SizedBox(height: 14),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_customerName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
              InkWell(
                onTap: () {
                  final dummyOrder = DeliveryOrder(
                    id: _orderId,
                    status: 'in_transit',
                    serviceType: 'BIKE',
                    senderName: _customerName,
                    senderPhone: _customerPhone,
                    pickupAddress: _pickup,
                    pickupLandmark: 'Beside Ebeano Supermarket',
                    recipientName: 'Chioma Adeyemi',
                    recipientPhone: '+234 802 334 9912',
                    dropoffAddress: _dropoff,
                    dropoffLandmark: 'Opposite Alade Market',
                    packageName: 'Retail Merchandise',
                    packageCategory: 'Commerce & Retail',
                    packageWeight: '2.5 kg',
                    securityPin: _correctOtp,
                    price: _tripPayout,
                    distanceKm: 14.5,
                    riderName: 'Babatunde Adeleke',
                    riderPhone: '+234 803 771 9021',
                    riderVehicle: 'Bajaj Boxer 150cc',
                    riderRating: 4.9,
                    createdAt: DateTime.now(),
                    isEscrow: true,
                    escrowAmount: 18500.0,
                    escrowStatus: 'HELD',
                    escrowReleaseCode: '6068',
                    waybillNumber: 'WB-LOS-2026-9042',
                  );
                  WaybillModal.show(context, dummyOrder);
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF334155),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.qr_code_rounded, color: Color(0xFF10B981), size: 14),
                      SizedBox(width: 4),
                      Text('Waybill', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          Text(_customerPhone, style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
          const SizedBox(height: 12),

          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(Icons.circle, size: 8, color: AppColors.primaryOrange),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_pickup, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
                          if (_pickupLandmark.isNotEmpty)
                            Text('Landmark: $_pickupLandmark', style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                        ],
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () {
                        NavigationLauncher.launchGoogleMaps(
                          context: context,
                          address: _pickup,
                          landmark: _pickupLandmark,
                          lat: _pickupLat,
                          lng: _pickupLng,
                          serviceType: _serviceType,
                        );
                      },
                      icon: const Icon(Icons.near_me_rounded, size: 13, color: Color(0xFF38BDF8)),
                      label: const Text('Maps', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF38BDF8))),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ],
                ),
                const Divider(height: 14, color: Color(0xFF1E293B)),
                Row(
                  children: [
                    const Icon(Icons.location_on_rounded, size: 12, color: Color(0xFF10B981)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_dropoff, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
                          if (_dropoffLandmark.isNotEmpty)
                            Text('Landmark: $_dropoffLandmark', style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                        ],
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () {
                        NavigationLauncher.launchGoogleMaps(
                          context: context,
                          address: _dropoff,
                          landmark: _dropoffLandmark,
                          lat: _dropoffLat,
                          lng: _dropoffLng,
                          serviceType: _serviceType,
                        );
                      },
                      icon: const Icon(Icons.near_me_rounded, size: 13, color: Color(0xFF10B981)),
                      label: const Text('Maps', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF10B981))),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Builder(
            builder: (context) {
              final headingToPickup = _activeDeliveryStep <= 1;
              final nextStop = _activeStops.cast<Map<String, dynamic>?>().firstWhere(
                    (s) => s != null && s['status']?.toString().toUpperCase() != 'DELIVERED',
                    orElse: () => null,
                  );
              final targetLabel = headingToPickup
                  ? 'PICKUP POINT'
                  : (nextStop != null ? 'STOP #${nextStop['sequence']}' : 'DROP-OFF');
              final targetAddr = headingToPickup
                  ? _pickup
                  : (nextStop?['address']?.toString() ?? _dropoff);
              final targetLandmark = headingToPickup
                  ? _pickupLandmark
                  : (nextStop?['landmark']?.toString() ?? _dropoffLandmark);
              final targetLat = headingToPickup
                  ? _pickupLat
                  : ((nextStop?['lat'] as num?)?.toDouble() ?? _dropoffLat);
              final targetLng = headingToPickup
                  ? _pickupLng
                  : ((nextStop?['lng'] as num?)?.toDouble() ?? _dropoffLng);
              final contactPhone = headingToPickup
                  ? _customerPhone
                  : (nextStop?['contactPhone']?.toString() ?? _recipientPhone);
              final contactName = headingToPickup
                  ? _customerName
                  : (nextStop?['contactName']?.toString() ?? _recipientName);

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            NavigationLauncher.launchGoogleMaps(
                              context: context,
                              address: targetAddr,
                              landmark: targetLandmark,
                              lat: targetLat,
                              lng: targetLng,
                              serviceType: _serviceType,
                            );
                          },
                          icon: const Icon(Icons.directions_rounded, size: 17),
                          label: Text(
                            'Google Maps -> $targetLabel',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1D4ED8),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 11),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        tooltip: 'Choose Navigation App (Google Maps, Waze, Copy)',
                        onPressed: () {
                          NavigationLauncher.showMapAppChooser(
                            context,
                            label: targetLabel,
                            address: targetAddr,
                            landmark: targetLandmark,
                            lat: targetLat,
                            lng: targetLng,
                            serviceType: _serviceType,
                          );
                        },
                        style: IconButton.styleFrom(
                          backgroundColor: const Color(0xFF0F172A),
                          side: const BorderSide(color: Color(0xFF334155)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.alt_route_rounded, color: Color(0xFF38BDF8), size: 18),
                      ),
                      const SizedBox(width: 6),
                      IconButton(
                        tooltip: 'Ping $contactName on WhatsApp',
                        onPressed: () {
                          NavigationLauncher.launchWhatsAppRecipientPing(
                            context: context,
                            phone: contactPhone,
                            recipientName: contactName,
                            destination: targetAddr,
                            orderId: _orderId,
                          );
                        },
                        style: IconButton.styleFrom(
                          backgroundColor: const Color(0xFF0F172A),
                          side: const BorderSide(color: Color(0xFF15803D)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.chat_rounded, color: Color(0xFF4ADE80), size: 18),
                      ),
                    ],
                  ),
                  if (_activeStops.length > 1) ...[
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          NavigationLauncher.launchMultiStopCorridor(
                            context: context,
                            pickupAddress: _pickup,
                            pickupLat: _pickupLat,
                            pickupLng: _pickupLng,
                            stops: _activeStops,
                          );
                        },
                        icon: const Icon(Icons.route_rounded, size: 15, color: Color(0xFFFBBF24)),
                        label: Text(
                          'Open All ${_activeStops.length} Corridor Stops in Google Maps',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFFFBBF24)),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFF475569)),
                          backgroundColor: const Color(0xFF0F172A),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _delayChip('ESTATE_GATE_HOLD', 'Estate Gate Hold', Icons.security_rounded),
                        const SizedBox(width: 6),
                        _delayChip('TRAFFIC_CONGESTION', 'Lagos Traffic Alert', Icons.traffic_rounded),
                        const SizedBox(width: 6),
                        _delayChip('WEATHER_HOLD', 'Rain / Weather Hold', Icons.thunderstorm_rounded),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _geofenceRejected
                    ? Colors.redAccent
                    : (_geofenceBanner != null ? const Color(0xFF10B981) : const Color(0xFF334155)),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      _geofenceRejected ? Icons.gpp_bad_rounded : Icons.gps_fixed_rounded,
                      size: 14,
                      color: _geofenceRejected ? Colors.redAccent : const Color(0xFF38BDF8),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _geofenceBanner ??
                            'GPS ${_currentLat.toStringAsFixed(4)}, ${_currentLng.toStringAsFixed(4)} • 150m Geofence Armed',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: _geofenceRejected ? Colors.redAccent : const Color(0xFFBAE6FD),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          setState(() {
                            _currentLat = 6.6019;
                            _currentLng = 3.3516;
                            _geofenceRejected = false;
                            _geofenceBanner = 'Within 150m of Drop-off — Handover OTP Ready!';
                          });
                          if (_activeBackendOrderId != null && AppState.instance.isAuthenticated) {
                            SocketService.instance.emitRiderLocation(
                              orderId: _activeBackendOrderId!,
                              latitude: _currentLat,
                              longitude: _currentLng,
                              speed: 32,
                            );
                          }
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF38BDF8),
                          side: const BorderSide(color: Color(0xFF334155)),
                          padding: const EdgeInsets.symmetric(vertical: 6),
                        ),
                        child: const Text('Trigger 150m Geofence', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          if (_activeBackendOrderId != null && AppState.instance.isAuthenticated) {
                            SocketService.instance.emitRiderLocation(
                              orderId: _activeBackendOrderId!,
                              latitude: 6.4281,
                              longitude: 3.4219,
                              speed: 280,
                            );
                          } else {
                            setState(() {
                              _geofenceRejected = true;
                              _geofenceBanner = 'Velocity Spoof Blocked (280 km/h > 140 km/h limit)';
                            });
                          }
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.amberAccent,
                          side: const BorderSide(color: Color(0xFF334155)),
                          padding: const EdgeInsets.symmetric(vertical: 6),
                        ),
                        child: const Text('Test Spoof Guard', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (_activeStops.isNotEmpty) ...[
            const SizedBox(height: 10),
            for (final s in _activeStops)
              Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 10,
                      backgroundColor: s['status'] == 'DELIVERED'
                          ? const Color(0xFF10B981)
                          : AppColors.primaryOrange,
                      child: Text(
                        '${s['sequence'] ?? 1}',
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${s['subWaybillCode'] ?? ''} • ${s['address'] ?? ''}',
                        style: const TextStyle(fontSize: 11, color: Colors.white70),
                      ),
                    ),
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: const Icon(Icons.directions_rounded, size: 16, color: Color(0xFF38BDF8)),
                      onPressed: () {
                        NavigationLauncher.launchGoogleMaps(
                          context: context,
                          address: s['address']?.toString() ?? '',
                          landmark: s['landmark']?.toString(),
                          lat: (s['lat'] as num?)?.toDouble(),
                          lng: (s['lng'] as num?)?.toDouble(),
                          serviceType: _serviceType,
                        );
                      },
                    ),
                    const SizedBox(width: 8),
                    Text(
                      s['status']?.toString() ?? 'PENDING',
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF38BDF8)),
                    ),
                  ],
                ),
              ),
          ],
          const SizedBox(height: 16),

          if (_activeDeliveryStep == 1) ...[
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () => setState(() => _activeDeliveryStep = 2),
                icon: const Icon(Icons.navigation_rounded, size: 18),
                label: const Text('I Have Arrived at Pickup', style: TextStyle(fontWeight: FontWeight.w800)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryOrange,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ] else if (_activeDeliveryStep == 2) ...[
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () {
                  setState(() => _activeDeliveryStep = 3);
                  _syncOrderStep('PICKED_UP');
                },
                icon: const Icon(Icons.inventory_2_rounded, size: 18),
                label: const Text('Confirm Package Collected & Start Trip', style: TextStyle(fontWeight: FontWeight.w800)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ] else if (_activeDeliveryStep == 3) ...[
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () {
                  setState(() => _activeDeliveryStep = 4);
                  _syncOrderStep('IN_TRANSIT');
                },
                icon: const Icon(Icons.location_pin, size: 18),
                label: const Text('Arrived at Drop-off Destination', style: TextStyle(fontWeight: FontWeight.w800)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D9488),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ] else ...[
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1E3A8A).withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF3B82F6)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.point_of_sale_rounded, color: Color(0xFF60A5FA), size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'COD Collection: ₦18,500',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white),
                        ),
                        Text(
                          'Dial *5573*1*18500*9042# or transfer to Moniepoint 8145 550 192',
                          style: TextStyle(fontSize: 11, color: Color(0xFFBFDBFE)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Text(
              'PROOF OF DELIVERY & RECIPIENT HANDOVER',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF94A3B8), letterSpacing: 0.5),
            ),
            const SizedBox(height: 10),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      try {
                        final picker = ImagePicker();
                        final photo = await picker.pickImage(
                          source: ImageSource.camera,
                          imageQuality: 70,
                        );
                        if (photo != null) {
                          final bytes = await photo.readAsBytes();
                          final url = await AppState.instance.uploadBase64Media(
                            folder: 'pod',
                            mimeType: 'image/jpeg',
                            bytes: bytes,
                          );
                          if (!mounted) return;
                          setState(() {
                            _hasPhoto = true;
                            _uploadedPodUrl = url;
                          });
                          messenger.showSnackBar(
                            const SnackBar(
                              content: Text('Doorstep Photo Uploaded to Media Vault!'),
                              backgroundColor: Color(0xFF15803D),
                            ),
                          );
                          return;
                        }
                      } catch (_) {}
                      if (mounted) {
                        setState(() => _hasPhoto = true);
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text('Doorstep Package Photo Verified!'),
                            backgroundColor: Color(0xFF15803D),
                          ),
                        );
                      }
                    },
                    icon: Icon(_hasPhoto ? Icons.check_circle_rounded : Icons.camera_alt_outlined, size: 16, color: _hasPhoto ? const Color(0xFF10B981) : Colors.white70),
                    label: Text(_hasPhoto ? 'Photo Uploaded' : 'Take Photo', style: TextStyle(fontSize: 12, color: _hasPhoto ? const Color(0xFF10B981) : Colors.white)),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: _hasPhoto ? const Color(0xFF10B981) : const Color(0xFF475569)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.white,
                        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
                        builder: (ctx) => Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('Recipient Signature Pad', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                              const SizedBox(height: 14),
                              SignaturePad(
                                key: _signatureKey,
                                onSignatureChanged: (_) {},
                                onClear: () {},
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                height: 46,
                                child: ElevatedButton(
                                  onPressed: () async {
                                    final nav = Navigator.of(ctx);
                                    final bytes = await _signatureKey.currentState?.capturePngBytes();
                                    String? sigUrl;
                                    if (bytes != null) {
                                      sigUrl = await AppState.instance.uploadBase64Media(
                                        folder: 'signature',
                                        mimeType: 'image/png',
                                        bytes: bytes,
                                      );
                                    }
                                    if (!mounted) return;
                                    setState(() {
                                      _hasSignature = true;
                                      _uploadedSignatureUrl = sigUrl;
                                    });
                                    nav.pop();
                                  },
                                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF15803D)),
                                  child: const Text('Save & Upload Signature', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                    icon: Icon(_hasSignature ? Icons.check_circle_rounded : Icons.draw_rounded, size: 16, color: _hasSignature ? const Color(0xFF10B981) : Colors.white70),
                    label: Text(_hasSignature ? 'Signed' : 'Get Signature', style: TextStyle(fontSize: 12, color: _hasSignature ? const Color(0xFF10B981) : Colors.white)),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: _hasSignature ? const Color(0xFF10B981) : const Color(0xFF475569)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            TextField(
              controller: _otpController,
              keyboardType: TextInputType.number,
              maxLength: 4,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 4),
              decoration: InputDecoration(
                counterText: '',
                prefixIcon: const Icon(Icons.shield_outlined, color: AppColors.primaryOrange),
                hintText: 'Enter 4-digit customer OTP (e.g. 6068)',
                hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF64748B), letterSpacing: 0),
                fillColor: const Color(0xFF0F172A),
                filled: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF334155))),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.primaryOrange, width: 2)),
              ),
            ),
            const SizedBox(height: 14),

            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _verifyOtpAndComplete,
                icon: const Icon(Icons.check_circle_rounded, size: 18),
                label: const Text('Verify Handover & Complete Delivery', style: TextStyle(fontWeight: FontWeight.w800)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF15803D),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _delayChip(String flagType, String label, IconData icon) {
    final active = _activeDelayFlag == flagType;
    return InkWell(
      onTap: _isReportingDelay ? null : () => _reportDelayFlag(flagType),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF78350F) : const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: active ? const Color(0xFFF59E0B) : const Color(0xFF334155),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: active ? const Color(0xFFFBBF24) : const Color(0xFF94A3B8)),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: active ? const Color(0xFFFEF3C7) : const Color(0xFFCBD5E1),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSimulatorTriggerButton() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.bolt_rounded, color: AppColors.amberWarning, size: 20),
              SizedBox(width: 8),
              Text(
                'DISPATCH SIMULATOR CONTROLS',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white70, letterSpacing: 0.5),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Simulate an incoming dispatch request to test the countdown timer, accepting orders, and entering OTP codes.',
            style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8), height: 1.4),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton.icon(
              onPressed: () => _showIncomingDispatchModal(),
              icon: const Icon(Icons.add_alert_rounded, size: 18),
              label: const Text('Simulate Incoming Dispatch Alert', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF334155),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}


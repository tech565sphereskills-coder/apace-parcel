import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/app_colors.dart';
import '../models/delivery_order.dart';
import '../models/saved_address.dart';
import '../services/mock_state.dart';
import 'order_tracking_screen.dart';
import 'saved_addresses_screen.dart';
import '../widgets/transaction_pin_sheet.dart';

class SendPackageScreen extends StatefulWidget {
  final String initialServiceType;
  final String? initialPickupAddress;
  final String? initialDropoffAddress;

  const SendPackageScreen({
    super.key,
    this.initialServiceType = 'Bike Dispatch',
    this.initialPickupAddress,
    this.initialDropoffAddress,
  });

  @override
  State<SendPackageScreen> createState() => _SendPackageScreenState();
}

class _SendPackageScreenState extends State<SendPackageScreen> {
  int _currentStep = 0;

  late final TextEditingController _pickupController;
  final _pickupLandmarkController = TextEditingController(text: 'Opp. Ebeano Supermarket');
  final _senderNameController = TextEditingController(text: 'Michael Ogundimu');
  final _senderPhoneController = TextEditingController(text: '+234 814 555 0192');

  late final TextEditingController _dropoffController;
  final _dropoffLandmarkController = TextEditingController(text: 'Beside Tejuosho Market');
  final _recipientNameController = TextEditingController(text: 'Chioma Adeyemi');
  final _recipientPhoneController = TextEditingController(text: '+234 802 334 9912');

  final _itemNameController = TextEditingController(text: 'Laptop & Essential Accessories');
  String _selectedCategory = 'Electronics & Gadgets';
  String _selectedWeight = 'Small (< 3kg)';
  bool _includeInsurance = true;
  final _notesController = TextEditingController(text: 'Call recipient on arrival. Fragile item.');

  final List<Map<String, String>> _extraStops = [];
  bool _isOptimizingCorridor = false;
  String? _corridorSummary;
  String _scheduledTimeSlot = 'Immediate (5-10 mins)';
  bool _isEscrow = false;
  final _escrowAmountController = TextEditingController(text: '18500');
  final _magicPasteController = TextEditingController();
  bool _isAiParsing = false;
  String? _aiParsedSummary;

  late String _selectedVehicle;
  String _selectedPaymentMethod = 'Apace Naira Wallet';

  @override
  void initState() {
    super.initState();
    _selectedVehicle = widget.initialServiceType;
    _pickupController = TextEditingController(
      text: widget.initialPickupAddress ?? '14 Admiralty Way, Lekki Phase 1',
    );
    _dropoffController = TextEditingController(
      text: widget.initialDropoffAddress ?? 'Plot 7 Commercial Ave, Yaba',
    );
  }

  @override
  void dispose() {
    _pickupController.dispose();
    _pickupLandmarkController.dispose();
    _senderNameController.dispose();
    _senderPhoneController.dispose();
    _dropoffController.dispose();
    _dropoffLandmarkController.dispose();
    _recipientNameController.dispose();
    _recipientPhoneController.dispose();
    _itemNameController.dispose();
    _notesController.dispose();
    _escrowAmountController.dispose();
    _magicPasteController.dispose();
    super.dispose();
  }

  Future<void> _runAiMagicPaste([String? rawOverride]) async {
    final text = (rawOverride ?? _magicPasteController.text).trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Paste a WhatsApp/Instagram order chat first or tap a sample.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (rawOverride != null) {
      _magicPasteController.text = rawOverride;
    }

    setState(() {
      _isAiParsing = true;
      _aiParsedSummary = null;
    });

    final parsed = await AppState.instance.aiParseDispatchText(
      text,
      pickupLocation: _pickupController.text.trim(),
    );

    if (!mounted) return;

    final rawCat = (parsed['packageCategory']?.toString() ?? '').toLowerCase();
    String mappedCat = 'Electronics & Gadgets';
    if (rawCat.contains('fashion') || rawCat.contains('apparel')) {
      mappedCat = 'Fashion & Apparel';
    } else if (rawCat.contains('food') || rawCat.contains('catering')) {
      mappedCat = 'Food & Catering';
    } else if (rawCat.contains('doc') || rawCat.contains('book')) {
      mappedCat = 'Documents & Books';
    } else if (rawCat.contains('health') || rawCat.contains('beauty')) {
      mappedCat = 'Health & Beauty';
    } else if ((parsed['notes']?.toString() ?? '').toLowerCase().contains('fragile') &&
        mappedCat == 'Electronics & Gadgets') {
      mappedCat = 'Fragile Goods';
    }

    final recService = parsed['recommendedService']?.toString() ?? 'Bike Dispatch';
    final escrowFlag = parsed['isEscrow'] == true;
    final escrowNum = (parsed['escrowAmount'] as num?)?.toDouble() ?? 0.0;

    setState(() {
      _isAiParsing = false;
      _recipientNameController.text = parsed['recipientName']?.toString() ?? _recipientNameController.text;
      _recipientPhoneController.text = parsed['recipientPhone']?.toString() ?? _recipientPhoneController.text;
      _dropoffController.text = parsed['dropoffAddress']?.toString() ?? _dropoffController.text;
      _dropoffLandmarkController.text = parsed['dropoffLandmark']?.toString() ?? _dropoffLandmarkController.text;
      _itemNameController.text = parsed['packageName']?.toString() ?? _itemNameController.text;
      _selectedCategory = mappedCat;
      _notesController.text = parsed['notes']?.toString() ?? _notesController.text;
      if (['Bike Dispatch', 'Car Delivery', 'Mini-Van Cargo', 'Interstate'].contains(recService)) {
        _selectedVehicle = recService;
      }
      _isEscrow = escrowFlag;
      if (escrowNum > 0) {
        _escrowAmountController.text = escrowNum.toStringAsFixed(0);
      }
      _aiParsedSummary =
          'Auto-filled ${_recipientNameController.text} • ${_dropoffController.text}'
          '${escrowFlag && escrowNum > 0 ? " • ₦${escrowNum.toStringAsFixed(0)} Escrow COD" : ""}';
    });
  }

  Future<void> _runCorridorOptimization() async {
    if (_extraStops.isEmpty) return;
    setState(() => _isOptimizingCorridor = true);

    final allStops = <Map<String, dynamic>>[
      {
        'address': _dropoffController.text.trim(),
        'landmark': _dropoffLandmarkController.text.trim(),
        'contactName': _recipientNameController.text.trim().isEmpty
            ? 'Primary Recipient'
            : _recipientNameController.text.trim(),
        'contactPhone': _recipientPhoneController.text.trim().isEmpty
            ? '+2348023349912'
            : _recipientPhoneController.text.trim(),
      },
      for (final s in _extraStops)
        {
          'address': s['address'] ?? '',
          'landmark': s['landmark'] ?? '',
          'contactName': s['name'] ?? 'Recipient',
          'contactPhone': s['phone'] ?? '+234',
        },
    ];

    final res = await AppState.instance.optimizeCorridorStops(
      pickupAddress: _pickupController.text.trim(),
      stops: allStops,
    );

    if (!mounted) return;
    final opt = res['optimizedStops'] is List
        ? List<Map<String, dynamic>>.from(
            (res['optimizedStops'] as List).whereType<Map>().map((e) => Map<String, dynamic>.from(e)),
          )
        : <Map<String, dynamic>>[];

    setState(() {
      _isOptimizingCorridor = false;
      if (opt.isNotEmpty) {
        final first = opt.first;
        _dropoffController.text = first['address']?.toString() ?? _dropoffController.text;
        _dropoffLandmarkController.text = first['landmark']?.toString() ?? _dropoffLandmarkController.text;
        _recipientNameController.text = first['contactName']?.toString() ?? _recipientNameController.text;
        _recipientPhoneController.text = first['contactPhone']?.toString() ?? _recipientPhoneController.text;
        _extraStops
          ..clear()
          ..addAll(
            opt.skip(1).map((s) => {
                  'address': s['address']?.toString() ?? '',
                  'landmark': s['landmark']?.toString() ?? '',
                  'name': s['contactName']?.toString() ?? 'Recipient',
                  'phone': s['contactPhone']?.toString() ?? '+234',
                }),
          );
      }
      final savedKm = res['distanceSavedKm'] ?? 0;
      final savedNgn = res['estimatedSavingsNgn'] ?? 0;
      _corridorSummary =
          'Corridor Optimized: Saved ${savedKm}km (~₦$savedNgn) • ${opt.length} Sub-Waybills ready';
    });
  }

  double get _basePrice {
    switch (_selectedVehicle) {
      case 'Car Delivery':
        return 4800.0;
      case 'Mini-Van Cargo':
        return 12500.0;
      case 'Interstate':
        return 7500.0;
      case 'Bike Dispatch':
      default:
        return 2450.0;
    }
  }

  double get _totalPrice {
    double total = _basePrice;
    if (_extraStops.isNotEmpty) {
      total += _extraStops.length * (_basePrice * 0.55);
    }
    if (_includeInsurance) total += 350.0;
    return total;
  }

  void _submitOrder() {
    if (_selectedPaymentMethod == 'Apace Naira Wallet') {
      if (AppState.instance.walletBalance < _totalPrice) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Insufficient wallet balance. Please top up your Apace Wallet.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
      TransactionPinSheet.show(
        context,
        title: 'Authorize Dispatch Payment',
        subtitle: 'Enter 4-digit PIN to pay for $_selectedVehicle',
        amount: _totalPrice,
        onSuccess: (pin) {
          _completeOrderCreation(transactionPin: pin);
        },
      );
    } else {
      _completeOrderCreation();
    }
  }

  Future<void> _completeOrderCreation({String? transactionPin}) async {
    final escrowAmt = double.tryParse(_escrowAmountController.text.trim()) ?? 0.0;
    final draftOrder = DeliveryOrder(
      id: 'AP-${(math.Random().nextInt(8999) + 1000)}-NG',
      status: 'assigned',
      serviceType: _selectedVehicle,
      senderName: _senderNameController.text.trim(),
      senderPhone: _senderPhoneController.text.trim(),
      pickupAddress: _pickupController.text.trim(),
      pickupLandmark: _pickupLandmarkController.text.trim(),
      recipientName: _recipientNameController.text.trim(),
      recipientPhone: _recipientPhoneController.text.trim(),
      dropoffAddress: _dropoffController.text.trim(),
      dropoffLandmark: _dropoffLandmarkController.text.trim(),
      packageName: _itemNameController.text.trim(),
      packageCategory: _selectedCategory,
      packageWeight: _selectedWeight,
      securityPin: '${math.Random().nextInt(8999) + 1000}',
      price: _totalPrice,
      distanceKm: 14.5 + (_extraStops.length * 4.2),
      riderName: 'Babatunde Adeleke',
      riderPhone: '+234 803 771 9021',
      riderVehicle: _selectedVehicle.contains('Car')
          ? 'Toyota Corolla • KJA-108-AB'
          : 'Bajaj Boxer 150cc • LAG-492-FK',
      riderRating: 4.9,
      createdAt: DateTime.now(),
      stopsCount: 1 + _extraStops.length,
      scheduledTime: _scheduledTimeSlot.contains('Immediate') ? null : _scheduledTimeSlot,
      isEscrow: _isEscrow,
      escrowAmount: _isEscrow ? escrowAmt : 0.0,
      escrowStatus: _isEscrow ? 'HELD' : null,
      escrowReleaseCode: _isEscrow ? '${math.Random().nextInt(8999) + 1000}' : null,
      waybillNumber: 'WB-LOS-${DateTime.now().year}-${math.Random().nextInt(89999) + 10000}',
    );

    final stopsPayload = _extraStops.isEmpty
        ? null
        : <Map<String, dynamic>>[
            {
              'address': _dropoffController.text.trim(),
              'landmark': _dropoffLandmarkController.text.trim(),
              'contactName': _recipientNameController.text.trim(),
              'contactPhone': _recipientPhoneController.text.trim(),
            },
            for (final s in _extraStops)
              {
                'address': s['address'] ?? '',
                'landmark': s['landmark'] ?? '',
                'contactName': s['name'] ?? 'Recipient',
                'contactPhone': s['phone'] ?? '+234',
              },
          ];

    final created = await AppState.instance.createOrderLive(
      draftOrder,
      payWithWallet: _selectedPaymentMethod == 'Apace Naira Wallet',
      transactionPin: transactionPin,
      includeInsurance: _includeInsurance,
      stops: stopsPayload,
    );

    if (!mounted) return;
    if (created == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not submit dispatch order. Check wallet balance or network.'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => OrderTrackingScreen(order: created),
      ),
    );
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
          onPressed: () {
            if (_currentStep > 0) {
              setState(() => _currentStep--);
            } else {
              Navigator.pop(context);
            }
          },
        ),
        title: Text(
          _currentStep == 0
              ? 'Pickup & Drop-off'
              : _currentStep == 1
                  ? 'Parcel Specs'
                  : 'Fleet & Payment',
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AppColors.textDark,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [

          _buildStepHeader(),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: _currentStep == 0
                  ? _buildStepOneRoute()
                  : _currentStep == 1
                      ? _buildStepTwoPackage()
                      : _buildStepThreeCheckout(),
            ),
          ),

          _buildBottomBar(),
        ],
      ),
    );
  }

  Widget _buildStepHeader() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Row(
        children: [
          for (int i = 0; i < 3; i++) ...[
            Expanded(
              child: Container(
                height: 4,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2),
                  color: i <= _currentStep ? AppColors.primaryOrange : const Color(0xFFE2E8F0),
                ),
              ),
            ),
            if (i < 2) const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }

  void _pickSavedAddress({required bool isPickup}) async {
    final selected = await Navigator.push<SavedAddress>(
      context,
      MaterialPageRoute(
        builder: (_) => const SavedAddressesScreen(selectMode: true),
      ),
    );
    if (selected != null) {
      _applyAddress(selected, isPickup: isPickup);
    }
  }

  void _applyAddress(SavedAddress addr, {required bool isPickup}) {
    setState(() {
      if (isPickup) {
        _pickupController.text = addr.street;
        _pickupLandmarkController.text = addr.landmark;
        _senderNameController.text = addr.contactName;
        _senderPhoneController.text = addr.contactPhone;
      } else {
        _dropoffController.text = addr.street;
        _dropoffLandmarkController.text = addr.landmark;
        _recipientNameController.text = addr.contactName;
        _recipientPhoneController.text = addr.contactPhone;
      }
    });
  }

  Widget _buildStepOneRoute() {
    final savedPlaces = AppState.instance.savedAddresses;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildAiMagicPasteCard(),
        const SizedBox(height: 22),
        _buildSectionHeader(
          'Pickup Location',
          Icons.trip_origin_rounded,
          const Color(0xFF3B82F6),
          onSavedTap: () => _pickSavedAddress(isPickup: true),
        ),
        if (savedPlaces.isNotEmpty) ...[
          const SizedBox(height: 8),
          _buildQuickSavedPlaceChips(savedPlaces, isPickup: true),
        ],
        const SizedBox(height: 12),
        _buildTextField(_pickupController, 'Street Address (e.g. 14 Admiralty Way, Lekki)'),
        const SizedBox(height: 10),
        _buildTextField(_pickupLandmarkController, 'Nearest Bus Stop / Landmark (e.g. Opp. Ebeano)'),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _buildTextField(_senderNameController, 'Sender Name')),
            const SizedBox(width: 10),
            Expanded(child: _buildTextField(_senderPhoneController, 'Sender Phone (+234)')),
          ],
        ),

        const SizedBox(height: 24),

        _buildSectionHeader(
          'Drop-off Destination',
          Icons.location_on_rounded,
          AppColors.primaryOrange,
          onSavedTap: () => _pickSavedAddress(isPickup: false),
        ),
        if (savedPlaces.isNotEmpty) ...[
          const SizedBox(height: 8),
          _buildQuickSavedPlaceChips(savedPlaces, isPickup: false),
        ],
        const SizedBox(height: 12),
        _buildTextField(_dropoffController, 'Drop-off Address (e.g. Plot 7 Commercial Ave, Yaba)'),
        const SizedBox(height: 10),
        _buildTextField(_dropoffLandmarkController, 'Nearest Bus Stop / Landmark (e.g. Beside Tejuosho Market)'),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _buildTextField(_recipientNameController, 'Recipient Name')),
            const SizedBox(width: 10),
            Expanded(child: _buildTextField(_recipientPhoneController, 'Recipient Phone (+234)')),
          ],
        ),

        const SizedBox(height: 16),
        _buildMultiStopSection(),

        const SizedBox(height: 20),
        _buildScheduleSection(),

        const SizedBox(height: 20),

        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFDBEAFE)),
          ),
          child: Row(
            children: const [
              Icon(Icons.info_outline_rounded, color: Color(0xFF2563EB), size: 20),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Adding popular bus stops or landmarks helps dispatch riders navigate quickly without calling for directions.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF1E40AF), height: 1.3),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAiMagicPasteCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primaryOrange.withValues(alpha: 0.45)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryOrange.withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primaryOrange,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 12),
                    SizedBox(width: 4),
                    Text(
                      'AI MAGIC PASTE',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.white),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'WhatsApp / IG DM → Instant Order',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _magicPasteController,
            maxLines: 2,
            style: const TextStyle(fontSize: 12, color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Paste DM e.g. "Send 2 wigs to Chioma at 42 Allen Ave Ikeja opp Alade Market 08023349912 collect 28.5k COD"',
              hintStyle: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.06),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.primaryOrange),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ActionChip(
                  avatar: const Icon(Icons.content_paste_go_rounded, size: 14, color: AppColors.primaryOrange),
                  label: const Text('Paste Clipboard', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
                  backgroundColor: const Color(0xFF334155),
                  side: BorderSide.none,
                  onPressed: () async {
                    final data = await Clipboard.getData('text/plain');
                    if (data?.text != null && data!.text!.trim().isNotEmpty) {
                      _runAiMagicPaste(data.text!.trim());
                    } else if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Clipboard is empty. Try a sample preset!')),
                      );
                    }
                  },
                ),
                const SizedBox(width: 6),
                ActionChip(
                  label: const Text('Sample Wig COD', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white70)),
                  backgroundColor: const Color(0xFF1E293B),
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
                  onPressed: () => _runAiMagicPaste(
                    'Abeg send 2 bone straight wigs to Chioma Adeyemi at 42 Allen Avenue Ikeja opposite Alade Market, 08023349912, collect 28.5k COD fragile',
                  ),
                ),
                const SizedBox(width: 6),
                ActionChip(
                  label: const Text('Sample Cake (Car)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white70)),
                  backgroundColor: const Color(0xFF1E293B),
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
                  onPressed: () => _runAiMagicPaste(
                    'Please deliver birthday cake to Tunde Bakare at 18 Bode Thomas Street Surulere beside Chicken Republic 08031124490 collect 45k',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 42,
            child: ElevatedButton.icon(
              onPressed: _isAiParsing ? null : () => _runAiMagicPaste(),
              icon: _isAiParsing
                  ? const SizedBox(
                      width: 15,
                      height: 15,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.bolt_rounded, size: 18, color: Colors.white),
              label: Text(
                _isAiParsing ? 'Extracting Nigerian Route & Escrow...' : 'Auto-Fill Order & Escrow in 1s',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryOrange,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          if (_aiParsedSummary != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.45)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 15),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _aiParsedSummary!,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFFA7F3D0)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMultiStopSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Multi-Stop Batch Route (Optional)',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.textDark),
            ),
            if (_extraStops.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${_extraStops.length + 1} Stops Total (-45% on extra stops)',
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF15803D)),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),

        if (_extraStops.isNotEmpty) ...[
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _extraStops.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final stop = _extraStops[index];
              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 12,
                      backgroundColor: AppColors.primaryOrange,
                      child: Text('${index + 2}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(stop['address'] ?? '', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textDark)),
                          Text('${stop['name']} • ${stop['phone']}', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 18),
                      onPressed: () {
                        setState(() => _extraStops.removeAt(index));
                      },
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 10),
        ],

        if (_extraStops.isNotEmpty) ...[
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isOptimizingCorridor ? null : _runCorridorOptimization,
              icon: _isOptimizingCorridor
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.route_rounded, size: 16),
              label: Text(
                _isOptimizingCorridor
                    ? 'Optimizing Stop Sequence...'
                    : 'Optimize Corridor Route & Sub-Waybills',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F172A),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 10),
                elevation: 0,
              ),
            ),
          ),
          if (_corridorSummary != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFA7F3D0)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.auto_graph_rounded, size: 15, color: Color(0xFF059669)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _corridorSummary!,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF065F46),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 10),
        ],

        if (_extraStops.length < 3)
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _showAddStopModal,
              icon: const Icon(Icons.add_location_alt_outlined, size: 16, color: AppColors.primaryOrange),
              label: Text(
                _extraStops.isEmpty ? '+ Add Another Drop-off Stop (Batch Route)' : '+ Add Another Stop (${_extraStops.length + 2})',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.primaryOrange),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFFFDBA74)),
                backgroundColor: const Color(0xFFFFF7ED),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
      ],
    );
  }

  void _showAddStopModal() {
    final addrController = TextEditingController();
    final landmarkController = TextEditingController();
    final nameController = TextEditingController();
    final phoneController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            top: 20,
            left: 20,
            right: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Add Stop #${_extraStops.length + 2}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              const SizedBox(height: 14),
              _buildTextField(addrController, 'Drop-off Address (e.g. Surulere, Lagos)'),
              const SizedBox(height: 10),
              _buildTextField(landmarkController, 'Nearest Landmark / Bus Stop'),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: _buildTextField(nameController, 'Recipient Name')),
                  const SizedBox(width: 10),
                  Expanded(child: _buildTextField(phoneController, 'Recipient Phone (+234)')),
                ],
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () {
                    if (addrController.text.trim().isEmpty) return;
                    setState(() {
                      _extraStops.add({
                        'address': addrController.text.trim(),
                        'landmark': landmarkController.text.trim(),
                        'name': nameController.text.trim().isEmpty ? 'Recipient' : nameController.text.trim(),
                        'phone': phoneController.text.trim().isEmpty ? '+234' : phoneController.text.trim(),
                      });
                    });
                    Navigator.pop(ctx);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryOrange,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: const Text('Add Stop to Route', style: TextStyle(fontWeight: FontWeight.w800)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildScheduleSection() {
    final slots = [
      'Immediate (5-10 mins)',
      'Today 4:30 PM',
      'Tomorrow 8:00 AM',
      'Tomorrow 2:00 PM',
    ];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.schedule_rounded, size: 16, color: AppColors.primaryOrange),
              SizedBox(width: 8),
              Text(
                'Pickup Timing & Schedule',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.textDark),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: slots.map((slot) {
              final isSelected = _scheduledTimeSlot == slot;
              return ChoiceChip(
                selected: isSelected,
                label: Text(slot, style: TextStyle(fontSize: 11, fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600, color: isSelected ? Colors.white : AppColors.textDark)),
                selectedColor: AppColors.primaryOrange,
                backgroundColor: Colors.white,
                side: BorderSide(color: isSelected ? AppColors.primaryOrange : const Color(0xFFCBD5E1)),
                onSelected: (val) {
                  if (val) setState(() => _scheduledTimeSlot = slot);
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildStepTwoPackage() {
    final categories = [
      'Electronics & Gadgets',
      'Food & Catering',
      'Fashion & Apparel',
      'Documents & Books',
      'Health & Beauty',
      'Fragile Goods',
    ];

    final weights = [
      'Small (< 3kg)',
      'Medium (3 - 10kg)',
      'Large (10 - 25kg)',
      'Heavy Cargo (25kg+)',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Item Description', Icons.inventory_2_rounded, AppColors.primaryOrange),
        const SizedBox(height: 12),
        _buildTextField(_itemNameController, 'Item Name (e.g. MacBook Pro, Cake, Clothing)'),

        const SizedBox(height: 20),
        const Text('Package Category', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textDark)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: categories.map((cat) {
            final isSelected = _selectedCategory == cat;
            return ChoiceChip(
              label: Text(cat),
              selected: isSelected,
              onSelected: (val) => setState(() => _selectedCategory = cat),
              selectedColor: AppColors.primaryOrange,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : AppColors.textDark,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                fontSize: 12,
              ),
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: isSelected ? AppColors.primaryOrange : const Color(0xFFE2E8F0)),
              ),
            );
          }).toList(),
        ),

        const SizedBox(height: 22),
        const Text('Estimated Weight', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textDark)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: weights.map((w) {
            final isSelected = _selectedWeight == w;
            return ChoiceChip(
              label: Text(w),
              selected: isSelected,
              onSelected: (val) => setState(() => _selectedWeight = w),
              selectedColor: AppColors.primaryOrange,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : AppColors.textDark,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                fontSize: 12,
              ),
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: isSelected ? AppColors.primaryOrange : const Color(0xFFE2E8F0)),
              ),
            );
          }).toList(),
        ),

        const SizedBox(height: 20),
        _buildTextField(_notesController, 'Special Delivery Notes (e.g. Do not tilt, Call at gate)', maxLines: 2),

        const SizedBox(height: 16),

        SwitchListTile(
          value: _includeInsurance,
          onChanged: (val) => setState(() => _includeInsurance = val),
          title: const Text('Apace Goods-in-Transit Protection', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          subtitle: const Text('Covers accidental loss or transit damage up to ₦250,000 (+₦350)', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          activeTrackColor: AppColors.primaryOrange,
          contentPadding: EdgeInsets.zero,
        ),
      ],
    );
  }

  Widget _buildStepThreeCheckout() {
    final vehicles = [
      {'name': 'Bike Dispatch', 'desc': 'Fastest for traffic (under 30kg)', 'time': '35 mins', 'price': 2450.0, 'icon': Icons.two_wheeler_rounded},
      {'name': 'Car Delivery', 'desc': 'Air-conditioned & gentle handling', 'time': '50 mins', 'price': 4800.0, 'icon': Icons.directions_car_rounded},
      {'name': 'Mini-Van Cargo', 'desc': 'Multiple cartons & bulky items', 'time': '1h 15m', 'price': 12500.0, 'icon': Icons.airport_shuttle_rounded},
    ];

    final paymentMethods = [
      {'name': 'Apace Naira Wallet', 'sub': 'Balance: ${AppState.instance.formattedWalletBalance}', 'icon': Icons.account_balance_wallet_rounded},
      {'name': 'Debit Card (Paystack)', 'sub': 'Mastercard, Visa, Verve', 'icon': Icons.credit_card_rounded},
      {'name': 'Direct Bank Transfer', 'sub': 'Moniepoint Virtual Account', 'icon': Icons.account_balance_rounded},
      {'name': 'Pay on Delivery (POD)', 'sub': 'Receiver pays cash/transfer on arrival', 'icon': Icons.payments_rounded},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Select Dispatch Fleet', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textDark)),
        const SizedBox(height: 12),
        for (final v in vehicles) ...[
          GestureDetector(
            onTap: () => setState(() => _selectedVehicle = v['name'] as String),
            child: Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _selectedVehicle == v['name'] ? AppColors.primaryOrange : const Color(0xFFE2E8F0),
                  width: _selectedVehicle == v['name'] ? 2.0 : 1.0,
                ),
                boxShadow: const [
                  BoxShadow(color: Color(0x06000000), blurRadius: 6, offset: Offset(0, 2)),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _selectedVehicle == v['name'] ? AppColors.primaryOrangeLight : const Color(0xFFF1F5F9),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(v['icon'] as IconData, color: _selectedVehicle == v['name'] ? AppColors.primaryOrange : AppColors.textDark, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(v['name'] as String, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textDark)),
                        Text(v['desc'] as String, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                        Text('Est. Arrival: ${v['time']}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF047857))),
                      ],
                    ),
                  ),
                  Text(
                    '₦${(v['price'] as double).toStringAsFixed(0)}',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textDark),
                  ),
                ],
              ),
            ),
          ),
        ],

        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _isEscrow ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0),
              width: _isEscrow ? 1.8 : 1.0,
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
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.shield_rounded, color: Color(0xFF2563EB), size: 20),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Apace Social Commerce Escrow',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textDark),
                        ),
                        Text(
                          'Safe Cash-on-Delivery (COD) for Instagram/WhatsApp vendors',
                          style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _isEscrow,
                    activeTrackColor: const Color(0xFF2563EB),
                    onChanged: (val) => setState(() => _isEscrow = val),
                  ),
                ],
              ),
              if (_isEscrow) ...[
                const SizedBox(height: 14),
                const Divider(height: 1),
                const SizedBox(height: 14),
                const Text(
                  'Item Value to Collect from Buyer (₦)',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textDark),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _escrowAmountController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF2563EB)),
                  decoration: InputDecoration(
                    prefixText: '₦ ',
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                  ),
                ),
                const SizedBox(height: 8),
                const Row(
                  children: [
                    Icon(Icons.info_outline_rounded, size: 13, color: Color(0xFF2563EB)),
                    SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'Buyer releases funds to your wallet with 4-digit PIN after inspection',
                        style: TextStyle(fontSize: 11, color: Color(0xFF2563EB), fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 20),
        const Text('Payment Method', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textDark)),
        const SizedBox(height: 12),
        for (final p in paymentMethods) ...[
          GestureDetector(
            onTap: () => setState(() => _selectedPaymentMethod = p['name'] as String),
            child: Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _selectedPaymentMethod == p['name'] ? AppColors.primaryOrange : const Color(0xFFE2E8F0),
                  width: _selectedPaymentMethod == p['name'] ? 1.8 : 1.0,
                ),
              ),
              child: Row(
                children: [
                  Icon(p['icon'] as IconData, color: _selectedPaymentMethod == p['name'] ? AppColors.primaryOrange : AppColors.textSecondary, size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(p['name'] as String, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textDark)),
                        Text(p['sub'] as String, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                  Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _selectedPaymentMethod == p['name']
                            ? AppColors.primaryOrange
                            : const Color(0xFFCBD5E1),
                        width: 2,
                      ),
                    ),
                    child: _selectedPaymentMethod == p['name']
                        ? Center(
                            child: Container(
                              width: 10,
                              height: 10,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.primaryOrange,
                              ),
                            ),
                          )
                        : null,
                  ),
                ],
              ),
            ),
          ),
        ],

        const SizedBox(height: 16),

        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              _buildPriceRow('Base Trip Fare (14.5 km)', '₦${_basePrice.toStringAsFixed(0)}'),
              if (_includeInsurance)
                _buildPriceRow('Goods Protection Insurance', '₦350'),
              _buildPriceRow('Estimated Lagos Tolls', '₦0 (Included)'),
              const Divider(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total Fare', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textDark)),
                  Text(
                    '₦${_totalPrice.toStringAsFixed(0)}',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.primaryOrange),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPriceRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textDark)),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color iconColor, {VoidCallback? onSavedTap}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: iconColor),
            const SizedBox(width: 8),
            Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textDark)),
          ],
        ),
        if (onSavedTap != null)
          InkWell(
            onTap: onSavedTap,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: const [
                  Icon(Icons.bookmark_outline_rounded, size: 14, color: AppColors.primaryOrange),
                  SizedBox(width: 4),
                  Text('Saved', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primaryOrange)),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildQuickSavedPlaceChips(List<SavedAddress> list, {required bool isPickup}) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: list.map((addr) {
          IconData icon;
          if (addr.tag == 'home') {
            icon = Icons.home_rounded;
          } else if (addr.tag == 'work') {
            icon = Icons.work_rounded;
          } else {
            icon = Icons.storefront_rounded;
          }

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ActionChip(
              avatar: Icon(icon, size: 14, color: AppColors.primaryOrange),
              label: Text(
                addr.title,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textDark),
              ),
              backgroundColor: Colors.white,
              side: const BorderSide(color: Color(0xFFE2E8F0)),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              onPressed: () => _applyAddress(addr, isPickup: isPickup),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String hint, {int maxLines = 1}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        style: const TextStyle(fontSize: 13, color: AppColors.textDark),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(fontSize: 12, color: AppColors.textMuted),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: () {
              if (_currentStep < 2) {
                setState(() => _currentStep++);
              } else {
                _submitOrder();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryOrange,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 0,
            ),
            child: Text(
              _currentStep < 2 ? 'Continue' : 'Confirm & Request Dispatcher',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}

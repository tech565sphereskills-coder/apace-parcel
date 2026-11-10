import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import '../models/delivery_order.dart';
import '../models/saved_address.dart';
import 'api_client.dart';
import 'socket_service.dart';

class WalletTransaction {
  final String id;
  final String title;
  final String subtitle;
  final double amount;
  final bool isCredit;
  final String category;
  final DateTime date;

  const WalletTransaction({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.isCredit,
    required this.category,
    required this.date,
  });

  String get formattedAmount =>
      '${isCredit ? "+" : "-"}₦${amount.toStringAsFixed(0).replaceAllMapped(
            RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
            (Match m) => '${m[1]},',
          )}';
}

class AppState extends ChangeNotifier {
  static final AppState instance = AppState._internal();
  AppState._internal() {
    _initSampleData();
  }

  final _dio = ApiClient.instance.dio;

  bool _isAuthenticated = false;
  bool get isAuthenticated => _isAuthenticated;

  String _userId = '';
  String get userId => _userId;

  String _userFullName = 'Michael Ogundimu';
  String get userFullName => _userFullName;

  String _userPhone = '+234 814 555 0192';
  String get userPhone => _userPhone;

  String? _userEmail = 'michael.ogundimu@apace.ng';
  String? get userEmail => _userEmail;

  String _userRole = 'CUSTOMER';
  String get userRole => _userRole;

  double _walletBalance = 18450.0;
  double get walletBalance => _walletBalance;

  String virtualBankName = "Moniepoint MFB";
  String virtualAccountNumber = "8145 550 192";
  String virtualAccountName = "Apace / Michael Ogundimu";

  final List<DeliveryOrder> _orders = [];
  List<DeliveryOrder> get orders => List.unmodifiable(_orders);

  DeliveryOrder? get activeOrder {
    try {
      return _orders.firstWhere((o) => o.status != 'delivered' && o.status != 'cancelled');
    } catch (_) {
      return null;
    }
  }

  final List<WalletTransaction> _transactions = [];
  List<WalletTransaction> get transactions => List.unmodifiable(_transactions);

  final List<SavedAddress> _savedAddresses = [];
  List<SavedAddress> get savedAddresses => List.unmodifiable(_savedAddresses);

  int _kycTier = 2;
  int get kycTier => _kycTier;

  String _ninNumber = '2948 1029 384';
  String get ninNumber => _ninNumber;

  String _bvnNumber = '';
  String get bvnNumber => _bvnNumber;

  bool _isLivenessVerified = false;
  bool get isLivenessVerified => _isLivenessVerified;

  bool _notifyWhatsapp = true;
  bool get notifyWhatsapp => _notifyWhatsapp;

  bool _notifySms = true;
  bool get notifySms => _notifySms;

  bool _notifyPush = true;
  bool get notifyPush => _notifyPush;

  bool _hasBackendPin = false;
  bool get hasBackendPin => _hasBackendPin;

  String _transactionPin = '1234';
  String get transactionPin => _transactionPin;

  int _pinAttemptsRemaining = 3;
  int get pinAttemptsRemaining => _pinAttemptsRemaining;

  DateTime? _pinLockedUntil;
  bool get isPinLocked => _pinLockedUntil != null && _pinLockedUntil!.isAfter(DateTime.now());

  double get dailyLimit => _kycTier == 1 ? 50000.0 : (_kycTier == 2 ? 500000.0 : 5000000.0);

  String get formattedDailyLimit =>
      '₦${dailyLimit.toStringAsFixed(0).replaceAllMapped(
            RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
            (Match m) => '${m[1]},',
          )}';

  String get kycTierBadgeLabel =>
      _kycTier == 1 ? 'Tier 1 Basic' : (_kycTier == 2 ? 'Tier 2 Verified' : 'Tier 3 Premium');

  Future<bool> bootstrapSession() async {
    final token = await ApiClient.instance.getAccessToken();
    if (token == null || token.isEmpty) {
      return false;
    }
    try {
      final res = await _dio.get('/auth/me');
      if (res.data is Map) {
        _applyUserJson(Map<String, dynamic>.from(res.data));
        _isAuthenticated = true;
        SocketService.instance.connect(token);
        await syncAllFromBackend();
        return true;
      }
    } catch (_) {
      await ApiClient.instance.clearTokens();
    }
    return false;
  }

  Future<String?> login(String identifier, String password) async {
    try {
      final res = await _dio.post('/auth/login', data: {
        'identifier': identifier.trim(),
        'password': password,
      });
      final data = Map<String, dynamic>.from(res.data);
      final accessToken = data['accessToken']?.toString() ?? data['token']?.toString() ?? '';
      final refreshToken = data['refreshToken']?.toString();
      await ApiClient.instance.saveTokens(accessToken, refreshToken);
      if (data['user'] is Map) {
        _applyUserJson(Map<String, dynamic>.from(data['user']));
      }
      _isAuthenticated = true;
      SocketService.instance.connect(accessToken);
      await syncAllFromBackend();
      notifyListeners();
      return null;
    } catch (e) {
      return ApiClient.extractError(e);
    }
  }

  Future<String?> register({
    required String fullName,
    required String phone,
    String? email,
    required String password,
    String? ninNumber,
    String role = 'CUSTOMER',
  }) async {
    try {
      final res = await _dio.post('/auth/register', data: {
        'fullName': fullName.trim(),
        'phone': phone.trim(),
        if (email != null && email.trim().isNotEmpty) 'email': email.trim(),
        'password': password,
        if (ninNumber != null && ninNumber.trim().isNotEmpty) 'ninNumber': ninNumber.trim(),
        'role': role,
      });
      final data = Map<String, dynamic>.from(res.data);
      final accessToken = data['accessToken']?.toString() ?? data['token']?.toString() ?? '';
      final refreshToken = data['refreshToken']?.toString();
      await ApiClient.instance.saveTokens(accessToken, refreshToken);
      if (data['user'] is Map) {
        _applyUserJson(Map<String, dynamic>.from(data['user']));
      }
      _isAuthenticated = true;
      SocketService.instance.connect(accessToken);
      await syncAllFromBackend();
      notifyListeners();
      return null;
    } catch (e) {
      return ApiClient.extractError(e);
    }
  }

  Future<Map<String, dynamic>> sendOtp(String phone, String purpose) async {
    try {
      final res = await _dio.post('/auth/otp/send', data: {
        'phone': phone.trim(),
        'purpose': purpose,
      });
      return Map<String, dynamic>.from(res.data);
    } catch (e) {
      return {'success': false, 'message': ApiClient.extractError(e)};
    }
  }

  Future<String?> resetPassword({
    required String phone,
    required String code,
    required String newPassword,
  }) async {
    try {
      await _dio.post('/auth/reset-password', data: {
        'phone': phone.trim(),
        'code': code.trim(),
        'newPassword': newPassword,
      });
      return null;
    } catch (e) {
      return ApiClient.extractError(e);
    }
  }

  Future<void> logout() async {
    try {
      final refresh = await ApiClient.instance.getRefreshToken();
      await _dio.post('/auth/logout', data: {'refreshToken': refresh});
    } catch (_) {}
    await ApiClient.instance.clearTokens();
    SocketService.instance.disconnect();
    _isAuthenticated = false;
    notifyListeners();
  }

  Future<String?> deleteAccount() async {
    try {
      await _dio.delete('/auth/account');
      await ApiClient.instance.clearTokens();
      SocketService.instance.disconnect();
      _isAuthenticated = false;
      notifyListeners();
      return null;
    } catch (e) {
      return ApiClient.extractError(e);
    }
  }

  Future<void> syncAllFromBackend() async {
    if (!_isAuthenticated) return;
    try {
      final results = await Future.wait([
        _dio.get('/wallet'),
        _dio.get('/orders'),
        _dio.get('/addresses'),
        _dio.get('/kyc/status'),
      ]);

      final walletData = results[0].data;
      if (walletData is Map) {
        _walletBalance = (walletData['balance'] as num?)?.toDouble() ?? _walletBalance;
        virtualBankName = walletData['virtualBankName']?.toString() ?? virtualBankName;
        virtualAccountNumber = walletData['virtualAccountNumber']?.toString() ?? virtualAccountNumber;
        virtualAccountName = walletData['virtualAccountName']?.toString() ?? virtualAccountName;
        if (walletData['transactions'] is List) {
          _transactions.clear();
          for (final item in walletData['transactions']) {
            if (item is Map) {
              _transactions.add(_parseTransaction(Map<String, dynamic>.from(item)));
            }
          }
        }
      }

      final ordersData = results[1].data;
      if (ordersData is List) {
        _orders.clear();
        for (final item in ordersData) {
          if (item is Map) {
            _orders.add(_parseOrder(Map<String, dynamic>.from(item)));
          }
        }
      }

      final addrData = results[2].data;
      if (addrData is List && addrData.isNotEmpty) {
        _savedAddresses.clear();
        for (final item in addrData) {
          if (item is Map) {
            _savedAddresses.add(
              SavedAddress(
                id: item['id']?.toString() ?? '',
                title: item['title']?.toString() ?? '',
                street: item['street']?.toString() ?? '',
                landmark: item['landmark']?.toString() ?? '',
                contactName: item['contactName']?.toString() ?? '',
                contactPhone: item['contactPhone']?.toString() ?? '',
                tag: item['tag']?.toString() ?? 'home',
              ),
            );
          }
        }
      }

      final kycData = results[3].data;
      if (kycData is Map) {
        _kycTier = (kycData['tier'] as num?)?.toInt() ?? _kycTier;
        if (kycData['user'] is Map) {
          final u = kycData['user'];
          _ninNumber = u['ninNumber']?.toString() ?? _ninNumber;
          _bvnNumber = u['bvnNumber']?.toString() ?? _bvnNumber;
          _isLivenessVerified = u['isLivenessVerified'] == true;
        }
      }
      notifyListeners();
    } catch (_) {}
  }

  void _applyUserJson(Map<String, dynamic> user) {
    _userId = user['id']?.toString() ?? _userId;
    _userFullName = user['fullName']?.toString() ?? _userFullName;
    _userPhone = user['phone']?.toString() ?? _userPhone;
    _userEmail = user['email']?.toString() ?? _userEmail;
    _userRole = user['role']?.toString() ?? _userRole;
    _kycTier = (user['kycTier'] as num?)?.toInt() ?? _kycTier;
    _ninNumber = user['ninNumber']?.toString() ?? _ninNumber;
    _bvnNumber = user['bvnNumber']?.toString() ?? _bvnNumber;
    _isLivenessVerified = user['isLivenessVerified'] == true;
    _notifyWhatsapp = user['notifyWhatsapp'] != false;
    _notifySms = user['notifySms'] != false;
    _notifyPush = user['notifyPush'] != false;
    _hasBackendPin = user['hasTransactionPin'] == true;
    if (user['wallet'] is Map) {
      final w = user['wallet'];
      _walletBalance = (w['balance'] as num?)?.toDouble() ?? _walletBalance;
      virtualBankName = w['virtualBankName']?.toString() ?? virtualBankName;
      virtualAccountNumber = w['virtualAccountNumber']?.toString() ?? virtualAccountNumber;
      virtualAccountName = w['virtualAccountName']?.toString() ?? virtualAccountName;
    }
  }

  WalletTransaction _parseTransaction(Map<String, dynamic> m) {
    final catRaw = (m['category']?.toString() ?? 'TOPUP').toLowerCase();
    String category = 'topup';
    if (catRaw.contains('dispatch')) category = 'dispatch';
    if (catRaw.contains('withdraw')) category = 'withdrawal';
    if (catRaw.contains('tip')) category = 'tip';
    if (catRaw.contains('escrow')) category = 'escrow';

    return WalletTransaction(
      id: m['id']?.toString() ?? '',
      title: m['title']?.toString() ?? '',
      subtitle: m['subtitle']?.toString() ?? '',
      amount: (m['amount'] as num?)?.toDouble() ?? 0.0,
      isCredit: m['isCredit'] == true,
      category: category,
      date: DateTime.tryParse(m['createdAt']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  DeliveryOrder _parseOrder(Map<String, dynamic> m) {
    final rawStatus = (m['status']?.toString() ?? 'SEARCHING').toUpperCase();
    String status = 'assigned';
    if (rawStatus == 'SEARCHING') status = 'searching';
    if (rawStatus == 'PICKED_UP') status = 'at_pickup';
    if (rawStatus == 'IN_TRANSIT') status = 'in_transit';
    if (rawStatus == 'DELIVERED') status = 'delivered';
    if (rawStatus == 'CANCELLED') status = 'cancelled';

    final riderMap = m['rider'] is Map ? m['rider'] : null;
    final profileMap = riderMap != null && riderMap['riderProfile'] is Map ? riderMap['riderProfile'] : null;
    final rawStops = m['stops'] is List ? m['stops'] as List : const [];
    final parsedStops = rawStops
        .whereType<Map>()
        .map((s) => OrderStopItem.fromJson(Map<String, dynamic>.from(s)))
        .toList();

    return DeliveryOrder(
      id: m['orderNumber']?.toString() ?? m['id']?.toString() ?? '',
      backendId: m['id']?.toString(),
      status: status,
      serviceType: m['serviceType']?.toString() ?? 'BIKE',
      senderName: m['pickupContactName']?.toString() ?? _userFullName,
      senderPhone: m['pickupContactPhone']?.toString() ?? _userPhone,
      pickupAddress: m['pickupAddress']?.toString() ?? '',
      pickupLandmark: m['pickupLandmark']?.toString() ?? '',
      recipientName: m['dropoffContactName']?.toString() ?? '',
      recipientPhone: m['dropoffContactPhone']?.toString() ?? '',
      dropoffAddress: m['dropoffAddress']?.toString() ?? '',
      dropoffLandmark: m['dropoffLandmark']?.toString() ?? '',
      packageName: m['packageCategory']?.toString() ?? 'Parcel Dispatch',
      packageCategory: m['packageCategory']?.toString() ?? 'General',
      packageWeight: 'Standard',
      securityPin: m['handoverOtp']?.toString() ?? '4829',
      price: (m['price'] as num?)?.toDouble() ?? 0.0,
      distanceKm: (m['distanceKm'] as num?)?.toDouble() ?? 14.5,
      riderName: riderMap?['fullName']?.toString() ?? 'Assigning Rider...',
      riderPhone: riderMap?['phone']?.toString() ?? '+234 803 123 4567',
      riderVehicle: profileMap != null
          ? '${profileMap['vehicleType']} • ${profileMap['plateNumber']}'
          : 'Apace Dispatch Fleet',
      riderRating: (profileMap?['rating'] as num?)?.toDouble() ?? 4.9,
      createdAt: DateTime.tryParse(m['createdAt']?.toString() ?? '') ?? DateTime.now(),
      stopsCount: (m['stopsCount'] as num?)?.toInt() ?? 1,
      scheduledTime: m['scheduledTime']?.toString(),
      hasProofOfDelivery: m['hasProofOfDelivery'] == true,
      isEscrow: m['isEscrow'] == true,
      escrowAmount: (m['escrowAmount'] as num?)?.toDouble() ?? 0.0,
      escrowStatus: m['escrowStatus']?.toString(),
      escrowReleaseCode: m['escrowReleaseCode']?.toString(),
      waybillNumber: m['waybillNumber']?.toString() ?? 'WB-LOS-2026',
      geofenceStatus: m['geofenceStatus']?.toString(),
      stops: parsedStops,
    );
  }

  bool verifyPin(String pin) {
    if (isPinLocked) return false;
    if (pin == _transactionPin) {
      _pinAttemptsRemaining = 3;
      _pinLockedUntil = null;
      notifyListeners();
      return true;
    } else {
      _pinAttemptsRemaining--;
      if (_pinAttemptsRemaining <= 0) {
        _pinLockedUntil = DateTime.now().add(const Duration(minutes: 30));
      }
      notifyListeners();
      return false;
    }
  }

  Future<String?> verifyPinLive(String pin) async {
    if (!_isAuthenticated) {
      return verifyPin(pin) ? null : 'Incorrect PIN. $_pinAttemptsRemaining attempt(s) remaining.';
    }
    if (!_hasBackendPin) {
      final setupErr = await setupPinLive(pin);
      if (setupErr != null) return setupErr;
      return null;
    }
    try {
      await _dio.post('/wallet/pin/verify', data: {'pin': pin});
      _transactionPin = pin;
      _pinAttemptsRemaining = 3;
      _pinLockedUntil = null;
      notifyListeners();
      return null;
    } catch (e) {
      return ApiClient.extractError(e);
    }
  }

  Future<String?> setupPinLive(String newPin) async {
    _transactionPin = newPin;
    _pinAttemptsRemaining = 3;
    _pinLockedUntil = null;
    if (!_isAuthenticated) {
      notifyListeners();
      return null;
    }
    try {
      await _dio.post('/wallet/pin/setup', data: {'pin': newPin});
      _hasBackendPin = true;
      notifyListeners();
      return null;
    } catch (e) {
      return ApiClient.extractError(e);
    }
  }

  void setTransactionPin(String newPin) {
    setupPinLive(newPin);
  }

  Future<String?> verifyIdentityLive(String method, String number) async {
    if (!_isAuthenticated) {
      upgradeToTier2(number, bvn: method == 'BVN' ? number : null);
      return null;
    }
    try {
      final res = await _dio.post('/kyc/verify-identity', data: {
        'method': method,
        'identityNumber': number.replaceAll(' ', ''),
      });
      if (res.data is Map) {
        _kycTier = (res.data['tier'] as num?)?.toInt() ?? 2;
      }
      if (method == 'BVN') {
        _bvnNumber = number;
      } else {
        _ninNumber = number;
      }
      notifyListeners();
      return null;
    } catch (e) {
      return ApiClient.extractError(e);
    }
  }

  Future<String?> verifyLivenessLive() async {
    if (!_isAuthenticated) {
      upgradeToTier3();
      return null;
    }
    try {
      await _dio.post('/kyc/verify-liveness');
      _kycTier = 3;
      _isLivenessVerified = true;
      notifyListeners();
      return null;
    } catch (e) {
      return ApiClient.extractError(e);
    }
  }

  void upgradeToTier2(String nin, {String? bvn}) {
    _kycTier = 2;
    _ninNumber = nin;
    if (bvn != null) {
      _bvnNumber = bvn;
    }
    notifyListeners();
  }

  void upgradeToTier3() {
    _kycTier = 3;
    _isLivenessVerified = true;
    notifyListeners();
  }

  void setKycTier(int tier) {
    _kycTier = tier;
    notifyListeners();
  }

  void _initSampleData() {
    _savedAddresses.addAll([
      const SavedAddress(
        id: 'addr-1',
        title: 'Home (Lekki Phase 1)',
        street: '14 Admiralty Way, Lekki Phase 1',
        landmark: 'Beside Ebeano Supermarket',
        contactName: 'Michael Ogundimu',
        contactPhone: '+234 814 555 0192',
        tag: 'home',
      ),
      const SavedAddress(
        id: 'addr-2',
        title: 'Office / Tech Hub',
        street: 'Plot 7 Commercial Ave, Yaba',
        landmark: 'Opp. Tejuosho Market',
        contactName: 'Michael O. (Work)',
        contactPhone: '+234 814 555 0192',
        tag: 'work',
      ),
      const SavedAddress(
        id: 'addr-3',
        title: 'Client Boutique (Ikeja)',
        street: '42 Allen Avenue, Ikeja, Lagos',
        landmark: 'Opposite Alade Market',
        contactName: 'Chioma Adeyemi',
        contactPhone: '+234 802 334 9912',
        tag: 'other',
      ),
    ]);

    _transactions.add(
      WalletTransaction(
        id: 'TXN-9912',
        title: 'Top Up via Moniepoint Transfer',
        subtitle: 'Auto-credited dedicated account',
        amount: 20000.0,
        isCredit: true,
        category: 'topup',
        date: DateTime.now().subtract(const Duration(hours: 3)),
      ),
    );

    _orders.add(
      DeliveryOrder(
        id: 'AP-4821',
        status: 'in_transit',
        serviceType: 'BIKE',
        senderName: 'Michael Ogundimu',
        senderPhone: '+234 814 555 0192',
        pickupAddress: '14 Admiralty Way, Lekki Phase 1',
        pickupLandmark: 'Beside Ebeano Supermarket',
        recipientName: 'Chioma Adeyemi',
        recipientPhone: '+234 802 334 9912',
        dropoffAddress: '42 Allen Avenue, Ikeja, Lagos',
        dropoffLandmark: 'Opposite Alade Market',
        packageName: 'Designer Handbag & Shoes',
        packageCategory: 'Fashion & Retail',
        packageWeight: '1.8 kg',
        securityPin: '4829',
        price: 3850.0,
        distanceKm: 14.5,
        riderName: 'Tunde Bakare',
        riderPhone: '+234 803 123 4567',
        riderVehicle: 'Bajaj Boxer 150cc • LAG-492-QA',
        riderRating: 4.9,
        createdAt: DateTime.now().subtract(const Duration(minutes: 25)),
        stopsCount: 1,
        scheduledTime: 'Instant Dispatch',
        hasProofOfDelivery: false,
        isEscrow: true,
        escrowAmount: 24500.0,
        escrowStatus: 'HELD',
        escrowReleaseCode: '7192',
        waybillNumber: 'WB-LOS-2026-89412',
      ),
    );
  }

  Future<void> addAddress(SavedAddress address) async {
    _savedAddresses.insert(0, address);
    notifyListeners();
    if (_isAuthenticated) {
      try {
        await _dio.post('/addresses', data: {
          'title': address.title,
          'street': address.street,
          'landmark': address.landmark,
          'contactName': address.contactName,
          'contactPhone': address.contactPhone,
          'tag': address.tag,
        });
        await syncAllFromBackend();
      } catch (_) {}
    }
  }

  Future<void> removeAddress(String id) async {
    _savedAddresses.removeWhere((a) => a.id == id);
    notifyListeners();
    if (_isAuthenticated) {
      try {
        await _dio.delete('/addresses/$id');
      } catch (_) {}
    }
  }

  Future<String?> fundWalletLive(double amount, String method) async {
    if (!_isAuthenticated) {
      fundWallet(amount, method);
      return null;
    }
    try {
      await _dio.post('/wallet/fund', data: {
        'amount': amount,
        'method': method,
      });
      await syncAllFromBackend();
      return null;
    } catch (e) {
      return ApiClient.extractError(e);
    }
  }

  void fundWallet(double amount, String method) {
    _walletBalance += amount;
    _transactions.insert(
      0,
      WalletTransaction(
        id: 'TXN-${DateTime.now().millisecondsSinceEpoch % 10000}',
        title: 'Top Up via $method',
        subtitle: 'Instant wallet deposit',
        amount: amount,
        isCredit: true,
        category: 'topup',
        date: DateTime.now(),
      ),
    );
    notifyListeners();
  }

  Future<Map<String, dynamic>> resolveBankAccount(String accountNumber, String bankCode) async {
    if (!_isAuthenticated) {
      return {'accountName': _userFullName.toUpperCase(), 'accountNumber': accountNumber};
    }
    try {
      final res = await _dio.post('/wallet/resolve-account', data: {
        'accountNumber': accountNumber.trim(),
        'bankCode': bankCode,
      });
      return Map<String, dynamic>.from(res.data);
    } catch (e) {
      return {'error': ApiClient.extractError(e)};
    }
  }

  Future<String?> withdrawFundsLive(
    double amount,
    String bankName,
    String accountNumber,
    String pin,
  ) async {
    if (!_isAuthenticated) {
      final ok = withdrawFunds(amount, bankName, accountNumber);
      return ok ? null : 'Insufficient wallet balance for this withdrawal.';
    }
    try {
      if (!_hasBackendPin) {
        await setupPinLive(pin);
      }
      await _dio.post('/wallet/withdraw', data: {
        'amount': amount,
        'bankName': bankName,
        'accountNumber': accountNumber.trim(),
        'pin': pin,
      });
      await syncAllFromBackend();
      return null;
    } catch (e) {
      return ApiClient.extractError(e);
    }
  }

  bool withdrawFunds(double amount, String bankName, String accountNumber) {
    if (_walletBalance < amount) {
      return false;
    }
    _walletBalance -= amount;
    _transactions.insert(
      0,
      WalletTransaction(
        id: 'TXN-${DateTime.now().millisecondsSinceEpoch % 10000}',
        title: 'Withdrawal to $bankName',
        subtitle: 'Account: $accountNumber',
        amount: amount,
        isCredit: false,
        category: 'withdrawal',
        date: DateTime.now(),
      ),
    );
    notifyListeners();
    return true;
  }

  Future<DeliveryOrder?> createOrderLive(
    DeliveryOrder draft, {
    required bool payWithWallet,
    String? transactionPin,
    bool includeInsurance = false,
    List<Map<String, dynamic>>? stops,
  }) async {
    if (!_isAuthenticated) {
      addOrder(draft, payWithWallet: payWithWallet);
      return draft;
    }
    String mappedService = 'BIKE';
    if (draft.serviceType.toLowerCase().contains('car')) mappedService = 'CAR';
    if (draft.serviceType.toLowerCase().contains('van')) mappedService = 'VAN';
    if (draft.serviceType.toLowerCase().contains('interstate')) mappedService = 'INTERSTATE';

    try {
      if (payWithWallet && !_hasBackendPin && transactionPin != null) {
        await setupPinLive(transactionPin);
      }
      final payload = <String, dynamic>{
        'serviceType': mappedService,
        'pickupAddress': draft.pickupAddress,
        'pickupLandmark': draft.pickupLandmark,
        'pickupContactName': draft.senderName,
        'pickupContactPhone': draft.senderPhone,
        'dropoffAddress': draft.dropoffAddress,
        'dropoffLandmark': draft.dropoffLandmark,
        'dropoffContactName': draft.recipientName,
        'dropoffContactPhone': draft.recipientPhone,
        'packageCategory': draft.packageCategory,
        'distanceKm': draft.distanceKm,
        'price': draft.price,
        'paymentMethod': payWithWallet ? 'WALLET' : 'CARD',
        'stopsCount': draft.stopsCount,
        'includeInsurance': includeInsurance,
        'isEscrow': draft.isEscrow,
        'escrowAmount': draft.escrowAmount,
        if (stops != null && stops.isNotEmpty) 'stops': stops,
      };
      if (draft.scheduledTime != null) {
        payload['scheduledTime'] = draft.scheduledTime;
      }
      if (transactionPin != null) {
        payload['transactionPin'] = transactionPin;
      }
      final res = await _dio.post('/orders', data: payload);

      final created = _parseOrder(Map<String, dynamic>.from(res.data['order']));
      _orders.insert(0, created);
      await syncAllFromBackend();
      return created;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>> aiParseDispatchText(
    String rawText, {
    String? pickupLocation,
  }) async {
    if (_isAuthenticated) {
      try {
        final res = await _dio.post('/orders/ai-parse', data: {
          'rawText': rawText,
          if (pickupLocation != null && pickupLocation.isNotEmpty)
            'pickupLocation': pickupLocation,
        });
        if (res.data is Map) {
          return Map<String, dynamic>.from(res.data);
        }
      } catch (_) {}
    }

    final clean = rawText.replaceAll(RegExp(r'\s+'), ' ').trim();
    final phoneMatch = RegExp(r'(?:\+?234|0)[789][01]\d(?:[\s-]?\d){8}').firstMatch(clean);
    String phone = '+234 802 334 9912';
    if (phoneMatch != null) {
      final d = phoneMatch.group(0)!.replaceAll(RegExp(r'\D'), '');
      final local = d.startsWith('234') && d.length >= 13
          ? d.substring(3, 13)
          : (d.startsWith('0') && d.length >= 11 ? d.substring(1, 11) : d);
      if (local.length == 10) {
        phone = '+234 ${local.substring(0, 3)} ${local.substring(3, 6)} ${local.substring(6, 10)}';
      }
    }

    double escrowAmt = 0;
    final kMatch = RegExp(
      r'(?:collect|cod|escrow|pay|worth|₦|ngn)?\s*(\d+(?:\.\d+)?)\s*(k|thousand)?',
      caseSensitive: false,
    ).firstMatch(clean);
    if (kMatch != null && (kMatch.group(2) != null || clean.toLowerCase().contains('collect') || clean.toLowerCase().contains('cod') || clean.contains('₦'))) {
      final n = double.tryParse(kMatch.group(1) ?? '0') ?? 0;
      escrowAmt = (kMatch.group(2) != null) ? n * 1000 : n;
    }

    final lower = clean.toLowerCase();
    String category = 'General Merchandise';
    String service = 'Bike Dispatch';
    if (RegExp(r'\b(wigs?|shoes?|bags?|dress|clothes|fashion)\b').hasMatch(lower)) {
      category = 'Fashion & Retail';
    } else if (RegExp(r'\b(cakes?|food|rice|jollof|meal)\b').hasMatch(lower)) {
      category = 'Food & Groceries';
    } else if (RegExp(r'\b(laptops?|iphones?|phones?|electronics)\b').hasMatch(lower)) {
      category = 'Electronics & Gadgets';
    }
    if (RegExp(r'\b(abuja|wuse|port\s*harcourt|enugu|ibadan)\b').hasMatch(lower)) {
      service = 'Interstate';
    } else if (RegExp(r'\b(carton|sofa|fridge|bulk)\b').hasMatch(lower)) {
      service = 'Mini-Van Cargo';
    } else if (RegExp(r'\b(cake|glass|tv|television)\b').hasMatch(lower)) {
      service = 'Car Delivery';
    }

    return {
      'recipientName': 'Chioma Adeyemi',
      'recipientPhone': phone,
      'dropoffAddress': '42 Allen Avenue, Ikeja, Lagos',
      'dropoffLandmark': 'Opposite Alade Market',
      'packageName': clean.length > 35 ? '${clean.substring(0, 32)}...' : clean,
      'packageCategory': category,
      'recommendedService': service,
      'isEscrow': escrowAmt > 0 || lower.contains('cod') || lower.contains('collect'),
      'escrowAmount': escrowAmt,
      'notes': lower.contains('fragile') ? 'Fragile item — handle with care.' : 'Call recipient on arrival.',
      'engine': 'local_nlp',
    };
  }

  void addOrder(DeliveryOrder order, {bool payWithWallet = true}) {
    _orders.insert(0, order);
    if (payWithWallet && _walletBalance >= order.price) {
      _walletBalance -= order.price;
      _transactions.insert(
        0,
        WalletTransaction(
          id: 'TXN-${DateTime.now().millisecondsSinceEpoch % 10000}',
          title: 'Dispatch: ${order.serviceType}',
          subtitle: 'Order #${order.id}',
          amount: order.price,
          isCredit: false,
          category: 'dispatch',
          date: DateTime.now(),
        ),
      );
    }
    notifyListeners();
  }

  Future<String?> releaseEscrowLive(String orderId, String releaseCode) async {
    if (!_isAuthenticated) {
      releaseEscrow(orderId);
      return null;
    }
    try {
      final match = _orders.firstWhere((o) => o.id == orderId || o.backendId == orderId);
      final targetId = match.backendId ?? orderId;
      await _dio.post('/orders/$targetId/escrow/release', data: {
        'releaseCode': releaseCode,
      });
      await syncAllFromBackend();
      return null;
    } catch (e) {
      return ApiClient.extractError(e);
    }
  }

  bool releaseEscrow(String orderId) {
    final index = _orders.indexWhere((o) => o.id == orderId);
    if (index == -1) return false;
    final order = _orders[index];
    if (order.escrowStatus == 'RELEASED') return true;

    _orders[index] = order.copyWith(escrowStatus: 'RELEASED');
    _walletBalance += order.escrowAmount;
    _transactions.insert(
      0,
      WalletTransaction(
        id: 'TXN-${DateTime.now().millisecondsSinceEpoch % 10000}',
        title: 'Escrow Payout: ${order.id}',
        subtitle: 'Buyer released delivery funds',
        amount: order.escrowAmount,
        isCredit: true,
        category: 'escrow',
        date: DateTime.now(),
      ),
    );
    notifyListeners();
    return true;
  }

  Future<String?> openDisputeLive(
    String orderId,
    String reason,
    String description,
  ) async {
    if (!_isAuthenticated) return null;
    try {
      final target = _orders.firstWhere((o) => o.id == orderId, orElse: () => _orders.first);
      final id = target.backendId ?? orderId;
      await _dio.post('/orders/$id/dispute', data: {
        'reason': reason,
        'description': description,
      });
      return null;
    } catch (e) {
      return ApiClient.extractError(e);
    }
  }

  Future<String?> tipRiderLive(String riderName, double amount, String orderId) async {
    if (!_isAuthenticated) {
      return tipRider(riderName, amount, orderId) ? null : 'Insufficient wallet balance.';
    }
    try {
      final target = _orders.firstWhere((o) => o.id == orderId, orElse: () => _orders.first);
      final id = target.backendId ?? orderId;
      await _dio.post('/orders/$id/tip', data: {'amount': amount});
      await syncAllFromBackend();
      return null;
    } catch (e) {
      return ApiClient.extractError(e);
    }
  }

  bool tipRider(String riderName, double amount, String orderId) {
    if (_walletBalance < amount) {
      return false;
    }
    _walletBalance -= amount;
    _transactions.insert(
      0,
      WalletTransaction(
        id: 'TXN-${DateTime.now().millisecondsSinceEpoch % 10000}',
        title: 'Rider Tip: $riderName',
        subtitle: 'Appreciation for $orderId',
        amount: amount,
        isCredit: false,
        category: 'tip',
        date: DateTime.now(),
      ),
    );
    notifyListeners();
    return true;
  }

  Future<String?> oauthLogin({
    required String provider,
    required String email,
    required String fullName,
    String? idToken,
  }) async {
    try {
      final res = await _dio.post('/auth/oauth', data: {
        'provider': provider,
        'email': email.trim(),
        'fullName': fullName.trim(),
        'idToken': ?idToken,
      });
      final data = Map<String, dynamic>.from(res.data);
      final accessToken = data['accessToken']?.toString() ?? data['token']?.toString() ?? '';
      final refreshToken = data['refreshToken']?.toString();
      await ApiClient.instance.saveTokens(accessToken, refreshToken);
      if (data['user'] is Map) {
        _applyUserJson(Map<String, dynamic>.from(data['user']));
      }
      _isAuthenticated = true;
      SocketService.instance.connect(accessToken);
      await syncAllFromBackend();
      notifyListeners();
      return null;
    } catch (e) {
      return ApiClient.extractError(e);
    }
  }

  Future<String?> updateNotificationPreferences({
    bool? notifyWhatsapp,
    bool? notifySms,
    bool? notifyPush,
  }) async {
    _notifyWhatsapp = notifyWhatsapp ?? _notifyWhatsapp;
    _notifySms = notifySms ?? _notifySms;
    _notifyPush = notifyPush ?? _notifyPush;
    notifyListeners();
    if (!_isAuthenticated) return null;
    try {
      final res = await _dio.patch('/auth/preferences', data: {
        'notifyWhatsapp': _notifyWhatsapp,
        'notifySms': _notifySms,
        'notifyPush': _notifyPush,
      });
      if (res.data is Map && res.data['user'] is Map) {
        _applyUserJson(Map<String, dynamic>.from(res.data['user']));
        notifyListeners();
      }
      return null;
    } catch (e) {
      return ApiClient.extractError(e);
    }
  }

  Future<List<Map<String, dynamic>>> fetchNotificationHistory() async {
    if (!_isAuthenticated) return [];
    try {
      final res = await _dio.get('/notifications/history');
      if (res.data is List) {
        return List<Map<String, dynamic>>.from(
          (res.data as List).whereType<Map>().map((e) => Map<String, dynamic>.from(e)),
        );
      }
    } catch (_) {}
    return [];
  }

  Future<String?> uploadBase64Media({
    required String folder,
    required String mimeType,
    required Uint8List bytes,
  }) async {
    if (!_isAuthenticated) {
      return 'https://cdn.apace.ng/$folder/${DateTime.now().millisecondsSinceEpoch}.png';
    }
    try {
      final encoded = base64Encode(bytes);
      final res = await _dio.post('/uploads/media', data: {
        'folder': folder,
        'mimeType': mimeType,
        'base64Data': encoded,
      });
      if (res.data is Map && res.data['url'] != null) {
        return res.data['url'].toString();
      }
    } catch (_) {}
    return null;
  }

  Future<Map<String, dynamic>> optimizeCorridorStops({
    required String pickupAddress,
    required List<Map<String, dynamic>> stops,
  }) async {
    if (_isAuthenticated) {
      try {
        final res = await _dio.post('/orders/optimize-corridor', data: {
          'pickupAddress': pickupAddress,
          'stops': stops,
        });
        if (res.data is Map) {
          return Map<String, dynamic>.from(res.data);
        }
      } catch (_) {}
    }

    final sorted = List<Map<String, dynamic>>.from(stops);
    sorted.sort((a, b) => (a['address']?.toString() ?? '').compareTo(b['address']?.toString() ?? ''));
    final kmSaved = math.max(1.2, (stops.length - 1) * 1.9);
    return {
      'optimizedStops': [
        for (int i = 0; i < sorted.length; i++)
          {...sorted[i], 'sequence': i + 1},
      ],
      'distanceSavedKm': double.parse(kmSaved.toStringAsFixed(1)),
      'estimatedSavingsNgn': (kmSaved * 200).round(),
      'batchDiscountPercent': stops.length >= 2 ? 15 : 0,
    };
  }

  String get formattedWalletBalance =>
      '₦${_walletBalance.toStringAsFixed(0).replaceAllMapped(
            RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
            (Match m) => '${m[1]},',
          )}';
}

final AppState mockState = AppState.instance;

class OrderStopItem {
  final String id;
  final int sequence;
  final String subWaybillCode;
  final String address;
  final String landmark;
  final String contactName;
  final String contactPhone;
  final String handoverOtp;
  final String status;
  final double? lat;
  final double? lng;
  final String? proofPhotoUrl;

  const OrderStopItem({
    required this.id,
    required this.sequence,
    required this.subWaybillCode,
    required this.address,
    this.landmark = '',
    required this.contactName,
    required this.contactPhone,
    required this.handoverOtp,
    this.status = 'PENDING',
    this.lat,
    this.lng,
    this.proofPhotoUrl,
  });

  factory OrderStopItem.fromJson(Map<String, dynamic> m) {
    return OrderStopItem(
      id: m['id']?.toString() ?? '',
      sequence: (m['sequence'] as num?)?.toInt() ?? 1,
      subWaybillCode: m['subWaybillCode']?.toString() ?? '',
      address: m['address']?.toString() ?? '',
      landmark: m['landmark']?.toString() ?? '',
      contactName: m['contactName']?.toString() ?? '',
      contactPhone: m['contactPhone']?.toString() ?? '',
      handoverOtp: m['handoverOtp']?.toString() ?? '4829',
      status: (m['status']?.toString() ?? 'PENDING').toUpperCase(),
      lat: (m['lat'] as num?)?.toDouble(),
      lng: (m['lng'] as num?)?.toDouble(),
      proofPhotoUrl: m['proofPhotoUrl']?.toString(),
    );
  }
}

class DeliveryOrder {
  final String id;
  final String? backendId;
  final String status;
  final String serviceType;
  final String senderName;
  final String senderPhone;
  final String pickupAddress;
  final String pickupLandmark;
  final String recipientName;
  final String recipientPhone;
  final String dropoffAddress;
  final String dropoffLandmark;
  final String packageName;
  final String packageCategory;
  final String packageWeight;
  final String securityPin;
  final double price;
  final double distanceKm;
  final String riderName;
  final String riderPhone;
  final String riderVehicle;
  final double riderRating;
  final DateTime createdAt;
  final int stopsCount;
  final String? scheduledTime;
  final bool hasProofOfDelivery;
  final bool isEscrow;
  final double escrowAmount;
  final String? escrowStatus;
  final String? escrowReleaseCode;
  final String waybillNumber;
  final String? geofenceStatus;
  final List<OrderStopItem> stops;

  const DeliveryOrder({
    required this.id,
    this.backendId,
    required this.status,
    required this.serviceType,
    required this.senderName,
    required this.senderPhone,
    required this.pickupAddress,
    required this.pickupLandmark,
    required this.recipientName,
    required this.recipientPhone,
    required this.dropoffAddress,
    required this.dropoffLandmark,
    required this.packageName,
    required this.packageCategory,
    required this.packageWeight,
    required this.securityPin,
    required this.price,
    required this.distanceKm,
    required this.riderName,
    required this.riderPhone,
    required this.riderVehicle,
    required this.riderRating,
    required this.createdAt,
    this.stopsCount = 1,
    this.scheduledTime,
    this.hasProofOfDelivery = false,
    this.isEscrow = false,
    this.escrowAmount = 0.0,
    this.escrowStatus,
    this.escrowReleaseCode,
    this.waybillNumber = 'WB-LOS-2026-8921',
    this.geofenceStatus,
    this.stops = const [],
  });

  String get formattedPrice => '₦${price.toStringAsFixed(0).replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (Match m) => '${m[1]},',
      )}';

  String get formattedEscrowAmount => '₦${escrowAmount.toStringAsFixed(0).replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (Match m) => '${m[1]},',
      )}';

  String get statusDisplay {
    switch (status) {
      case 'searching':
        return 'Live Dispatch Auction';
      case 'assigned':
        return 'Rider Assigned';
      case 'at_pickup':
        return 'Arrived at Pickup';
      case 'in_transit':
        return 'In Transit';
      case 'delivered':
        return 'Delivered';
      default:
        return 'Processing';
    }
  }

  DeliveryOrder copyWith({
    String? id,
    String? backendId,
    String? status,
    String? serviceType,
    String? senderName,
    String? senderPhone,
    String? pickupAddress,
    String? pickupLandmark,
    String? recipientName,
    String? recipientPhone,
    String? dropoffAddress,
    String? dropoffLandmark,
    String? packageName,
    String? packageCategory,
    String? packageWeight,
    String? securityPin,
    double? price,
    double? distanceKm,
    String? riderName,
    String? riderPhone,
    String? riderVehicle,
    double? riderRating,
    DateTime? createdAt,
    int? stopsCount,
    String? scheduledTime,
    bool? hasProofOfDelivery,
    bool? isEscrow,
    double? escrowAmount,
    String? escrowStatus,
    String? escrowReleaseCode,
    String? waybillNumber,
    String? geofenceStatus,
    List<OrderStopItem>? stops,
  }) {
    return DeliveryOrder(
      id: id ?? this.id,
      backendId: backendId ?? this.backendId,
      status: status ?? this.status,
      serviceType: serviceType ?? this.serviceType,
      senderName: senderName ?? this.senderName,
      senderPhone: senderPhone ?? this.senderPhone,
      pickupAddress: pickupAddress ?? this.pickupAddress,
      pickupLandmark: pickupLandmark ?? this.pickupLandmark,
      recipientName: recipientName ?? this.recipientName,
      recipientPhone: recipientPhone ?? this.recipientPhone,
      dropoffAddress: dropoffAddress ?? this.dropoffAddress,
      dropoffLandmark: dropoffLandmark ?? this.dropoffLandmark,
      packageName: packageName ?? this.packageName,
      packageCategory: packageCategory ?? this.packageCategory,
      packageWeight: packageWeight ?? this.packageWeight,
      securityPin: securityPin ?? this.securityPin,
      price: price ?? this.price,
      distanceKm: distanceKm ?? this.distanceKm,
      riderName: riderName ?? this.riderName,
      riderPhone: riderPhone ?? this.riderPhone,
      riderVehicle: riderVehicle ?? this.riderVehicle,
      riderRating: riderRating ?? this.riderRating,
      createdAt: createdAt ?? this.createdAt,
      stopsCount: stopsCount ?? this.stopsCount,
      scheduledTime: scheduledTime ?? this.scheduledTime,
      hasProofOfDelivery: hasProofOfDelivery ?? this.hasProofOfDelivery,
      isEscrow: isEscrow ?? this.isEscrow,
      escrowAmount: escrowAmount ?? this.escrowAmount,
      escrowStatus: escrowStatus ?? this.escrowStatus,
      escrowReleaseCode: escrowReleaseCode ?? this.escrowReleaseCode,
      waybillNumber: waybillNumber ?? this.waybillNumber,
      geofenceStatus: geofenceStatus ?? this.geofenceStatus,
      stops: stops ?? this.stops,
    );
  }
}

import 'load_status.dart';

class LoadModel {
  final String? id;
  final String supplierId;
  final String originCity;
  final String originState;
  final String destCity;
  final String destState;
  final String material;
  final double weightTonnes;
  final double? weightMaxTonnes;
  final String? requiredTruckType;
  final List<int>? requiredTyres;
  final double price;
  final String priceType;
  final int? advancePercentage;
  final DateTime pickupDate;
  final LoadStatus loadStatus;
  final bool isSuperLoad;
  final String? superStatus;
  final String? assignedTruckerId;
  final String? assignedTruckId;
  final String? podPhotoUrl;
  final String? lrPhotoUrl;
  final String? tripStage;
  final int viewsCount;
  final int responsesCount;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? expiresAt;
  final DateTime? completedAt;
  // Booking fields
  final String? bookedByTruckerId;
  final String? bookedTruckId;
  final DateTime? bookingRequestedAt;
  final DateTime? bookingApprovedAt;
  // Geo fields
  final double? originLat;
  final double? originLng;
  final double? destLat;
  final double? destLng;
  final String? originAddress;
  final String? destAddress;
  final double? routeDistanceKm;
  // Super Load / Admin fields
  final int? paymentTermDays;
  final String? proxySupplierName;
  final String? proxySupplierMobile;
  final String? notes;
  final String? postedByAdminId;
  final String? assignedOpsAdminId;
  final bool isVerifiedSupplier;
  // Bulk load group fields
  final int? trucksNeeded;
  final int trucksBooked;

  const LoadModel({
    this.id,
    required this.supplierId,
    required this.originCity,
    required this.originState,
    required this.destCity,
    required this.destState,
    required this.material,
    required this.weightTonnes,
    this.weightMaxTonnes,
    this.requiredTruckType,
    this.requiredTyres,
    required this.price,
    this.priceType = 'negotiable',
    this.advancePercentage,
    required this.pickupDate,
    this.loadStatus = LoadStatus.active,
    this.isSuperLoad = false,
    this.superStatus,
    this.assignedTruckerId,
    this.assignedTruckId,
    this.podPhotoUrl,
    this.lrPhotoUrl,
    this.tripStage,
    this.viewsCount = 0,
    this.responsesCount = 0,
    this.createdAt,
    this.updatedAt,
    this.expiresAt,
    this.completedAt,
    this.bookedByTruckerId,
    this.bookedTruckId,
    this.bookingRequestedAt,
    this.bookingApprovedAt,
    this.originLat,
    this.originLng,
    this.destLat,
    this.destLng,
    this.originAddress,
    this.destAddress,
    this.routeDistanceKm,
    this.paymentTermDays,
    this.proxySupplierName,
    this.proxySupplierMobile,
    this.notes,
    this.postedByAdminId,
    this.assignedOpsAdminId,
    this.isVerifiedSupplier = false,
    this.trucksNeeded,
    this.trucksBooked = 0,
  });

  /// Backward-compat getter — returns the DB string value.
  String get status => loadStatus.toDbValue();

  factory LoadModel.fromJson(Map<String, dynamic> json) {
    return LoadModel(
      id: json['id'] as String?,
      supplierId: json['supplier_id'] as String,
      originCity: json['origin_city'] as String,
      originState: json['origin_state'] as String? ?? '',
      destCity: json['dest_city'] as String,
      destState: json['dest_state'] as String? ?? '',
      material: json['material'] as String,
      weightTonnes: (json['weight_tonnes'] as num).toDouble(),
      weightMaxTonnes: (json['weight_max_tonnes'] as num?)?.toDouble(),
      requiredTruckType: json['required_truck_type'] as String?,
      requiredTyres: (json['required_tyres'] as List<dynamic>?)
          ?.map((e) => e as int)
          .toList(),
      price: (json['price'] as num).toDouble(),
      priceType: json['price_type'] as String? ?? 'negotiable',
      advancePercentage: json['advance_percentage'] as int?,
      pickupDate: DateTime.parse(json['pickup_date'] as String),
      loadStatus: LoadStatus.fromString(json['status'] as String?),
      isSuperLoad: json['is_super_load'] as bool? ?? false,
      superStatus: json['super_status'] as String?,
      assignedTruckerId: json['assigned_trucker_id'] as String?,
      assignedTruckId: json['assigned_truck_id'] as String?,
      podPhotoUrl: json['pod_photo_url'] as String?,
      lrPhotoUrl: json['lr_photo_url'] as String?,
      tripStage: json['trip_stage'] as String?,
      viewsCount: json['views_count'] as int? ?? 0,
      responsesCount: json['responses_count'] as int? ?? 0,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
      expiresAt: json['expires_at'] != null
          ? DateTime.parse(json['expires_at'] as String)
          : null,
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'] as String)
          : null,
      bookedByTruckerId: json['booked_by_trucker_id'] as String?,
      bookedTruckId: json['booked_truck_id'] as String?,
      bookingRequestedAt: json['booking_requested_at'] != null
          ? DateTime.parse(json['booking_requested_at'] as String)
          : null,
      bookingApprovedAt: json['booking_approved_at'] != null
          ? DateTime.parse(json['booking_approved_at'] as String)
          : null,
      originLat: (json['origin_lat'] as num?)?.toDouble(),
      originLng: (json['origin_lng'] as num?)?.toDouble(),
      destLat: (json['dest_lat'] as num?)?.toDouble(),
      destLng: (json['dest_lng'] as num?)?.toDouble(),
      originAddress: json['origin_address'] as String?,
      destAddress: json['dest_address'] as String?,
      routeDistanceKm: (json['route_distance_km'] as num?)?.toDouble(),
      paymentTermDays: json['payment_term_days'] as int?,
      proxySupplierName: json['proxy_supplier_name'] as String?,
      proxySupplierMobile: json['proxy_supplier_mobile'] as String?,
      notes: json['notes'] as String?,
      postedByAdminId: json['posted_by_admin_id'] as String?,
      assignedOpsAdminId: json['assigned_ops_admin_id'] as String?,
      isVerifiedSupplier: json['is_verified_supplier'] as bool? ?? false,
      trucksNeeded: json['trucks_needed'] as int?,
      trucksBooked: json['trucks_booked'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'supplier_id': supplierId,
      'origin_city': originCity,
      'origin_state': originState,
      'dest_city': destCity,
      'dest_state': destState,
      'material': material,
      'weight_tonnes': weightTonnes,
      if (weightMaxTonnes != null) 'weight_max_tonnes': weightMaxTonnes,
      'required_truck_type': requiredTruckType,
      'required_tyres': requiredTyres,
      'price': price,
      'price_type': priceType,
      'advance_percentage': advancePercentage,
      'pickup_date': pickupDate.toIso8601String().split('T').first,
      'status': loadStatus.toDbValue(),
      'is_super_load': isSuperLoad,
      'super_status': superStatus,
      if (originLat != null) 'origin_lat': originLat,
      if (originLng != null) 'origin_lng': originLng,
      if (destLat != null) 'dest_lat': destLat,
      if (destLng != null) 'dest_lng': destLng,
      if (originAddress != null) 'origin_address': originAddress,
      if (destAddress != null) 'dest_address': destAddress,
      if (routeDistanceKm != null) 'route_distance_km': routeDistanceKm,
      if (paymentTermDays != null) 'payment_term_days': paymentTermDays,
      if (notes != null) 'notes': notes,
      if (trucksNeeded != null) 'trucks_needed': trucksNeeded,
      'trucks_booked': trucksBooked,
    };
  }

  String get route => '$originCity → $destCity';

  bool get hasBooking => bookedByTruckerId != null;

  bool get isExpired => loadStatus == LoadStatus.expired;

  LoadModel copyWith({
    String? id,
    String? supplierId,
    String? originCity,
    String? originState,
    String? destCity,
    String? destState,
    String? material,
    double? weightTonnes,
    double? weightMaxTonnes,
    String? requiredTruckType,
    List<int>? requiredTyres,
    double? price,
    String? priceType,
    int? advancePercentage,
    DateTime? pickupDate,
    LoadStatus? loadStatus,
    bool? isSuperLoad,
    String? superStatus,
    String? assignedTruckerId,
    String? assignedTruckId,
    String? podPhotoUrl,
    String? lrPhotoUrl,
    String? tripStage,
    int? viewsCount,
    int? responsesCount,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? expiresAt,
    DateTime? completedAt,
    String? bookedByTruckerId,
    String? bookedTruckId,
    DateTime? bookingRequestedAt,
    DateTime? bookingApprovedAt,
    double? originLat,
    double? originLng,
    double? destLat,
    double? destLng,
    String? originAddress,
    String? destAddress,
    double? routeDistanceKm,
    int? paymentTermDays,
    String? proxySupplierName,
    String? proxySupplierMobile,
    String? notes,
    String? postedByAdminId,
    String? assignedOpsAdminId,
    bool? isVerifiedSupplier,
    int? trucksNeeded,
    int? trucksBooked,
  }) {
    return LoadModel(
      id: id ?? this.id,
      supplierId: supplierId ?? this.supplierId,
      originCity: originCity ?? this.originCity,
      originState: originState ?? this.originState,
      destCity: destCity ?? this.destCity,
      destState: destState ?? this.destState,
      material: material ?? this.material,
      weightTonnes: weightTonnes ?? this.weightTonnes,
      weightMaxTonnes: weightMaxTonnes ?? this.weightMaxTonnes,
      requiredTruckType: requiredTruckType ?? this.requiredTruckType,
      requiredTyres: requiredTyres ?? this.requiredTyres,
      price: price ?? this.price,
      priceType: priceType ?? this.priceType,
      advancePercentage: advancePercentage ?? this.advancePercentage,
      pickupDate: pickupDate ?? this.pickupDate,
      loadStatus: loadStatus ?? this.loadStatus,
      isSuperLoad: isSuperLoad ?? this.isSuperLoad,
      superStatus: superStatus ?? this.superStatus,
      assignedTruckerId: assignedTruckerId ?? this.assignedTruckerId,
      assignedTruckId: assignedTruckId ?? this.assignedTruckId,
      podPhotoUrl: podPhotoUrl ?? this.podPhotoUrl,
      lrPhotoUrl: lrPhotoUrl ?? this.lrPhotoUrl,
      tripStage: tripStage ?? this.tripStage,
      viewsCount: viewsCount ?? this.viewsCount,
      responsesCount: responsesCount ?? this.responsesCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      expiresAt: expiresAt ?? this.expiresAt,
      completedAt: completedAt ?? this.completedAt,
      bookedByTruckerId: bookedByTruckerId ?? this.bookedByTruckerId,
      bookedTruckId: bookedTruckId ?? this.bookedTruckId,
      bookingRequestedAt: bookingRequestedAt ?? this.bookingRequestedAt,
      bookingApprovedAt: bookingApprovedAt ?? this.bookingApprovedAt,
      originLat: originLat ?? this.originLat,
      originLng: originLng ?? this.originLng,
      destLat: destLat ?? this.destLat,
      destLng: destLng ?? this.destLng,
      originAddress: originAddress ?? this.originAddress,
      destAddress: destAddress ?? this.destAddress,
      routeDistanceKm: routeDistanceKm ?? this.routeDistanceKm,
      paymentTermDays: paymentTermDays ?? this.paymentTermDays,
      proxySupplierName: proxySupplierName ?? this.proxySupplierName,
      proxySupplierMobile: proxySupplierMobile ?? this.proxySupplierMobile,
      notes: notes ?? this.notes,
      postedByAdminId: postedByAdminId ?? this.postedByAdminId,
      assignedOpsAdminId: assignedOpsAdminId ?? this.assignedOpsAdminId,
      isVerifiedSupplier: isVerifiedSupplier ?? this.isVerifiedSupplier,
      trucksNeeded: trucksNeeded ?? this.trucksNeeded,
      trucksBooked: trucksBooked ?? this.trucksBooked,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is LoadModel && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'LoadModel(id=$id, $route, status=$status)';
}

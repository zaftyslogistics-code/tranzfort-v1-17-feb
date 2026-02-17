class LoadModel {
  final String? id;
  final String supplierId;
  final String originCity;
  final String originState;
  final String destCity;
  final String destState;
  final String material;
  final double weightTonnes;
  final String? requiredTruckType;
  final List<int>? requiredTyres;
  final double price;
  final String priceType;
  final int? advancePercentage;
  final DateTime pickupDate;
  final String status;
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

  const LoadModel({
    this.id,
    required this.supplierId,
    required this.originCity,
    required this.originState,
    required this.destCity,
    required this.destState,
    required this.material,
    required this.weightTonnes,
    this.requiredTruckType,
    this.requiredTyres,
    required this.price,
    this.priceType = 'negotiable',
    this.advancePercentage,
    required this.pickupDate,
    this.status = 'active',
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
  });

  factory LoadModel.fromJson(Map<String, dynamic> json) {
    return LoadModel(
      id: json['id'] as String?,
      supplierId: json['supplier_id'] as String,
      originCity: json['origin_city'] as String,
      originState: json['origin_state'] as String,
      destCity: json['dest_city'] as String,
      destState: json['dest_state'] as String,
      material: json['material'] as String,
      weightTonnes: (json['weight_tonnes'] as num).toDouble(),
      requiredTruckType: json['required_truck_type'] as String?,
      requiredTyres: (json['required_tyres'] as List<dynamic>?)
          ?.map((e) => e as int)
          .toList(),
      price: (json['price'] as num).toDouble(),
      priceType: json['price_type'] as String? ?? 'negotiable',
      advancePercentage: json['advance_percentage'] as int?,
      pickupDate: DateTime.parse(json['pickup_date'] as String),
      status: json['status'] as String? ?? 'active',
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
      'required_truck_type': requiredTruckType,
      'required_tyres': requiredTyres,
      'price': price,
      'price_type': priceType,
      'advance_percentage': advancePercentage,
      'pickup_date': pickupDate.toIso8601String().split('T').first,
      'status': status,
      'is_super_load': isSuperLoad,
      'super_status': superStatus,
    };
  }

  String get route => '$originCity → $destCity';
}

class TruckModel {
  final String? id;
  final String ownerId;
  final String truckNumber;
  final String bodyType;
  final int tyres;
  final double capacityTonnes;
  final String? rcPhotoUrl;
  final String status;
  final String? rejectionReason;
  final DateTime? verifiedAt;
  final DateTime? createdAt;

  const TruckModel({
    this.id,
    required this.ownerId,
    required this.truckNumber,
    required this.bodyType,
    required this.tyres,
    required this.capacityTonnes,
    this.rcPhotoUrl,
    this.status = 'pending',
    this.rejectionReason,
    this.verifiedAt,
    this.createdAt,
  });

  factory TruckModel.fromJson(Map<String, dynamic> json) {
    return TruckModel(
      id: json['id'] as String?,
      ownerId: json['owner_id'] as String,
      truckNumber: json['truck_number'] as String,
      bodyType: json['body_type'] as String,
      tyres: json['tyres'] as int,
      capacityTonnes: (json['capacity_tonnes'] as num).toDouble(),
      rcPhotoUrl: json['rc_photo_url'] as String?,
      status: json['status'] as String? ?? 'pending',
      rejectionReason: json['rejection_reason'] as String?,
      verifiedAt: json['verified_at'] != null
          ? DateTime.parse(json['verified_at'] as String)
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'owner_id': ownerId,
      'truck_number': truckNumber,
      'body_type': bodyType,
      'tyres': tyres,
      'capacity_tonnes': capacityTonnes,
      'rc_photo_url': rcPhotoUrl,
    };
  }

  bool get isVerified => status == 'verified';
  bool get isRejected => status == 'rejected';
  bool get isPending => status == 'pending';
}

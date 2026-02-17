class ConversationModel {
  final String? id;
  final String loadId;
  final String supplierId;
  final String truckerId;
  final bool isActive;
  final DateTime? lastMessageAt;
  final String? lastMessageText;
  final String? supplierName;
  final String? truckerName;
  final int unreadCount;
  final DateTime? createdAt;

  const ConversationModel({
    this.id,
    required this.loadId,
    required this.supplierId,
    required this.truckerId,
    this.isActive = true,
    this.lastMessageAt,
    this.lastMessageText,
    this.supplierName,
    this.truckerName,
    this.unreadCount = 0,
    this.createdAt,
  });

  factory ConversationModel.fromJson(Map<String, dynamic> json) {
    return ConversationModel(
      id: json['id'] as String?,
      loadId: json['load_id'] as String,
      supplierId: json['supplier_id'] as String,
      truckerId: json['trucker_id'] as String,
      isActive: json['is_active'] as bool? ?? true,
      lastMessageAt: json['last_message_at'] != null
          ? DateTime.parse(json['last_message_at'] as String)
          : null,
      lastMessageText: json['last_message_text'] as String?,
      supplierName: json['supplier_name'] as String?,
      truckerName: json['trucker_name'] as String?,
      unreadCount: json['unread_count'] as int? ?? 0,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'load_id': loadId,
      'supplier_id': supplierId,
      'trucker_id': truckerId,
      'is_active': isActive,
    };
  }
}

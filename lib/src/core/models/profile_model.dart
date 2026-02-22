class ProfileModel {
  final String id;
  final String fullName;
  final String mobile;
  final String email;
  final String? currentRole;
  final String? avatarUrl;
  final String verificationStatus;
  final bool isBanned;
  final String? banReason;
  final String? preferredLanguage;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const ProfileModel({
    required this.id,
    required this.fullName,
    required this.mobile,
    required this.email,
    this.currentRole,
    this.avatarUrl,
    this.verificationStatus = 'unverified',
    this.isBanned = false,
    this.banReason,
    this.preferredLanguage,
    this.createdAt,
    this.updatedAt,
  });

  factory ProfileModel.fromJson(Map<String, dynamic> json) {
    return ProfileModel(
      id: json['id'] as String,
      fullName: json['full_name'] as String? ?? '',
      mobile: json['mobile'] as String? ?? '',
      email: json['email'] as String? ?? '',
      currentRole: json['current_role'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      verificationStatus:
          json['verification_status'] as String? ?? 'unverified',
      isBanned: json['is_banned'] as bool? ?? false,
      banReason: json['ban_reason'] as String?,
      preferredLanguage: json['preferred_language'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'full_name': fullName,
      'mobile': mobile,
      'email': email,
      if (currentRole != null) 'current_role': currentRole,
      if (avatarUrl != null) 'avatar_url': avatarUrl,
      'verification_status': verificationStatus,
      if (preferredLanguage != null) 'preferred_language': preferredLanguage,
    };
  }

  bool get isVerified => verificationStatus == 'verified';
  bool get isSupplier => currentRole == 'supplier';
  bool get isTrucker => currentRole == 'trucker';

  ProfileModel copyWith({
    String? id,
    String? fullName,
    String? mobile,
    String? email,
    String? currentRole,
    String? avatarUrl,
    String? verificationStatus,
    bool? isBanned,
    String? banReason,
    String? preferredLanguage,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ProfileModel(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      mobile: mobile ?? this.mobile,
      email: email ?? this.email,
      currentRole: currentRole ?? this.currentRole,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      verificationStatus: verificationStatus ?? this.verificationStatus,
      isBanned: isBanned ?? this.isBanned,
      banReason: banReason ?? this.banReason,
      preferredLanguage: preferredLanguage ?? this.preferredLanguage,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is ProfileModel && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'ProfileModel(id=$id, $fullName, role=$currentRole)';
}

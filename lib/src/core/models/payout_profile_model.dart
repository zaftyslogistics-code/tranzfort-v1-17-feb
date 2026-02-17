class PayoutProfileModel {
  final String? id;
  final String profileId;
  final String accountHolderName;
  final String accountNumberLast4;
  final String ifscCode;
  final String? bankName;
  final String status;
  final String? rejectionReason;
  final DateTime? createdAt;

  const PayoutProfileModel({
    this.id,
    required this.profileId,
    required this.accountHolderName,
    required this.accountNumberLast4,
    required this.ifscCode,
    this.bankName,
    this.status = 'pending',
    this.rejectionReason,
    this.createdAt,
  });

  factory PayoutProfileModel.fromJson(Map<String, dynamic> json) {
    return PayoutProfileModel(
      id: json['id'] as String?,
      profileId: json['profile_id'] as String,
      accountHolderName: json['account_holder_name'] as String,
      accountNumberLast4: json['account_number_last4'] as String,
      ifscCode: json['ifsc_code'] as String,
      bankName: json['bank_name'] as String?,
      status: json['status'] as String? ?? 'pending',
      rejectionReason: json['rejection_reason'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'profile_id': profileId,
      'account_holder_name': accountHolderName,
      'account_number_last4': accountNumberLast4,
      'ifsc_code': ifscCode,
      'bank_name': bankName,
    };
  }
}

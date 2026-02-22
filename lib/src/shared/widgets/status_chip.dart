import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/models/load_status.dart';

class StatusChip extends StatelessWidget {
  final String status;
  final String? role;
  final String? locale;

  const StatusChip({
    super.key,
    required this.status,
    this.role,
    this.locale,
  });

  @override
  Widget build(BuildContext context) {
    final colors = _getColors(status);
    final label = _getLabel(status, role, locale);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: colors.bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: colors.text,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  static String _getLabel(String status, String? role, String? locale) {
    // Load/trip statuses → use LoadStatus.displayName for role+locale awareness
    const loadStatuses = {
      'active', 'pending_approval', 'booked', 'in_transit',
      'delivered', 'completed', 'cancelled', 'expired',
    };
    if (loadStatuses.contains(status.toLowerCase()) && locale != null) {
      final ls = LoadStatus.fromString(status);
      return ls.displayName(role ?? '', locale);
    }
    // Verification and other statuses → simple localized map
    if (locale == 'hi') {
      return _hiLabels[status.toLowerCase()] ?? status;
    }
    return _enLabels[status.toLowerCase()] ?? status;
  }

  static const _enLabels = {
    'active': 'Active',
    'booked': 'Booked',
    'in_transit': 'In Transit',
    'completed': 'Completed',
    'cancelled': 'Cancelled',
    'expired': 'Expired',
    'pending': 'Pending',
    'pending_approval': 'Pending Approval',
    'delivered': 'Delivered',
    'verified': 'Verified',
    'rejected': 'Rejected',
    'unverified': 'Unverified',
  };

  static const _hiLabels = {
    'active': 'एक्टिव',
    'booked': 'बुक्ड',
    'in_transit': 'ट्रांज़िट में',
    'completed': 'पूर्ण',
    'cancelled': 'रद्द',
    'expired': 'एक्सपायर्ड',
    'pending': 'पेंडिंग',
    'pending_approval': 'मंजूरी का इंतजार',
    'delivered': 'डिलीवर हुआ',
    'verified': 'वेरिफाइड',
    'rejected': 'अस्वीकृत',
    'unverified': 'अवेरिफाइड',
  };

  static _ChipColors _getColors(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return _ChipColors(AppColors.successLight, AppColors.success);
      case 'booked':
        return _ChipColors(AppColors.infoLight, AppColors.info);
      case 'in_transit':
        return _ChipColors(AppColors.warningLight, AppColors.warning);
      case 'completed':
        return _ChipColors(AppColors.successLight, AppColors.success);
      case 'delivered':
        return _ChipColors(AppColors.infoLight, AppColors.info);
      case 'pending_approval':
        return _ChipColors(AppColors.warningLight, AppColors.warning);
      case 'cancelled':
        return _ChipColors(AppColors.errorLight, AppColors.error);
      case 'expired':
        return _ChipColors(const Color(0xFFF1F5F9), AppColors.textTertiary);
      case 'pending':
        return _ChipColors(AppColors.warningLight, AppColors.warning);
      case 'verified':
        return _ChipColors(AppColors.successLight, AppColors.success);
      case 'rejected':
        return _ChipColors(AppColors.errorLight, AppColors.error);
      default:
        return _ChipColors(const Color(0xFFF1F5F9), AppColors.textSecondary);
    }
  }
}

class _ChipColors {
  final Color bg;
  final Color text;

  const _ChipColors(this.bg, this.text);
}

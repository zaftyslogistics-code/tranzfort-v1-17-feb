import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

class StatusChip extends StatelessWidget {
  final String status;

  const StatusChip({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final config = _getConfig(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: config.bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        config.label,
        style: TextStyle(
          color: config.text,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  static _ChipConfig _getConfig(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return _ChipConfig('Active', AppColors.successLight, AppColors.success);
      case 'booked':
        return _ChipConfig('Booked', AppColors.infoLight, AppColors.info);
      case 'in_transit':
        return _ChipConfig(
            'In Transit', AppColors.warningLight, AppColors.warning);
      case 'completed':
        return _ChipConfig(
            'Completed', AppColors.successLight, AppColors.success);
      case 'cancelled':
        return _ChipConfig(
            'Cancelled', AppColors.errorLight, AppColors.error);
      case 'expired':
        return _ChipConfig(
            'Expired', const Color(0xFFF1F5F9), AppColors.textTertiary);
      case 'pending':
        return _ChipConfig(
            'Pending', AppColors.warningLight, AppColors.warning);
      case 'verified':
        return _ChipConfig(
            'Verified', AppColors.successLight, AppColors.success);
      case 'rejected':
        return _ChipConfig(
            'Rejected', AppColors.errorLight, AppColors.error);
      default:
        return _ChipConfig(
            status, const Color(0xFFF1F5F9), AppColors.textSecondary);
    }
  }
}

class _ChipConfig {
  final String label;
  final Color bg;
  final Color text;

  const _ChipConfig(this.label, this.bg, this.text);
}

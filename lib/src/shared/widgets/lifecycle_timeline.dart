import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_typography.dart';
import '../../core/models/load_status.dart';

/// Horizontal lifecycle timeline showing load/trip progress stages.
/// Stages: Posted → Booked → Started → In Transit → Delivered → Completed
class LifecycleTimeline extends StatelessWidget {
  final String currentStatus;
  final String? role;
  final String? locale;
  final ValueChanged<int>? onStageTap;

  const LifecycleTimeline({
    super.key,
    required this.currentStatus,
    this.role,
    this.locale,
    this.onStageTap,
  });

  static const _stages = [
    LoadStatus.active,
    LoadStatus.pendingApproval,
    LoadStatus.booked,
    LoadStatus.inTransit,
    LoadStatus.delivered,
    LoadStatus.completed,
  ];

  static const _stageIcons = [
    Icons.publish,
    Icons.hourglass_top,
    Icons.handshake,
    Icons.local_shipping,
    Icons.inventory_2,
    Icons.check_circle,
  ];

  @override
  Widget build(BuildContext context) {
    final current = LoadStatus.fromString(currentStatus);
    final currentIdx = _stages.indexOf(current);
    // If cancelled/expired, show all as incomplete
    final isCancelled =
        current == LoadStatus.cancelled || current == LoadStatus.expired;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Stage dots + connecting lines
        Row(
          children: List.generate(_stages.length * 2 - 1, (i) {
            if (i.isOdd) {
              // Connector line
              final stageIdx = i ~/ 2;
              final isCompleted = !isCancelled && stageIdx < currentIdx;
              return Expanded(
                child: Container(
                  height: 2,
                  color: isCompleted
                      ? AppColors.brandTeal
                      : AppColors.textTertiary.withValues(alpha: 0.2),
                ),
              );
            }
            // Stage dot
            final stageIdx = i ~/ 2;
            final isCompleted = !isCancelled && stageIdx <= currentIdx;
            final isCurrent = !isCancelled && stageIdx == currentIdx;

            return GestureDetector(
              onTap: onStageTap != null ? () => onStageTap!(stageIdx) : null,
              child: Column(
                children: [
                  Container(
                    width: isCurrent ? 28 : 22,
                    height: isCurrent ? 28 : 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isCancelled
                          ? AppColors.textTertiary.withValues(alpha: 0.2)
                          : isCompleted
                              ? AppColors.brandTeal
                              : AppColors.textTertiary.withValues(alpha: 0.15),
                      border: isCurrent
                          ? Border.all(color: AppColors.brandTeal, width: 2.5)
                          : null,
                    ),
                    child: Icon(
                      isCompleted && !isCurrent
                          ? Icons.check
                          : _stageIcons[stageIdx],
                      size: isCurrent ? 14 : 11,
                      color: isCompleted
                          ? Colors.white
                          : AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            );
          }),
        ),
        const SizedBox(height: 6),
        // Stage labels
        Row(
          children: List.generate(_stages.length, (i) {
            final isCurrent = !isCancelled && i == currentIdx;
            final label = _stages[i].displayName(role ?? '', locale ?? 'en');
            // Shorten labels for compact display
            final shortLabel = _shortenLabel(label);
            return Expanded(
              child: Text(
                shortLabel,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.caption.copyWith(
                  fontSize: 9,
                  fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w400,
                  color: isCurrent
                      ? AppColors.brandTeal
                      : AppColors.textTertiary,
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  String _shortenLabel(String label) {
    // Truncate long labels for timeline display
    if (label.length > 12) return '${label.substring(0, 10)}…';
    return label;
  }
}

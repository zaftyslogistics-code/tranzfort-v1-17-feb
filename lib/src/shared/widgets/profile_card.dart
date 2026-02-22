import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_typography.dart';

/// Reusable profile card for displaying supplier or trucker info.
/// Used on load_detail_screen (supplier card for truckers, trucker card for suppliers after booking).
class ProfileCard extends StatelessWidget {
  final String name;
  final String? avatarUrl;
  final String role;
  final bool isVerified;
  final double rating;
  final int ratingCount;
  final String? subtitle;
  final List<ProfileStat> stats;
  final VoidCallback? onTap;

  const ProfileCard({
    super.key,
    required this.name,
    this.avatarUrl,
    required this.role,
    this.isVerified = false,
    this.rating = 0,
    this.ratingCount = 0,
    this.subtitle,
    this.stats = const [],
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(12),
          boxShadow: AppColors.cardShadow,
        ),
        child: Row(
          children: [
            // Avatar
            CircleAvatar(
              radius: 24,
              backgroundColor: role == 'supplier'
                  ? AppColors.brandOrangeLight
                  : AppColors.brandTealLight,
              backgroundImage:
                  avatarUrl != null ? NetworkImage(avatarUrl!) : null,
              child: avatarUrl == null
                  ? Text(
                      initial,
                      style: TextStyle(
                        color: role == 'supplier'
                            ? AppColors.brandOrange
                            : AppColors.brandTeal,
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          name,
                          style: AppTypography.bodyMedium.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isVerified) ...[
                        const SizedBox(width: 4),
                        const Icon(Icons.verified,
                            size: 16, color: AppColors.brandTeal),
                      ],
                    ],
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  const SizedBox(height: 4),
                  // Rating
                  if (rating > 0 || ratingCount > 0)
                    Row(
                      children: [
                        ...List.generate(5, (i) {
                          final starValue = i + 1;
                          if (starValue <= rating.floor()) {
                            return const Icon(Icons.star,
                                size: 14, color: AppColors.brandOrange);
                          } else if (starValue - 0.5 <= rating) {
                            return const Icon(Icons.star_half,
                                size: 14, color: AppColors.brandOrange);
                          }
                          return Icon(Icons.star_border,
                              size: 14,
                              color: AppColors.textTertiary.withValues(alpha: 0.5));
                        }),
                        const SizedBox(width: 4),
                        Text(
                          rating > 0
                              ? '${rating.toStringAsFixed(1)} ($ratingCount)'
                              : 'No ratings',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  // Stats row
                  if (stats.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 12,
                      children: stats
                          .map((s) => Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(s.icon,
                                      size: 13, color: AppColors.textTertiary),
                                  const SizedBox(width: 3),
                                  Text(
                                    s.label,
                                    style: AppTypography.caption.copyWith(
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ))
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),
            if (onTap != null)
              const Icon(Icons.chevron_right,
                  size: 20, color: AppColors.textTertiary),
          ],
        ),
      ),
    );
  }
}

class ProfileStat {
  final IconData icon;
  final String label;

  const ProfileStat({required this.icon, required this.label});
}

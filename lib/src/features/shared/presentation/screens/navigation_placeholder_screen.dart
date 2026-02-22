import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';

/// GPS: Navigation system placeholder screen.
/// Full implementation planned in advance-gps.md (91 tasks, 10 phases).
class NavigationPlaceholderScreen extends StatelessWidget {
  final String? loadId;
  final String? origin;
  final String? destination;

  const NavigationPlaceholderScreen({
    super.key,
    this.loadId,
    this.origin,
    this.destination,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(title: const Text('Navigation')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: AppColors.brandTeal.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.navigation_rounded,
                  size: 56,
                  color: AppColors.brandTeal,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Navigation Coming Soon',
                style: AppTypography.h2Section,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'नेविगेशन जल्द आ रहा है',
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              if (origin != null && destination != null) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.cardBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.location_on, color: AppColors.success, size: 20),
                      const SizedBox(width: 8),
                      Text(origin!, style: AppTypography.bodyMedium),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Icon(Icons.arrow_forward, size: 16, color: AppColors.textTertiary),
                      ),
                      const Icon(Icons.flag, color: AppColors.error, size: 20),
                      const SizedBox(width: 8),
                      Text(destination!, style: AppTypography.bodyMedium),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
              Text(
                'Voice-first Hindi navigation with\nflutter_map + OSRM routing',
                style: AppTypography.caption.copyWith(
                  color: AppColors.textTertiary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              OutlinedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Go Back'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

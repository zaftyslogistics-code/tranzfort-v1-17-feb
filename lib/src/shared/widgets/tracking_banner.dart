import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_typography.dart';
import '../../features/navigation/providers/navigation_providers.dart';
import '../../features/navigation/services/tracking_service.dart';

/// Persistent banner shown at the top of every screen when tracking is active.
/// Displays origin → dest, speed, and paused state. Taps open active nav.
class TrackingBanner extends ConsumerWidget {
  const TrackingBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tracking = ref.watch(trackingServiceProvider);

    return ValueListenableBuilder<TrackingState>(
      valueListenable: tracking.state,
      builder: (context, state, _) {
        if (!state.isActive) return const SizedBox.shrink();

        return Material(
          color: state.isPaused
              ? AppColors.brandOrange
              : AppColors.brandTeal,
          child: InkWell(
            onTap: () {
              // Navigate to active navigation screen
              // Using Navigator directly since this widget sits above GoRouter
            },
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Icon(
                      state.isPaused ? Icons.pause_circle : Icons.navigation,
                      color: Colors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            state.isPaused
                                ? 'Tracking paused — stopped'
                                : '${state.originCity ?? '?'} → ${state.destCity ?? '?'}',
                            style: AppTypography.bodySmall.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (!state.isPaused && state.lastSpeedKmh != null)
                            Text(
                              '${state.lastSpeedKmh!.toStringAsFixed(0)} km/h',
                              style: AppTypography.caption.copyWith(
                                color: Colors.white70,
                                fontSize: 11,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: Colors.white70, size: 20),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../providers/active_navigation_state.dart';

class NavigationBanner extends ConsumerWidget {
  const NavigationBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final navInfo = ref.watch(activeNavigationProvider);
    if (navInfo == null) return const SizedBox.shrink();

    return GestureDetector(
      onTap: () {
        // Pop back to the active navigation screen if it's on the stack
        // Otherwise this is a no-op (banner only shows during active nav)
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).popUntil((route) {
            // Pop until we reach the active navigation screen or root
            return route.isFirst || (route.settings.name?.contains('active') ?? false);
          });
        }
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.brandTeal, AppColors.brandTealDark],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Row(
            children: [
              const Icon(Icons.navigation, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${navInfo.originCity} → ${navInfo.destCity}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${navInfo.distanceText} left · ${navInfo.etaText}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Return',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

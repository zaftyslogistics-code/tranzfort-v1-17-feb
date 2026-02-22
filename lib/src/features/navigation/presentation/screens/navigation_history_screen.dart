import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tranzfort/l10n/app_localizations.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/providers/auth_service_provider.dart';
import '../../../../core/utils/dialogs.dart';
import '../../providers/navigation_providers.dart';

/// GPS-13.5: Navigation history screen — last 20 routes
class NavigationHistoryScreen extends ConsumerStatefulWidget {
  const NavigationHistoryScreen({super.key});

  @override
  ConsumerState<NavigationHistoryScreen> createState() =>
      _NavigationHistoryScreenState();
}

class _NavigationHistoryScreenState
    extends ConsumerState<NavigationHistoryScreen> {
  List<Map<String, dynamic>> _history = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final userId = ref.read(authServiceProvider).currentUser?.id;
    if (userId == null) return;
    setState(() => _isLoading = true);
    try {
      final tracking = ref.read(trackingServiceProvider);
      final history = await tracking.getRecentNavigations(userId, limit: 20);
      if (mounted) setState(() => _history = history);
    } catch (e) {
      if (mounted) {
        AppDialogs.showErrorSnackBar(context, 'Failed to load history: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}w ago';
    return '${(diff.inDays / 30).floor()}mo ago';
  }

  String _formatDate(DateTime dt) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }

  void _navigateToRoute(Map<String, dynamic> nav) {
    final origin = nav['origin_city'] as String? ?? '';
    final dest = nav['dest_city'] as String? ?? '';
    final originLat = (nav['origin_lat'] as num?)?.toDouble();
    final originLng = (nav['origin_lng'] as num?)?.toDouble();
    final destLat = (nav['dest_lat'] as num?)?.toDouble();
    final destLng = (nav['dest_lng'] as num?)?.toDouble();

    if (originLat != null && originLng != null && destLat != null && destLng != null) {
      context.push('/navigation/preview', extra: {
        'originLat': originLat,
        'originLng': originLng,
        'destLat': destLat,
        'destLng': destLng,
        'originCity': origin,
        'destCity': dest,
      });
    } else {
      // Fall back to navigation home with cities pre-filled
      context.push('/navigation', extra: {
        'origin': origin,
        'destination': dest,
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        title: Text(l10n.navRecentDestinations),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _history.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.history,
                          size: 64, color: AppColors.textTertiary),
                      const SizedBox(height: 16),
                      Text(
                        'No navigation history yet',
                        style: AppTypography.bodyMedium
                            .copyWith(color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Your recent routes will appear here',
                        style: AppTypography.caption
                            .copyWith(color: AppColors.textTertiary),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadHistory,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(AppSpacing.screenPaddingH),
                    itemCount: _history.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final nav = _history[index];
                      return _buildHistoryCard(nav);
                    },
                  ),
                ),
    );
  }

  Widget _buildHistoryCard(Map<String, dynamic> nav) {
    final origin = nav['origin_city'] as String? ?? '';
    final dest = nav['dest_city'] as String? ?? '';
    final distKm = nav['distance_km'] as num?;
    final durationMin = nav['duration_min'] as num?;
    final navigatedAt =
        DateTime.tryParse(nav['navigated_at']?.toString() ?? '');
    final ago = navigatedAt != null ? _timeAgo(navigatedAt) : '';
    final dateStr = navigatedAt != null ? _formatDate(navigatedAt) : '';

    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(12),
        boxShadow: AppColors.cardShadow,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _navigateToRoute(nav),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // Route icon
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.brandTealLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.route,
                    color: AppColors.brandTeal, size: 22),
              ),
              const SizedBox(width: 12),
              // Route details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$origin → $dest',
                      style: AppTypography.bodyMedium
                          .copyWith(fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (distKm != null) ...[
                          Icon(Icons.straighten,
                              size: 13, color: AppColors.textTertiary),
                          const SizedBox(width: 3),
                          Text(
                            '${distKm.toStringAsFixed(0)} km',
                            style: AppTypography.caption
                                .copyWith(color: AppColors.textTertiary),
                          ),
                          const SizedBox(width: 10),
                        ],
                        if (durationMin != null) ...[
                          Icon(Icons.schedule,
                              size: 13, color: AppColors.textTertiary),
                          const SizedBox(width: 3),
                          Text(
                            '${durationMin.toStringAsFixed(0)} min',
                            style: AppTypography.caption
                                .copyWith(color: AppColors.textTertiary),
                          ),
                          const SizedBox(width: 10),
                        ],
                        if (dateStr.isNotEmpty)
                          Text(
                            dateStr,
                            style: AppTypography.caption
                                .copyWith(color: AppColors.textTertiary),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              // Time ago + chevron
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (ago.isNotEmpty)
                    Text(
                      ago,
                      style: AppTypography.caption.copyWith(
                        color: AppColors.brandTeal,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  const SizedBox(height: 4),
                  const Icon(Icons.chevron_right,
                      size: 18, color: AppColors.textTertiary),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

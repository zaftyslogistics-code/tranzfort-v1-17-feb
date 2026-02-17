import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/providers/auth_service_provider.dart';
import '../../../../core/utils/animations.dart';
import '../../../../core/utils/dialogs.dart';
import '../../../../shared/widgets/app_drawer.dart';
import '../../../../shared/widgets/bottom_nav_bar.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/error_retry.dart';
import '../../../../shared/widgets/skeleton_loader.dart';
import '../../../../shared/widgets/status_chip.dart';

final _myTripsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final userId = ref.read(authServiceProvider).currentUser?.id;
  if (userId == null) return [];
  return ref.read(databaseServiceProvider).getMyTrips(userId);
});

class MyTripsScreen extends ConsumerWidget {
  const MyTripsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tripsAsync = ref.watch(_myTripsProvider);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.scaffoldBg,
        drawer: const AppDrawer(),
        appBar: AppBar(
          title: const Text('My Trips'),
          bottom: const TabBar(
            indicatorColor: AppColors.brandTeal,
            labelColor: AppColors.brandTeal,
            unselectedLabelColor: AppColors.textTertiary,
            tabs: [
              Tab(text: 'Active'),
              Tab(text: 'Completed'),
            ],
          ),
        ),
        bottomNavigationBar: const BottomNavBar(currentRole: 'trucker'),
        body: tripsAsync.when(
          loading: () => const SkeletonLoader(
            itemCount: 3,
            type: SkeletonType.card,
          ),
          error: (e, _) => ErrorRetry(
            onRetry: () => ref.invalidate(_myTripsProvider),
          ),
          data: (trips) {
            final active = trips
                .where((t) =>
                    ['booked', 'in_transit'].contains(t['status']))
                .toList();
            final completed = trips
                .where((t) => t['status'] == 'completed')
                .toList();

            return TabBarView(
              children: [
                _TripList(
                  trips: active,
                  emptyTitle: 'No active trips',
                  emptyDesc: 'Accepted loads will appear here',
                  onRefresh: () => ref.invalidate(_myTripsProvider),
                ),
                _TripList(
                  trips: completed,
                  emptyTitle: 'No completed trips',
                  emptyDesc: 'Delivered loads will appear here',
                  onRefresh: () => ref.invalidate(_myTripsProvider),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _TripList extends StatelessWidget {
  final List<Map<String, dynamic>> trips;
  final String emptyTitle;
  final String emptyDesc;
  final VoidCallback onRefresh;

  const _TripList({
    required this.trips,
    required this.emptyTitle,
    required this.emptyDesc,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    if (trips.isEmpty) {
      return EmptyState(
        icon: Icons.assignment_outlined,
        title: emptyTitle,
        description: emptyDesc,
      );
    }

    return RefreshIndicator(
      color: AppColors.brandTeal,
      onRefresh: () async => onRefresh(),
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.all(AppSpacing.screenPaddingH),
        itemCount: trips.length,
        itemBuilder: (context, index) {
          return _TripCard(
            trip: trips[index],
            onStageUpdated: onRefresh,
          ).staggerEntrance(index);
        },
      ),
    );
  }
}

const _tripStages = [
  'not_started',
  'reached_pickup',
  'loading',
  'in_transit',
  'reached_destination',
  'unloading',
  'delivered',
];

const _stageLabels = {
  'not_started': 'Not Started',
  'reached_pickup': 'Reached Pickup',
  'loading': 'Loading',
  'in_transit': 'In Transit',
  'reached_destination': 'Reached Destination',
  'unloading': 'Unloading',
  'delivered': 'Delivered',
};

const _stageIcons = {
  'not_started': Icons.schedule,
  'reached_pickup': Icons.location_on,
  'loading': Icons.upload,
  'in_transit': Icons.local_shipping,
  'reached_destination': Icons.flag,
  'unloading': Icons.download,
  'delivered': Icons.check_circle,
};

class _TripCard extends ConsumerStatefulWidget {
  final Map<String, dynamic> trip;
  final VoidCallback onStageUpdated;

  const _TripCard({required this.trip, required this.onStageUpdated});

  @override
  ConsumerState<_TripCard> createState() => _TripCardState();
}

class _TripCardState extends ConsumerState<_TripCard> {
  bool _isUpdating = false;

  String get _currentStage =>
      widget.trip['trip_stage'] as String? ?? 'not_started';

  int get _currentIndex => _tripStages.indexOf(_currentStage);

  String? get _nextStage {
    final idx = _currentIndex;
    if (idx < 0 || idx >= _tripStages.length - 1) return null;
    return _tripStages[idx + 1];
  }

  Future<void> _advanceStage() async {
    final next = _nextStage;
    if (next == null) return;

    setState(() => _isUpdating = true);
    HapticFeedback.mediumImpact();

    try {
      final db = ref.read(databaseServiceProvider);
      await db.updateTripStage(widget.trip['id'], next);
      widget.onStageUpdated();
    } catch (e) {
      if (mounted) {
        AppDialogs.showErrorSnackBar(context, e);
      }
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final trip = widget.trip;
    final status = trip['status'] as String? ?? 'booked';
    final isDelivered = _currentStage == 'delivered';

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.cardGap),
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Route + status
          Row(
            children: [
              Expanded(
                child: Text(
                  '${trip['origin_city']} → ${trip['dest_city']}',
                  style: AppTypography.h3Subsection,
                ),
              ),
              StatusChip(status: status),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${trip['material']} • ${trip['weight_tonnes']} tonnes • ₹${trip['price']}/ton',
            style: AppTypography.bodySmall
                .copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),

          // Trip stage progress
          _buildStageProgress(),

          // Advance button
          if (!isDelivered && status != 'completed') ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _isUpdating ? null : _advanceStage,
                icon: _isUpdating
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.brandTeal,
                        ),
                      )
                    : Icon(_stageIcons[_nextStage] ?? Icons.arrow_forward,
                        size: 18),
                label: Text(
                  _nextStage != null
                      ? 'Mark: ${_stageLabels[_nextStage]}'
                      : 'Up to date',
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.brandTeal,
                  side: const BorderSide(color: AppColors.brandTeal),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStageProgress() {
    return Row(
      children: List.generate(_tripStages.length, (i) {
        final isCompleted = i <= _currentIndex;
        final isCurrent = i == _currentIndex;

        return Expanded(
          child: Row(
            children: [
              Container(
                width: isCurrent ? 14 : 10,
                height: isCurrent ? 14 : 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isCompleted
                      ? AppColors.brandTeal
                      : AppColors.textTertiary.withValues(alpha: 0.3),
                  border: isCurrent
                      ? Border.all(color: AppColors.brandTeal, width: 2)
                      : null,
                ),
              ),
              if (i < _tripStages.length - 1)
                Expanded(
                  child: Container(
                    height: 2,
                    color: i < _currentIndex
                        ? AppColors.brandTeal
                        : AppColors.textTertiary.withValues(alpha: 0.2),
                  ),
                ),
            ],
          ),
        );
      }),
    );
  }
}

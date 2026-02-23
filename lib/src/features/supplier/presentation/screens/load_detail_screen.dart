import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tranzfort/l10n/app_localizations.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/providers/auth_service_provider.dart';
import '../../../../core/utils/dialogs.dart';
import '../../../../core/utils/haptics.dart';
import '../../../../core/utils/map_launcher.dart';
import '../../../../shared/widgets/app_drawer.dart';
import '../../../../shared/widgets/route_map_preview.dart';
import '../../../../shared/widgets/profile_card.dart';
import '../../../../shared/widgets/status_chip.dart';
import '../../../../shared/widgets/error_retry.dart';
import '../../../../shared/widgets/skeleton_loader.dart';
import '../../../../core/providers/locale_provider.dart';
import '../../../../core/utils/status_localizer.dart';
import '../../../../shared/widgets/tts_button.dart';
import '../../../../shared/widgets/lifecycle_timeline.dart';

final _loadDetailProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>?, String>((ref, loadId) async {
  return ref.read(databaseServiceProvider).getLoadById(loadId);
});

class LoadDetailScreen extends ConsumerWidget {
  final String loadId;

  const LoadDetailScreen({super.key, required this.loadId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loadFuture = ref.watch(_loadDetailProvider(loadId));

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.loadDetails),
        actions: [
          if (loadFuture.valueOrNull != null) ...[
            TtsButton(
              text: 'Read aloud',
              spokenText: _buildTtsText(
                loadFuture.valueOrNull!,
                isHindi: ref.watch(localeProvider).languageCode == 'hi',
              ),
              size: 22,
              locale: ref.watch(localeProvider).languageCode == 'hi' ? 'hi-IN' : 'en-IN',
            ),
            IconButton(
              icon: const Icon(Icons.share_outlined),
              tooltip: AppLocalizations.of(context)!.share,
              onPressed: () => _shareLoad(loadFuture.valueOrNull!),
            ),
          ],
        ],
      ),
      body: loadFuture.when(
        loading: () => const SkeletonLoader(
          itemCount: 4,
          type: SkeletonType.card,
        ),
        error: (e, _) => ErrorRetry(
          onRetry: () => ref.invalidate(_loadDetailProvider(loadId)),
        ),
        data: (load) {
          if (load == null) {
            return Center(child: Text(AppLocalizations.of(context)!.notFound));
          }

          final status = load['status'] as String? ?? 'active';

          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(AppSpacing.screenPaddingH),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Route header
                Container(
                  padding: const EdgeInsets.all(AppSpacing.cardPadding),
                  decoration: BoxDecoration(
                    color: AppColors.cardBg,
                    borderRadius:
                        BorderRadius.circular(AppSpacing.cardRadius),
                    boxShadow: AppColors.cardShadow,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${load['origin_city']} → ${load['dest_city']}',
                              style: AppTypography.h2Section,
                            ),
                          ),
                          StatusChip(
                            status: status,
                            role: 'supplier',
                            locale: ref.watch(localeProvider).languageCode,
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${load['origin_state']} → ${load['dest_state']}',
                        style: AppTypography.bodySmall
                            .copyWith(color: AppColors.textSecondary),
                      ),
                      // Phase 8: Show precise addresses if available
                      if (load['origin_address'] != null ||
                          load['dest_address'] != null) ...[
                        const SizedBox(height: 6),
                        if (load['origin_address'] != null)
                          Row(
                            children: [
                              const Icon(Icons.circle, size: 8, color: AppColors.success),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  load['origin_address'] as String,
                                  style: AppTypography.caption.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        if (load['dest_address'] != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Row(
                              children: [
                                const Icon(Icons.location_on, size: 8, color: AppColors.error),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    load['dest_address'] as String,
                                    style: AppTypography.caption.copyWith(
                                      color: AppColors.textSecondary,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                      // Phase 8: Show route distance and duration
                      if (load['route_distance_km'] != null) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.route, size: 14, color: AppColors.brandTeal),
                            const SizedBox(width: 6),
                            Text(
                              '${(load['route_distance_km'] as num).round()} km'
                              '${load['route_duration_min'] != null ? ' \u2022 ~${((load['route_duration_min'] as num).toDouble() / 60).toStringAsFixed(1)} hrs' : ''}',
                              style: AppTypography.bodySmall.copyWith(
                                color: AppColors.brandTeal,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Task 5.12: Lifecycle timeline
                Container(
                  padding: const EdgeInsets.all(AppSpacing.cardPadding),
                  decoration: BoxDecoration(
                    color: AppColors.cardBg,
                    borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
                    boxShadow: AppColors.cardShadow,
                  ),
                  child: LifecycleTimeline(
                    currentStatus: status,
                    role: ref.watch(userRoleProvider).valueOrNull ?? 'supplier',
                    locale: ref.watch(localeProvider).languageCode,
                  ),
                ),
                const SizedBox(height: 16),

                // Static route map (only if lat/lng available)
                Builder(builder: (_) {
                  final oLat = (load['origin_lat'] as num?)?.toDouble();
                  final oLng = (load['origin_lng'] as num?)?.toDouble();
                  final dLat = (load['dest_lat'] as num?)?.toDouble();
                  final dLng = (load['dest_lng'] as num?)?.toDouble();

                  if (oLat != null && oLng != null && dLat != null && dLng != null) {
                    return Column(
                      children: [
                        RouteMapPreview(
                          originLat: oLat,
                          originLng: oLng,
                          destLat: dLat,
                          destLng: dLng,
                          originLabel: load['origin_city'] as String?,
                          destLabel: load['dest_city'] as String?,
                          height: 140,
                          onTap: () => MapLauncher.openGoogleMapsRoute(
                            originLat: oLat,
                            originLng: oLng,
                            destLat: dLat,
                            destLng: dLng,
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () => MapLauncher.openGoogleMapsRoute(
                              originLat: oLat,
                              originLng: oLng,
                              destLat: dLat,
                              destLng: dLng,
                            ),
                            icon: const Icon(Icons.map_outlined, size: 18),
                            label: const Text('Open in Google Maps'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.brandTeal,
                              side: const BorderSide(color: AppColors.brandTeal),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    );
                  }
                  return const SizedBox.shrink();
                }),

                // Details
                _detailSection(context, AppLocalizations.of(context)!.material, [
                  _detailRow(context, AppLocalizations.of(context)!.material, load['material'] ?? '-'),
                  _detailRow(context, AppLocalizations.of(context)!.weight, '${load['weight_tonnes'] ?? '-'} ${AppLocalizations.of(context)!.tonnes}'),
                ]),
                const SizedBox(height: 16),

                _detailSection(context, AppLocalizations.of(context)!.truckType, [
                  _detailRow(context, AppLocalizations.of(context)!.truckType,
                      load['required_truck_type'] ?? 'Any'),
                  _detailRow(context, AppLocalizations.of(context)!.tyres,
                      (load['required_tyres'] as List?)?.join(', ') ??
                          'Any'),
                ]),
                const SizedBox(height: 16),

                _detailSection(context, AppLocalizations.of(context)!.price, [
                  _detailRow(context, AppLocalizations.of(context)!.price,
                      '₹${load['price']}/${AppLocalizations.of(context)!.tonnes} (${load['price_type'] ?? AppLocalizations.of(context)!.negotiable})'),
                  _detailRow(context, AppLocalizations.of(context)!.pickupDate,
                      load['pickup_date'] ?? '-'),
                ]),
                const SizedBox(height: 16),

                _detailSection(context, AppLocalizations.of(context)!.status, [
                  _detailRow(context,
                      AppLocalizations.of(context)!.status, '${load['views_count'] ?? 0}'),
                  _detailRow(context, AppLocalizations.of(context)!.interestedTruckers,
                      '${load['responses_count'] ?? 0}'),
                ]),
                const SizedBox(height: 24),

                // Additional details
                if (load['advance_percentage'] != null ||
                    (load['notes'] as String?)?.isNotEmpty == true)
                  _detailSection(context, 'Additional', [
                    if (load['advance_percentage'] != null)
                      _detailRow(context, 'Advance',
                          '${load['advance_percentage']}% on loading'),
                    if ((load['notes'] as String?)?.isNotEmpty == true)
                      _detailRow(context, 'Notes', load['notes']),
                  ]),
                if (load['advance_percentage'] != null ||
                    (load['notes'] as String?)?.isNotEmpty == true)
                  const SizedBox(height: 16),

                // Task 7.3: Super Load payment terms
                if (load['is_super_load'] == true) ...[
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.cardPadding),
                    decoration: BoxDecoration(
                      color: AppColors.brandOrangeLight,
                      borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
                      border: Border.all(color: AppColors.brandOrange),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.star, size: 18, color: AppColors.brandOrange),
                            const SizedBox(width: 6),
                            Text('Super Load', style: AppTypography.bodyMedium.copyWith(
                              fontWeight: FontWeight.w700, color: AppColors.brandOrange)),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.brandOrange,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text('TranZfort Guarantee',
                                  style: AppTypography.caption.copyWith(
                                    color: Colors.white, fontWeight: FontWeight.w600, fontSize: 10)),
                            ),
                          ],
                        ),
                        if (load['payment_term_days'] != null) ...[
                          const SizedBox(height: 8),
                          _detailRow(context, 'Payment',
                              '${load['payment_term_days']} working days after POD'),
                        ],
                        if (load['advance_percentage'] != null) ...[
                          const SizedBox(height: 4),
                          Builder(builder: (_) {
                            final price = (load['price'] as num?)?.toDouble() ?? 0;
                            final weight = (load['weight_tonnes'] as num?)?.toDouble() ?? 0;
                            final adv = (load['advance_percentage'] as num?)?.toInt() ?? 0;
                            final total = price * weight;
                            final advAmt = (total * adv / 100).round();
                            final remaining = (total - advAmt).round();
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _detailRow(context, 'Advance',
                                    '$adv% (\u20b9$advAmt on loading)'),
                                const SizedBox(height: 4),
                                _detailRow(context, 'Remaining',
                                    '\u20b9$remaining after delivery'),
                              ],
                            );
                          }),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Phase 4C: Supplier profile card (for truckers viewing load)
                Builder(builder: (_) {
                  String supplierName = load['supplier_name'] as String? ?? '';
                  String? supplierAvatar = load['supplier_avatar'] as String?;
                  if (supplierName.isEmpty && load['suppliers'] is Map) {
                    final sp = (load['suppliers'] as Map)['profiles'];
                    if (sp is Map) {
                      supplierName = sp['full_name'] as String? ?? '';
                      supplierAvatar ??= sp['avatar_url'] as String?;
                    }
                  }
                  final supplierRating = (load['supplier_rating'] as num?)?.toDouble() ?? 0;

                  if (supplierName.isNotEmpty) {
                    return Column(
                      children: [
                        ProfileCard(
                          name: supplierName,
                          avatarUrl: supplierAvatar,
                          role: 'supplier',
                          isVerified: true,
                          rating: supplierRating,
                          subtitle: 'Supplier',
                          stats: [
                            if (load['origin_city'] != null)
                              ProfileStat(
                                icon: Icons.location_on_outlined,
                                label: load['origin_city'] as String,
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),
                      ],
                    );
                  }
                  return const SizedBox.shrink();
                }),

                // Actions — role-aware
                _LoadDetailActions(
                  loadId: loadId,
                  load: load,
                  status: status,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _buildTtsText(Map<String, dynamic> load, {bool isHindi = false}) {
    final status = load['status'] as String? ?? 'active';
    if (isHindi) {
      return '${load['origin_city']} से ${load['dest_city']}। '
          '${load['material']}, ${load['weight_tonnes']} टन। '
          'रेट ${load['price']} रुपये प्रति टन। '
          'ट्रक: ${load['required_truck_type'] ?? 'कोई भी'}। '
          'उठान: ${load['pickup_date'] ?? 'तय नहीं'}। '
          'स्थिति: ${StatusLocalizer.spokenText(status, 'hi')}।';
    }
    return 'Load from ${load['origin_city']} to ${load['dest_city']}. '
        '${load['material']}, ${load['weight_tonnes']} tonnes. '
        'Price ${load['price']} rupees per tonne. '
        'Truck type: ${load['required_truck_type'] ?? 'any'}. '
        'Pickup: ${load['pickup_date'] ?? 'not specified'}. '
        'Status: ${StatusLocalizer.spokenText(status, 'en')}.';
  }

  void _shareLoad(Map<String, dynamic> load) {
    final loadId = load['id'] as String? ?? '';
    // UX-2: Deep link — will resolve when app link domain is configured
    final deepLink = 'https://tranzfort.app/load/$loadId';
    final text = '''
TranZfort Load Available

Route: ${load['origin_city']} to ${load['dest_city']}
Material: ${load['material']}
Weight: ${load['weight_tonnes']} tonnes
Price: Rs ${load['price']}/ton (${load['price_type'] ?? 'negotiable'})
Truck Type: ${load['required_truck_type'] ?? 'Any'}
Pickup: ${load['pickup_date'] ?? '-'}

View on TranZfort: $deepLink
''';
    Share.share(text.trim(), subject: 'Load: ${load['origin_city']} → ${load['dest_city']}');
  }

  Widget _detailSection(BuildContext context, String title, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: AppTypography.overline
                  .copyWith(letterSpacing: 0.8)),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _detailRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(label,
                style: AppTypography.bodySmall
                    .copyWith(color: AppColors.textSecondary)),
          ),
          Expanded(
            child: Text(value, style: AppTypography.bodyMedium),
          ),
        ],
      ),
    );
  }
}

/// Stateful actions widget for load detail — handles booking, approval, navigation.
class _LoadDetailActions extends ConsumerStatefulWidget {
  final String loadId;
  final Map<String, dynamic> load;
  final String status;

  const _LoadDetailActions({
    required this.loadId,
    required this.load,
    required this.status,
  });

  @override
  ConsumerState<_LoadDetailActions> createState() => _LoadDetailActionsState();
}

class _LoadDetailActionsState extends ConsumerState<_LoadDetailActions> {
  bool _isBooking = false;
  bool _isApproving = false;

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(userRoleProvider).valueOrNull ?? 'trucker';
    final userId = ref.read(authServiceProvider).currentUser?.id;
    final isOwner = widget.load['supplier_id'] == userId;
    final l10n = AppLocalizations.of(context)!;

    // ── Supplier: Approve/Reject pending booking ──
    if (isOwner && widget.status == 'pending_approval') {
      return _buildApproveRejectSection(l10n);
    }

    // ── Supplier: Track trucker on booked/in-transit loads ──
    if (isOwner && (widget.status == 'booked' || widget.status == 'in_transit')) {
      return Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => context.push(
                '/navigation/live-tracking/${widget.loadId}',
                extra: {
                  'originCity': widget.load['origin_city'] ?? '',
                  'destCity': widget.load['dest_city'] ?? '',
                },
              ),
              icon: const Icon(Icons.location_on, size: 18),
              label: const Text('Track Trucker Live'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.brandTeal,
                minimumSize: const Size.fromHeight(AppSpacing.buttonHeight),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      );
    }

    // ── Supplier: Active load actions (deactivate, super load request) ──
    if (isOwner && widget.status == 'active') {
      return Column(
        children: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => context.push(
                      '/super-load-request/${widget.loadId}'),
                  icon: const Icon(Icons.star),
                  label: Text(l10n.requestSuperLoad),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(AppSpacing.buttonHeight),
                    side: const BorderSide(color: AppColors.brandOrange),
                    foregroundColor: AppColors.brandOrange,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final confirmed = await AppDialogs.confirm(
                      context,
                      title: l10n.deactivateLoad,
                      description: l10n.deactivateConfirm,
                      confirmText: l10n.deactivateLoad,
                      isDestructive: true,
                    );
                    if (confirmed) {
                      AppHaptics.onDestructive();
                      await ref.read(databaseServiceProvider).updateLoad(
                        widget.loadId, {'status': 'cancelled'},
                      );
                      ref.invalidate(supplierActiveLoadsCountProvider);
                      ref.invalidate(supplierRecentLoadsProvider);
                      if (context.mounted) {
                        AppDialogs.showSuccessSnackBar(context, l10n.loadDeactivated);
                        context.pop();
                      }
                    }
                  },
                  icon: const Icon(Icons.close),
                  label: Text(l10n.deactivateLoad),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(AppSpacing.buttonHeight),
                    side: const BorderSide(color: AppColors.error),
                    foregroundColor: AppColors.error,
                  ),
                ),
              ),
            ],
          ),
        ],
      );
    }

    // ── Trucker: Navigate on booked/in-transit loads ──
    if (role == 'trucker' && (widget.status == 'booked' || widget.status == 'in_transit')) {
      final navLabel = widget.status == 'booked' ? 'Navigate to Pickup' : 'Navigate to Delivery';
      final navCity = widget.status == 'booked'
          ? (widget.load['origin_city'] as String? ?? '')
          : (widget.load['dest_city'] as String? ?? '');
      return Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => context.push('/navigation', extra: {
                'destination': navCity,
                'origin': widget.status == 'in_transit'
                    ? (widget.load['origin_city'] as String? ?? '')
                    : null,
                'loadContext':
                    '${widget.load['origin_city']} → ${widget.load['dest_city']} | ${widget.load['material']} | ${widget.load['weight_tonnes']}T',
              }),
              icon: const Icon(Icons.navigation, size: 18),
              label: Text(navLabel),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.brandTeal,
                minimumSize: const Size.fromHeight(AppSpacing.buttonHeight),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      );
    }

    // ── Trucker: Book This Load (active loads) ──
    if (role == 'trucker' && widget.status == 'active' && userId != null) {
      final price = widget.load['price'];
      return Column(
        children: [
          // Primary CTA: Book This Load
          SizedBox(
            width: double.infinity,
            height: AppSpacing.buttonHeight,
            child: FilledButton.icon(
              onPressed: _isBooking ? null : () => _showTruckSelectionSheet(userId),
              icon: _isBooking
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.check_circle_outline),
              label: Text(_isBooking ? 'Booking...' : 'Book This Load at ₹$price/T'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.brandTeal,
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Secondary: Chat Now
          SizedBox(
            width: double.infinity,
            height: AppSpacing.buttonHeight,
            child: OutlinedButton.icon(
              onPressed: () async {
                final db = ref.read(databaseServiceProvider);
                try {
                  final conv = await db.getOrCreateConversation(
                    loadId: widget.loadId,
                    supplierId: widget.load['supplier_id'],
                    truckerId: userId,
                  );
                  if (context.mounted) {
                    context.push('/chat/${conv['id']}');
                  }
                } catch (e) {
                  if (context.mounted) {
                    AppDialogs.showErrorSnackBar(context, e);
                  }
                }
              },
              icon: const Icon(Icons.chat_bubble_outline),
              label: const Text('Chat with Supplier'),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.brandTeal),
                foregroundColor: AppColors.brandTeal,
              ),
            ),
          ),
        ],
      );
    }

    return const SizedBox.shrink();
  }

  /// Shows bottom sheet with trucker's verified trucks for selection.
  Future<void> _showTruckSelectionSheet(String truckerId) async {
    final db = ref.read(databaseServiceProvider);
    final trucks = await db.getVerifiedTrucks(truckerId);

    if (!mounted) return;

    if (trucks.isEmpty) {
      AppDialogs.showErrorSnackBar(
        context,
        'No verified trucks. Please add and verify a truck first.',
      );
      return;
    }

    // If only one truck, book directly
    if (trucks.length == 1) {
      await _bookWithTruck(truckerId, trucks.first['id'] as String);
      return;
    }

    // Multiple trucks — show selection sheet
    if (!mounted) return;
    final selectedTruckId = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => _TruckSelectionSheet(trucks: trucks),
    );

    if (selectedTruckId != null && mounted) {
      await _bookWithTruck(truckerId, selectedTruckId);
    }
  }

  Future<void> _bookWithTruck(String truckerId, String truckId) async {
    // Task 7.5: Super Load payment terms confirmation
    if (widget.load['is_super_load'] == true) {
      final termDays = widget.load['payment_term_days'] as int? ?? 10;
      final adv = (widget.load['advance_percentage'] as num?)?.toInt() ?? 0;
      final confirmed = await AppDialogs.confirm(
        context,
        title: 'Super Load Booking',
        description:
            'This is a Super Load with TranZfort payment guarantee.\n\n'
            '• Advance: $adv% paid on loading\n'
            '• Remaining: ${100 - adv}% within $termDays working days after POD\n'
            '• Payment guaranteed by TranZfort\n\n'
            'Do you want to proceed?',
        confirmText: 'Book Super Load',
      );
      if (!confirmed || !mounted) return;
    }

    setState(() => _isBooking = true);
    try {
      await ref.read(databaseServiceProvider).bookLoad(
        loadId: widget.loadId,
        truckerId: truckerId,
        truckId: truckId,
      );
      if (mounted) {
        AppHaptics.onPrimaryAction();
        AppDialogs.showSuccessSnackBar(
          context,
          widget.load['is_super_load'] == true
              ? 'Super Load booked! Payment guaranteed by TranZfort.'
              : 'Booking request sent! Supplier will approve.',
        );
        ref.invalidate(_loadDetailProvider(widget.loadId));
      }
    } catch (e) {
      if (mounted) {
        AppDialogs.showErrorSnackBar(context, e);
      }
    } finally {
      if (mounted) setState(() => _isBooking = false);
    }
  }

  Widget _buildApproveRejectSection(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Booking request info card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.cardPadding),
          decoration: BoxDecoration(
            color: AppColors.brandTealLight,
            borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
            border: Border.all(color: AppColors.brandTeal.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.local_shipping, color: AppColors.brandTeal, size: 20),
                  const SizedBox(width: 8),
                  Text('Booking Request', style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.w700)),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'A trucker wants to book this load.',
                style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Approve / Reject buttons
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: _isApproving ? null : () => _handleApprove(),
                icon: _isApproving
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.check, size: 18),
                label: Text(_isApproving ? 'Approving...' : 'Approve Booking'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.success,
                  minimumSize: const Size.fromHeight(AppSpacing.buttonHeight),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _isApproving ? null : () => _handleReject(),
                icon: const Icon(Icons.close, size: 18),
                label: const Text('Reject'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(AppSpacing.buttonHeight),
                  side: const BorderSide(color: AppColors.error),
                  foregroundColor: AppColors.error,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _handleApprove() async {
    setState(() => _isApproving = true);
    try {
      await ref.read(databaseServiceProvider).approveBooking(widget.loadId);
      if (mounted) {
        AppHaptics.onPrimaryAction();
        AppDialogs.showSuccessSnackBar(context, 'Booking approved! Trip created.');
        ref.invalidate(_loadDetailProvider(widget.loadId));
        ref.invalidate(supplierActiveLoadsCountProvider);
      }
    } catch (e) {
      if (mounted) AppDialogs.showErrorSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _isApproving = false);
    }
  }

  Future<void> _handleReject() async {
    final confirmed = await AppDialogs.confirm(
      context,
      title: 'Reject Booking',
      description: 'The load will go back to active and the trucker will be notified.',
      confirmText: 'Reject',
      isDestructive: true,
    );
    if (!confirmed) return;

    setState(() => _isApproving = true);
    try {
      await ref.read(databaseServiceProvider).rejectBooking(widget.loadId);
      if (mounted) {
        AppHaptics.onDestructive();
        AppDialogs.showSuccessSnackBar(context, 'Booking rejected. Load is active again.');
        ref.invalidate(_loadDetailProvider(widget.loadId));
      }
    } catch (e) {
      if (mounted) AppDialogs.showErrorSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _isApproving = false);
    }
  }
}

/// Bottom sheet for selecting a truck when booking a load.
class _TruckSelectionSheet extends StatelessWidget {
  final List<Map<String, dynamic>> trucks;

  const _TruckSelectionSheet({required this.trucks});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Select Truck', style: AppTypography.h2Section),
          const SizedBox(height: 4),
          Text('Choose which truck to use for this load',
              style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: 16),
          ...trucks.map((truck) => _truckTile(context, truck)),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _truckTile(BuildContext context, Map<String, dynamic> truck) {
    final number = truck['truck_number'] as String? ?? '-';
    final bodyType = truck['body_type'] as String? ?? '-';
    final tyres = truck['tyres'];
    final capacity = truck['capacity_tonnes'];

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const CircleAvatar(
          backgroundColor: AppColors.brandTealLight,
          child: Icon(Icons.local_shipping, color: AppColors.brandTeal),
        ),
        title: Text(number, style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
        subtitle: Text('$bodyType | ${tyres}T | ${capacity}T capacity'),
        trailing: FilledButton(
          onPressed: () => Navigator.of(context).pop(truck['id'] as String),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.brandTeal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
          ),
          child: const Text('Select'),
        ),
      ),
    );
  }
}

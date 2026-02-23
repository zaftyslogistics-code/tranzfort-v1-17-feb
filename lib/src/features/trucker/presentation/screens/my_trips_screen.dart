import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tranzfort/l10n/app_localizations.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/providers/auth_service_provider.dart';
import '../../../../core/utils/animations.dart';
import '../../../../core/utils/dialogs.dart';
import '../../../../shared/widgets/app_drawer.dart';
import '../../../../shared/widgets/bottom_nav_bar.dart';
import 'package:go_router/go_router.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/error_retry.dart';
import '../../../../shared/widgets/skeleton_loader.dart';
import '../../../../shared/widgets/status_chip.dart';
import '../../../../core/providers/locale_provider.dart';
import '../../../../shared/widgets/feedback_prompt.dart';
import '../../../../shared/widgets/route_map_preview.dart';
import '../../../../shared/widgets/tts_button.dart';

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
          title: Text(AppLocalizations.of(context)!.myTrips),
          actions: [
            tripsAsync.whenData((trips) {
              final active = trips.where((t) => ['booked','in_transit'].contains(t['status'])).length;
              final completed = trips.where((t) => t['status'] == 'completed').length;
              final isHi = ref.watch(localeProvider).languageCode == 'hi';
              return TtsButton(
                text: 'Read aloud',
                spokenText: isHi
                    ? 'मेरी ट्रिप। $active एक्टिव, $completed पूर्ण।'
                    : 'My Trips. $active active, $completed completed.',
                locale: isHi ? 'hi-IN' : 'en-IN',
                size: 22,
              );
            }).valueOrNull ?? const SizedBox.shrink(),
          ],
          bottom: TabBar(
            indicatorColor: AppColors.brandTeal,
            labelColor: AppColors.brandTeal,
            unselectedLabelColor: AppColors.textTertiary,
            tabs: [
              Tab(text: AppLocalizations.of(context)!.active),
              Tab(text: AppLocalizations.of(context)!.completed),
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
                  emptyTitle: AppLocalizations.of(context)!.noActiveTrips,
                  emptyDesc: AppLocalizations.of(context)!.noActiveTrips,
                  onRefresh: () => ref.invalidate(_myTripsProvider),
                ),
                _TripList(
                  trips: completed,
                  emptyTitle: AppLocalizations.of(context)!.noTripHistory,
                  emptyDesc: AppLocalizations.of(context)!.noCompletedTrips,
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

Map<String, String> _getStageLabels(AppLocalizations l10n) {
  return {
    'not_started': l10n.stageNotStarted,
    'reached_pickup': l10n.stageReachedPickup,
    'loading': l10n.stageLoading,
    'in_transit': l10n.stageInTransit,
    'reached_destination': l10n.stageReachedDestination,
    'unloading': l10n.stageUnloading,
    'delivered': l10n.stageDelivered,
  };
}

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
  final _picker = ImagePicker();

  String get _currentStage =>
      widget.trip['trip_stage'] as String? ?? 'not_started';

  int get _currentIndex => _tripStages.indexOf(_currentStage);

  bool get _isSuperLoad => widget.trip['is_super_load'] == true;

  String? get _nextStage {
    final idx = _currentIndex;
    if (idx < 0 || idx >= _tripStages.length - 1) return null;
    return _tripStages[idx + 1];
  }

  /// Check if the next stage requires a document upload gate.
  bool get _nextStageRequiresUpload {
    final next = _nextStage;
    // Gate 1: loading → in_transit requires LR (Lorry Receipt)
    if (_currentStage == 'loading' && next == 'in_transit') return true;
    // Gate 2: unloading → delivered requires POD (Proof of Delivery)
    if (_currentStage == 'unloading' && next == 'delivered') return true;
    return false;
  }

  String _getRequiredDocLabel(AppLocalizations l10n) {
    if (_currentStage == 'loading') return 'Lorry Receipt (LR / Bilty)';
    if (_currentStage == 'unloading') return 'Proof of Delivery (POD)';
    return '';
  }

  String get _requiredDocColumn {
    if (_currentStage == 'loading') return 'lr_photo_url';
    if (_currentStage == 'unloading') return 'pod_photo_url';
    return '';
  }

  Future<void> _advanceStage(AppLocalizations l10n) async {
    final next = _nextStage;
    if (next == null) return;

    // If this transition requires a document upload, show the upload gate
    if (_nextStageRequiresUpload) {
      final alreadyUploaded =
          (widget.trip[_requiredDocColumn] as String?)?.isNotEmpty == true;
      if (!alreadyUploaded) {
        final docLabel = _getRequiredDocLabel(l10n);
        final doUpload = await _showUploadGate(docLabel);
        if (doUpload != true) return; // User cancelled
        return _pickAndUploadDoc(docLabel);
      }
    }

    await _performStageAdvance(next);
  }

  Future<void> _performStageAdvance(String next) async {
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

  Future<bool?> _showUploadGate(String docLabel) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text('Upload $docLabel'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _currentStage == 'loading'
                  ? Icons.description
                  : Icons.camera_alt,
              size: 48,
              color: AppColors.brandTeal,
            ),
            const SizedBox(height: 12),
            Text(
              _currentStage == 'loading'
                  ? 'Please upload the Lorry Receipt (Bilty) photo before marking In Transit.'
                  : _isSuperLoad
                      ? 'Please upload Proof of Delivery photo. Admin will review and approve before the load is marked as completed.'
                      : 'Please upload Proof of Delivery photo before marking Delivered.',
              textAlign: TextAlign.center,
              style: AppTypography.bodyMedium,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.camera_alt, size: 18),
            label: const Text('Take Photo'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.brandTeal,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickAndUploadDoc(String docLabel) async {
    final source = await showDialog<ImageSource>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Choose source'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, ImageSource.camera),
            child: const ListTile(
              leading: Icon(Icons.camera_alt),
              title: Text('Camera'),
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, ImageSource.gallery),
            child: const ListTile(
              leading: Icon(Icons.photo_library),
              title: Text('Gallery'),
            ),
          ),
        ],
      ),
    );

    if (source == null || !mounted) return;

    final picked = await _picker.pickImage(
      source: source,
      maxWidth: 1920,
      imageQuality: 80,
    );
    if (picked == null || !mounted) return;

    setState(() => _isUpdating = true);

    try {
      final userId = ref.read(authServiceProvider).currentUser?.id;
      if (userId == null) throw Exception('Not authenticated');

      final loadId = widget.trip['id'] as String;
      final column = _requiredDocColumn;
      final fileExt = picked.path.split('.').last;
      final storagePath = '$userId/${column}_$loadId.$fileExt';

      final storage = ref.read(storageServiceProvider);
      final url = await storage.uploadFile(
        bucket: 'verification-docs',
        filePath: storagePath,
        file: File(picked.path),
      );

      // Update the load record with the uploaded URL
      final db = ref.read(databaseServiceProvider);
      await db.updateLoad(loadId, {column: url});

      // Now advance the stage
      final next = _nextStage;
      if (next != null) {
        await db.updateTripStage(loadId, next);
      }

      if (mounted) {
        final isDeliveryComplete = _currentStage != 'loading';
        AppDialogs.showSnackBar(
          context,
          _currentStage == 'loading'
              ? 'Lorry Receipt uploaded. Trip marked In Transit.'
              : _isSuperLoad
                  ? 'Delivery Photo (POD) uploaded. Awaiting admin approval.'
                  : 'Delivery Photo (POD) uploaded. Trip completed!',
        );
        // Task 5.9: Feedback prompt after trip completion
        if (isDeliveryComplete && mounted) {
          final locale = ref.read(localeProvider).languageCode;
          FeedbackPrompt.maybeShow(
            context,
            actionLabel: locale == 'hi' ? 'ट्रिप पूरी हुई' : 'Trip Completed',
            locale: locale,
          );
        }
      }
      widget.onStageUpdated();
    } catch (e) {
      if (mounted) {
        AppDialogs.showErrorSnackBar(context, e);
      }
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  Future<void> _showRatingDialog(Map<String, dynamic> trip) async {
    final db = ref.read(databaseServiceProvider);
    final userId = ref.read(authServiceProvider).currentUser?.id;
    if (userId == null) return;

    final loadId = trip['id'] as String;
    final supplierId = trip['supplier_id'] as String?;
    if (supplierId == null) {
      if (mounted) {
        AppDialogs.showSnackBar(context, 'Supplier info not available');
      }
      return;
    }

    // Check if already rated
    final alreadyRated = await db.hasRated(
      loadId: loadId,
      reviewerId: userId,
    );
    if (alreadyRated) {
      if (mounted) {
        AppDialogs.showSnackBar(context, AppLocalizations.of(context)!.alreadyRated);
      }
      return;
    }

    if (!mounted) return;

    int selectedScore = 0;
    final commentController = TextEditingController();

    final submitted = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(AppLocalizations.of(context)!.rateSupplier),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${trip['origin_city']} → ${trip['dest_city']}',
                style: AppTypography.bodyMedium
                    .copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (i) {
                  final starIndex = i + 1;
                  return IconButton(
                    onPressed: () =>
                        setDialogState(() => selectedScore = starIndex),
                    icon: Icon(
                      starIndex <= selectedScore
                          ? Icons.star
                          : Icons.star_border,
                      color: AppColors.brandOrange,
                      size: 36,
                    ),
                  );
                }),
              ),
              if (selectedScore > 0)
                Builder(builder: (_) {
                  final l10n = AppLocalizations.of(context)!;
                  final labels = ['', l10n.ratingPoor, l10n.ratingFair, l10n.ratingGood, l10n.ratingVeryGood, l10n.ratingExcellent];
                  return Text(
                    labels[selectedScore],
                    style: AppTypography.bodySmall
                        .copyWith(color: AppColors.brandOrange),
                  );
                }),
              const SizedBox(height: 12),
              TextField(
                controller: commentController,
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: AppLocalizations.of(context)!.addComment,
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: selectedScore > 0
                  ? () => Navigator.pop(ctx, true)
                  : null,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.brandOrange,
              ),
              child: Text(AppLocalizations.of(context)!.submitRating),
            ),
          ],
        ),
      ),
    );

    final commentText = commentController.text.trim();
    commentController.dispose();

    if (submitted != true || selectedScore == 0 || !mounted) return;

    try {
      await db.submitRating(
        loadId: loadId,
        reviewerId: userId,
        revieweeId: supplierId,
        reviewerRole: 'trucker',
        score: selectedScore,
        comment: commentText,
      );
      if (mounted) {
        AppDialogs.showSuccessSnackBar(context, AppLocalizations.of(context)!.ratingSubmitted);
      }
    } catch (e) {
      if (mounted) {
        AppDialogs.showErrorSnackBar(context, e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final trip = widget.trip;
    final status = trip['status'] as String? ?? 'booked';
    final l10n = AppLocalizations.of(context)!;

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
              StatusChip(
                status: status,
                role: 'trucker',
                locale: ref.watch(localeProvider).languageCode,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${trip['material']} • ${trip['weight_tonnes']} tonnes • ₹${trip['price']}/ton',
            style: AppTypography.bodySmall
                .copyWith(color: AppColors.textSecondary),
          ),

          // Task 7.4: Super Load payment breakdown
          if (trip['is_super_load'] == true) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.brandOrangeLight,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.brandOrange.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.shield, size: 14, color: AppColors.brandOrange),
                      const SizedBox(width: 4),
                      Text('TranZfort Guarantee',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.brandOrange,
                            fontWeight: FontWeight.w700,
                          )),
                    ],
                  ),
                  Builder(builder: (_) {
                    final price = (trip['price'] as num?)?.toDouble() ?? 0;
                    final weight = (trip['weight_tonnes'] as num?)?.toDouble() ?? 0;
                    final adv = (trip['advance_percentage'] as num?)?.toInt() ?? 0;
                    final termDays = trip['payment_term_days'] as int? ?? 10;
                    final total = price * weight;
                    final advAmt = (total * adv / 100).round();
                    final remaining = (total - advAmt).round();
                    return Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Advance: $adv% (\u20b9$advAmt) \u2022 Remaining: \u20b9$remaining \u2022 $termDays days after POD',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textSecondary, fontSize: 10),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],

          // Task 6.3: Inline mini-map for active trips
          Builder(builder: (_) {
            final oLat = (trip['origin_lat'] as num?)?.toDouble();
            final oLng = (trip['origin_lng'] as num?)?.toDouble();
            final dLat = (trip['dest_lat'] as num?)?.toDouble();
            final dLng = (trip['dest_lng'] as num?)?.toDouble();
            if (oLat != null && oLng != null && dLat != null && dLng != null &&
                (status == 'booked' || status == 'in_transit')) {
              return Padding(
                padding: const EdgeInsets.only(top: 10),
                child: RouteMapPreview(
                  originLat: oLat,
                  originLng: oLng,
                  destLat: dLat,
                  destLng: dLng,
                  height: 100,
                  onTap: () => context.push('/load-detail/${trip['id']}'),
                ),
              );
            }
            return const SizedBox.shrink();
          }),
          const SizedBox(height: 16),

          // Trip stage progress
          _buildStageProgress(l10n),

          // Task 5.5: Single primary CTA per status
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildPrimaryCta(context, trip, status, l10n)),
              const SizedBox(width: 8),
              _buildOverflowMenu(context, trip, status, l10n),
            ],
          ),
        ],
      ),
    );
  }

  /// Task 5.5: Single primary CTA based on trip status + stage.
  Widget _buildPrimaryCta(
    BuildContext context,
    Map<String, dynamic> trip,
    String status,
    AppLocalizations l10n,
  ) {
    final isDelivered = _currentStage == 'delivered';
    final atDestination = _currentStage == 'reached_destination' ||
        _currentStage == 'unloading';

    // completed → Rate Supplier
    if (status == 'completed' || isDelivered) {
      if (status == 'completed') {
        return FilledButton.icon(
          onPressed: () => _showRatingDialog(trip),
          icon: const Icon(Icons.star, size: 18),
          label: const Text('Rate Supplier'),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.brandOrange,
            minimumSize: const Size.fromHeight(44),
          ),
        );
      }
      // delivered → waiting for supplier confirmation
      return FilledButton.icon(
        onPressed: null,
        icon: const Icon(Icons.hourglass_top, size: 18),
        label: const Text('Waiting for supplier'),
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.textTertiary,
          disabledBackgroundColor: AppColors.textTertiary.withValues(alpha: 0.15),
          disabledForegroundColor: AppColors.textSecondary,
          minimumSize: const Size.fromHeight(44),
        ),
      );
    }

    // booked, not_started → Start Trip
    if (status == 'booked' && _currentStage == 'not_started') {
      return FilledButton.icon(
        onPressed: _isUpdating ? null : () => _advanceStage(l10n),
        icon: _isUpdating
            ? const SizedBox(width: 18, height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.local_shipping, size: 18),
        label: const Text('Start Trip'),
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.success,
          minimumSize: const Size.fromHeight(44),
        ),
      );
    }

    // in_transit, at destination → Take Delivery Photo
    if (atDestination) {
      return FilledButton.icon(
        onPressed: _isUpdating ? null : () => _advanceStage(l10n),
        icon: _isUpdating
            ? const SizedBox(width: 18, height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.camera_alt, size: 18),
        label: const Text('Take Delivery Photo (POD)'),
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.brandOrange,
          minimumSize: const Size.fromHeight(44),
        ),
      );
    }

    // in_transit (moving) → Navigate
    if (status == 'in_transit' || _currentStage == 'in_transit') {
      return FilledButton.icon(
        onPressed: () {
          final origin = trip['origin_city'] as String? ?? '';
          final dest = trip['dest_city'] as String? ?? '';
          final material = trip['material'] as String? ?? '';
          final weight = trip['weight_tonnes']?.toString() ?? '';
          context.push('/navigation', extra: {
            'origin': origin,
            'destination': dest,
            'tripId': trip['id'] as String?,
            'loadContext': '$origin → $dest | $material | ${weight}T',
          });
        },
        icon: const Icon(Icons.navigation, size: 18),
        label: const Text('Navigate'),
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.info,
          minimumSize: const Size.fromHeight(44),
        ),
      );
    }

    // Default: advance stage
    return FilledButton.icon(
      onPressed: _isUpdating ? null : () => _advanceStage(l10n),
      icon: _isUpdating
          ? const SizedBox(width: 18, height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
          : Icon(_stageIcons[_nextStage] ?? Icons.arrow_forward, size: 18),
      label: Text(
        _nextStage != null
            ? 'Mark: ${_getStageLabels(l10n)[_nextStage]}'
            : 'Up to date',
      ),
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.brandTeal,
        minimumSize: const Size.fromHeight(44),
      ),
    );
  }

  /// Task 5.5: Overflow menu with secondary actions.
  Widget _buildOverflowMenu(
    BuildContext context,
    Map<String, dynamic> trip,
    String status,
    AppLocalizations l10n,
  ) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, color: AppColors.textSecondary),
      onSelected: (value) {
        switch (value) {
          case 'navigate':
            final origin = trip['origin_city'] as String? ?? '';
            final dest = trip['dest_city'] as String? ?? '';
            final material = trip['material'] as String? ?? '';
            final weight = trip['weight_tonnes']?.toString() ?? '';
            context.push('/navigation', extra: {
              'origin': origin,
              'destination': dest,
              'tripId': trip['id'] as String?,
              'loadContext': '$origin → $dest | $material | ${weight}T',
            });
          case 'advance':
            _advanceStage(l10n);
          case 'rate':
            _showRatingDialog(trip);
          case 'details':
            final loadId = trip['id'] as String?;
            if (loadId != null) context.push('/load-detail/$loadId');
          case 'contact':
            final supplierId = trip['supplier_id'] as String?;
            if (supplierId != null) {
              final userId = ref.read(authServiceProvider).currentUser?.id;
              if (userId != null) {
                ref.read(databaseServiceProvider).getOrCreateConversation(
                  loadId: trip['id'],
                  supplierId: supplierId,
                  truckerId: userId,
                ).then((conv) {
                  if (context.mounted) context.push('/chat/${conv['id']}');
                });
              }
            }
        }
      },
      itemBuilder: (ctx) {
        final items = <PopupMenuEntry<String>>[];
        final isDelivered = _currentStage == 'delivered';

        // Navigate (if not the primary CTA)
        if (status != 'in_transit' || _currentStage != 'in_transit') {
          items.add(const PopupMenuItem(
            value: 'navigate',
            child: ListTile(
              leading: Icon(Icons.navigation, size: 20),
              title: Text('Navigate'),
              dense: true,
              contentPadding: EdgeInsets.zero,
            ),
          ));
        }

        // Advance stage (if not the primary CTA and not terminal)
        if (!isDelivered &&
            status != 'completed' &&
            _nextStage != null &&
            !(status == 'booked' && _currentStage == 'not_started')) {
          items.add(PopupMenuItem(
            value: 'advance',
            child: ListTile(
              leading: const Icon(Icons.skip_next, size: 20),
              title: Text('Mark: ${_getStageLabels(l10n)[_nextStage]}'),
              dense: true,
              contentPadding: EdgeInsets.zero,
            ),
          ));
        }

        // View Details
        items.add(const PopupMenuItem(
          value: 'details',
          child: ListTile(
            leading: Icon(Icons.info_outline, size: 20),
            title: Text('View Details'),
            dense: true,
            contentPadding: EdgeInsets.zero,
          ),
        ));

        // Contact Supplier
        items.add(const PopupMenuItem(
          value: 'contact',
          child: ListTile(
            leading: Icon(Icons.chat_bubble_outline, size: 20),
            title: Text('Contact Supplier'),
            dense: true,
            contentPadding: EdgeInsets.zero,
          ),
        ));

        // Rate (if completed and not primary)
        if (status == 'completed' || isDelivered) {
          if (status != 'completed') {
            items.add(const PopupMenuItem(
              value: 'rate',
              child: ListTile(
                leading: Icon(Icons.star_outline, size: 20),
                title: Text('Rate Supplier'),
                dense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ));
          }
        }

        return items;
      },
    );
  }

  Widget _buildStageProgress(AppLocalizations l10n) {
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
                    color: isCompleted
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

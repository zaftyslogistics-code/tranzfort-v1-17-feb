import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/providers/auth_service_provider.dart';
import '../../../../core/utils/dialogs.dart';
import '../../../../shared/widgets/app_drawer.dart';
import '../../../../shared/widgets/city_autocomplete_field.dart';
import '../../../../shared/widgets/bottom_nav_bar.dart';
import '../../../../shared/widgets/gradient_button.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../core/utils/animations.dart';
import '../../../../shared/widgets/scroll_to_top_fab.dart';
import '../../../../shared/widgets/stat_card.dart';
import '../../../../core/services/smart_defaults_service.dart';
import '../../../../shared/widgets/tts_button.dart';

class FindLoadsScreen extends ConsumerStatefulWidget {
  const FindLoadsScreen({super.key});

  @override
  ConsumerState<FindLoadsScreen> createState() => _FindLoadsScreenState();
}

class _FindLoadsScreenState extends ConsumerState<FindLoadsScreen> {
  final _fromController = TextEditingController();
  final _toController = TextEditingController();
  String _truckType = 'Any';
  bool _hasSearched = false;
  bool _isSearching = false;
  List<Map<String, dynamic>> _results = [];
  String _sortOrder = 'none';
  final _resultsScrollController = ScrollController();

  // New filters
  bool _verifiedOnly = false;
  String? _materialFilter;
  double? _minWeight;
  double? _maxWeight;

  static const _truckTypes = ['Any', 'Open', 'Container', 'Trailer', 'Tanker'];
  static const _commonMaterials = ['Any', 'Steel', 'Cement', 'Coal', 'Agriculture', 'FMCG', 'Construction', 'Containers'];
  static const _weightRanges = ['Any', '10-20T', '20-30T', '30T+'];

  @override
  void initState() {
    super.initState();
    _loadDefaults();
  }

  Future<void> _loadDefaults() async {
    final (origin, dest) = await SmartDefaults.getLastSearch();
    if (origin != null && _fromController.text.isEmpty) {
      _fromController.text = origin;
    }
    if (dest != null && _toController.text.isEmpty) {
      _toController.text = dest;
    }
  }

  @override
  void dispose() {
    _fromController.dispose();
    _toController.dispose();
    _resultsScrollController.dispose();
    super.dispose();
  }

  Future<void> _searchLoads() async {
    setState(() => _isSearching = true);
    HapticFeedback.lightImpact();

    try {
      final db = ref.read(databaseServiceProvider);
      final results = await db.getActiveLoads(
        originCity: _fromController.text.trim(),
        destCity: _toController.text.trim(),
        truckType: _truckType,
        sortOrder: _sortOrder,
        verifiedOnly: _verifiedOnly,
        materialFilter: _materialFilter,
        minWeight: _minWeight,
        maxWeight: _maxWeight,
      );

      // Save search defaults for next time
      SmartDefaults.saveLastSearch(
        _fromController.text.trim(),
        _toController.text.trim(),
      );

      setState(() {
        _results = results;
        _hasSearched = true;
      });
    } catch (e) {
      if (mounted) {
        AppDialogs.showErrorSnackBar(context, e);
      }
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  List<Map<String, dynamic>> get _filteredAndSortedResults {
    // Results are already filtered and sorted by DB query
    // Only client-side filter remaining is for cases where we need complex logic
    return _results;
  }

  String _formatTimeAgo(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr);
      final diff = DateTime.now().difference(date);
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      return '${(diff.inDays / 7).floor()}w ago';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: const Text('Find Loads'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () => context.push('/messages'),
          ),
        ],
      ),
      bottomNavigationBar: const BottomNavBar(currentRole: 'trucker'),
      floatingActionButton: _hasSearched
          ? ScrollToTopFab(scrollController: _resultsScrollController)
          : null,
      body: _hasSearched ? _buildResults() : _buildPreSearch(),
    );
  }

  Widget _buildPreSearch() {
    final activeTripsAsync = ref.watch(truckerActiveTripsCountProvider);
    final totalTripsAsync = ref.watch(truckerTotalTripsProvider);

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(AppSpacing.screenPaddingH),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Find loads for\nyour return trip.',
              style: AppTypography.h1Hero),
          const SizedBox(height: 24),

          // Quick stats
          Row(
            children: [
              Expanded(
                child: StatCard(
                  icon: Icons.assignment,
                  value: '${activeTripsAsync.valueOrNull ?? 0}',
                  label: 'Active Trips',
                  onTap: () => context.go('/my-trips'),
                ),
              ),
              const SizedBox(width: AppSpacing.cardGap),
              Expanded(
                child: StatCard(
                  icon: Icons.check_circle,
                  value: '${totalTripsAsync.valueOrNull ?? 0}',
                  label: 'Total Trips',
                  iconColor: AppColors.success,
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),

          // Search form
          Container(
            padding: const EdgeInsets.all(AppSpacing.cardPadding),
            decoration: BoxDecoration(
              color: AppColors.cardBg,
              borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
              boxShadow: AppColors.cardShadow,
            ),
            child: Column(
              children: [
                CityAutocompleteField(
                  controller: _fromController,
                  labelText: 'From City',
                  prefixIcon: Icons.location_on_outlined,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 12),
                CityAutocompleteField(
                  controller: _toController,
                  labelText: 'To City',
                  prefixIcon: Icons.flag_outlined,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _truckType,
                  decoration: const InputDecoration(
                    labelText: 'Truck Type (Optional)',
                  ),
                  items: _truckTypes
                      .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                      .toList(),
                  onChanged: (v) => setState(() => _truckType = v!),
                ),
                const SizedBox(height: 16),
                GradientButton(
                  text: 'Search Loads',
                  isLoading: _isSearching,
                  onPressed: _isSearching ? null : _searchLoads,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Quick links
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => context.go('/my-trips'),
                  icon: const Icon(Icons.assignment, size: 18),
                  label: const Text('My Trips'),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.brandTeal),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => context.go('/my-fleet'),
                  icon: const Icon(Icons.local_shipping, size: 18),
                  label: const Text('My Fleet'),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.brandTeal),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildResults() {
    final sorted = _filteredAndSortedResults;
    final hasActiveFilters = _verifiedOnly || _materialFilter != null || _minWeight != null || _maxWeight != null;

    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.screenPaddingH,
            vertical: 12,
          ),
          color: AppColors.cardBg,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '${_fromController.text} → ${_toController.text}',
                  style: AppTypography.h3Subsection,
                ),
              ),
              if (hasActiveFilters)
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.brandTeal,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Filters On',
                    style: AppTypography.caption.copyWith(color: Colors.white),
                  ),
                ),
              IconButton(
                icon: const Icon(Icons.close, size: 20),
                onPressed: () => setState(() {
                  _hasSearched = false;
                  _clearFilters();
                }),
              ),
            ],
          ),
        ),

        // Filter chips
        SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              // Verified supplier toggle
              _filterChip(
                'Verified Only',
                _verifiedOnly,
                () => setState(() => _verifiedOnly = !_verifiedOnly),
              ),
              const SizedBox(width: 8),
              // Material filters
              ..._commonMaterials.where((m) => m != 'Any').map((material) {
                final isSelected = _materialFilter == material;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _filterChip(
                    material,
                    isSelected,
                    () => setState(() => _materialFilter = isSelected ? null : material),
                  ),
                );
              }),
            ],
          ),
        ),

        // Weight range chips
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              ..._weightRanges.map((range) {
                final isSelected = _getWeightRangeLabel() == range && range != 'Any';
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(range),
                    selected: isSelected,
                    onSelected: (selected) => _applyWeightFilter(selected ? range : 'Any'),
                    selectedColor: AppColors.brandTeal,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : AppColors.textPrimary,
                      fontSize: 12,
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: 4),

        // Sort chips
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              _filterChip(
                'Price ↑',
                _sortOrder == 'price_high',
                () => setState(() => _sortOrder =
                    _sortOrder == 'price_high' ? 'none' : 'price_high'),
              ),
              const SizedBox(width: 8),
              _filterChip(
                'Price ↓',
                _sortOrder == 'price_low',
                () => setState(() => _sortOrder =
                    _sortOrder == 'price_low' ? 'none' : 'price_low'),
              ),
              if (hasActiveFilters) ...[
                const SizedBox(width: 16),
                ActionChip(
                  label: const Text('Clear All'),
                  onPressed: _clearFilters,
                  backgroundColor: AppColors.errorLight,
                  labelStyle: const TextStyle(color: AppColors.error, fontSize: 12),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 8),

        // Results
        Expanded(
          child: sorted.isEmpty
              ? EmptyState(
                  icon: Icons.search_off,
                  title: 'No loads found',
                  description: hasActiveFilters
                      ? 'Try adjusting your filters or search criteria'
                      : 'Try a different route or truck type',
                  actionLabel: hasActiveFilters ? 'Clear Filters' : 'New Search',
                  onAction: () => hasActiveFilters
                      ? _clearFilters()
                      : setState(() => _hasSearched = false),
                )
              : RefreshIndicator(
                  color: AppColors.brandTeal,
                  onRefresh: _searchLoads,
                  child: ListView.builder(
                    controller: _resultsScrollController,
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    padding: const EdgeInsets.all(AppSpacing.screenPaddingH),
                    itemCount: sorted.length,
                    itemBuilder: (context, index) {
                      return _LoadCard(
                        load: sorted[index],
                        timeAgo: _formatTimeAgo(
                            sorted[index]['created_at'] as String?),
                      ).staggerEntrance(index);
                    },
                  ),
                ),
        ),
      ],
    );
  }

  String? _getWeightRangeLabel() {
    if (_minWeight == null && _maxWeight == null) return 'Any';
    if (_minWeight == 10 && _maxWeight == 20) return '10-20T';
    if (_minWeight == 20 && _maxWeight == 30) return '20-30T';
    if (_minWeight == 30 && _maxWeight == null) return '30T+';
    return null;
  }

  void _applyWeightFilter(String range) {
    setState(() {
      switch (range) {
        case '10-20T':
          _minWeight = 10;
          _maxWeight = 20;
          break;
        case '20-30T':
          _minWeight = 20;
          _maxWeight = 30;
          break;
        case '30T+':
          _minWeight = 30;
          _maxWeight = null;
          break;
        default:
          _minWeight = null;
          _maxWeight = null;
      }
    });
  }

  void _clearFilters() {
    setState(() {
      _verifiedOnly = false;
      _materialFilter = null;
      _minWeight = null;
      _maxWeight = null;
      _sortOrder = 'none';
    });
  }

  Widget _filterChip(String label, bool selected, VoidCallback onTap) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: AppColors.brandTeal,
      labelStyle: TextStyle(
        color: selected ? Colors.white : AppColors.textPrimary,
        fontSize: 13,
      ),
    );
  }
}

class _LoadCard extends ConsumerWidget {
  final Map<String, dynamic> load;
  final String timeAgo;

  const _LoadCard({required this.load, required this.timeAgo});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSuperLoad = load['is_super_load'] as bool? ?? false;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.cardGap),
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        boxShadow: isSuperLoad ? AppColors.superLoadGlow : AppColors.cardShadow,
        border: isSuperLoad
            ? Border.all(color: AppColors.brandOrange, width: 1.5)
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isSuperLoad)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.brandOrangeLight,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.star, size: 14, color: AppColors.brandOrange),
                  const SizedBox(width: 4),
                  Text(
                    'SUPER LOAD',
                    style: AppTypography.overline
                        .copyWith(color: AppColors.brandOrange),
                  ),
                ],
              ),
            ),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${load['origin_city']} → ${load['dest_city']}',
                  style: AppTypography.h3Subsection,
                ),
              ),
              TtsButton(
                text: 'Load from ${load['origin_city']} to ${load['dest_city']}. '
                    '${load['material']}, ${load['weight_tonnes']} tonnes. '
                    'Price ${load['price']} rupees per ton.',
                size: 18,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.brandTealLight,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(load['material'] ?? '',
                    style: AppTypography.caption
                        .copyWith(color: AppColors.brandTeal)),
              ),
              const SizedBox(width: 8),
              Text('${load['weight_tonnes']} tonnes',
                  style: AppTypography.bodySmall),
              const Spacer(),
              Text('₹${load['price']}/ton',
                  style: AppTypography.number.copyWith(fontSize: 16)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              if (timeAgo.isNotEmpty)
                Text('Posted $timeAgo',
                    style: AppTypography.caption
                        .copyWith(color: AppColors.textTertiary)),
              const Spacer(),
              SizedBox(
                height: 36,
                child: GradientButton(
                  text: 'Chat Now',
                  height: 36,
                  width: 110,
                  onPressed: () async {
                    HapticFeedback.lightImpact();

                    // Fresh-fetch verification status from DB (not cached provider)
                    final authService = ref.read(authServiceProvider);
                    final db = ref.read(databaseServiceProvider);
                    final userId = authService.currentUser!.id;

                    final freshProfile = await db.getPublicProfile(userId);
                    final verStatus =
                        freshProfile?['verification_status'] as String? ??
                            'unverified';

                    if (verStatus != 'verified') {
                      if (context.mounted) _showVerifySheet(context);
                      return;
                    }

                    // Update cached provider so drawer stays in sync
                    ref.invalidate(userProfileProvider);

                    try {
                      final conv = await db.getOrCreateConversation(
                        loadId: load['id'],
                        supplierId: load['supplier_id'],
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
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showVerifySheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.verified_user_outlined,
                size: 48, color: AppColors.brandTeal),
            const SizedBox(height: 16),
            Text('Verify Profile to Chat',
                style: AppTypography.h3Subsection),
            const SizedBox(height: 8),
            Text(
              'Complete your verification to start chatting with suppliers.',
              textAlign: TextAlign.center,
              style: AppTypography.bodyMedium
                  .copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
            GradientButton(
              text: 'Verify Now',
              onPressed: () {
                Navigator.pop(ctx);
                context.push('/trucker-verification');
              },
            ),
          ],
        ),
      ),
    );
  }
}

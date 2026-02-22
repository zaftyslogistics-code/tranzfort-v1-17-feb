import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tranzfort/l10n/app_localizations.dart';
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
import '../../../../core/constants/load_constants.dart';
import '../../../../core/services/smart_defaults_service.dart';
import '../../../../core/providers/locale_provider.dart';
import '../../../../shared/widgets/tts_button.dart';
import '../../../../shared/widgets/language_toggle_button.dart';

class FindLoadsScreen extends ConsumerStatefulWidget {
  final String? initialOrigin;
  final String? initialDestination;
  final bool autoSearch;

  const FindLoadsScreen({
    super.key,
    this.initialOrigin,
    this.initialDestination,
    this.autoSearch = false,
  });

  @override
  ConsumerState<FindLoadsScreen> createState() => _FindLoadsScreenState();
}

class _FindLoadsScreenState extends ConsumerState<FindLoadsScreen> {
  final _fromController = TextEditingController();
  final _toController = TextEditingController();
  String _truckType = 'Any';
  bool _isSearching = false;
  List<Map<String, dynamic>> _results = [];
  String _sortOrder = 'none';
  final _resultsScrollController = ScrollController();
  int _currentPage = 0;
  bool _hasMorePages = true;
  bool _isLoadingMore = false;

  // New filters
  bool _verifiedOnly = false;
  String? _materialFilter;
  double? _minWeight;
  double? _maxWeight;
  bool _showSearchBar = false;
  bool _initialLoadDone = false;
  List<Map<String, dynamic>> _myTrucks = []; // TRK-1: for match indicator
  Set<String> _bookmarkedIds = {}; // TRK-2: saved loads
  bool _truckMatchOnly = false; // P0-6: My Truck Match filter
  String? _pickupDateFilter; // P1-8: pickup date filter
  double? _minPrice; // P1-9: price range filter
  double? _maxPrice;

  static const _truckTypes = ['Any', 'Open', 'Container', 'Trailer', 'Tanker'];
  static final _commonMaterials = LoadConstants.filterMaterials; // P0-5: smart categories
  static const _weightRanges = ['Any', '0-10T', '10-20T', '20-30T', '30T+']; // P0-7: added 0-10T
  static const _priceRanges = ['Any', '₹0-1500', '₹1500-2500', '₹2500-4000', '₹4000+'];
  static const _dateFilters = ['Any', 'Today', 'Tomorrow', 'This Week'];

  @override
  void initState() {
    super.initState();
    _loadInitialState();
    _loadMyTrucks();
    _loadBookmarks();
    _resultsScrollController.addListener(_onScroll);
  }

  Future<void> _loadBookmarks() async {
    final ids = await SmartDefaults.getBookmarkedLoadIds();
    if (mounted) setState(() => _bookmarkedIds = ids.toSet());
  }

  Future<void> _toggleBookmark(String loadId) async {
    await SmartDefaults.toggleBookmark(loadId);
    setState(() {
      if (_bookmarkedIds.contains(loadId)) {
        _bookmarkedIds.remove(loadId);
      } else {
        _bookmarkedIds.add(loadId);
      }
    });
  }

  Future<void> _loadMyTrucks() async {
    final userId = ref.read(authServiceProvider).currentUser?.id;
    if (userId == null) return;
    try {
      final trucks = await ref.read(databaseServiceProvider).getMyTrucks(userId);
      if (mounted) setState(() => _myTrucks = trucks);
    } catch (_) {}
  }

  bool _truckMatchesLoad(Map<String, dynamic> load) {
    if (_myTrucks.isEmpty) return false;
    final reqType = (load['required_truck_type'] as String?)?.toLowerCase();
    final reqTyres = load['required_tyres'];
    for (final truck in _myTrucks) {
      final truckType = (truck['body_type'] as String?)?.toLowerCase();
      final truckTyres = truck['tyres'];
      final typeMatch = reqType == null || reqType.isEmpty || truckType == reqType;
      final tyreMatch = reqTyres == null ||
          (reqTyres is List && reqTyres.isEmpty) ||
          (truckTyres != null && reqTyres is List && reqTyres.contains(truckTyres));
      if (typeMatch && tyreMatch) return true;
    }
    return false;
  }

  Future<void> _loadInitialState() async {
    final (origin, dest) = await SmartDefaults.getLastSearch();
    if (!mounted) return;

    final initialOrigin = widget.initialOrigin?.trim();
    final initialDestination = widget.initialDestination?.trim();

    setState(() {
      _fromController.text =
          (initialOrigin != null && initialOrigin.isNotEmpty)
              ? initialOrigin
              : (origin ?? _fromController.text);
      _toController.text =
          (initialDestination != null && initialDestination.isNotEmpty)
              ? initialDestination
              : (dest ?? _toController.text);
    });

    // Always fetch loads on screen open — truckers see all loads by default
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _searchLoads();
    });
  }

  void _onScroll() {
    if (_resultsScrollController.position.pixels >=
            _resultsScrollController.position.maxScrollExtent - 200 &&
        !_isLoadingMore &&
        _hasMorePages) {
      _loadMoreResults();
    }
  }

  Future<void> _loadMoreResults() async {
    if (_isLoadingMore || !_hasMorePages) return;
    setState(() => _isLoadingMore = true);

    try {
      final db = ref.read(databaseServiceProvider);
      final nextPage = _currentPage + 1;

      List<String>? materialList;
      if (_materialFilter != null && _materialFilter != 'Any') {
        materialList = LoadConstants.categoryMaterialMap[_materialFilter!];
      }

      final moreResults = await db.getActiveLoads(
        originCity: _fromController.text.trim(),
        destCity: _toController.text.trim(),
        truckType: _truckType,
        sortOrder: _sortOrder,
        verifiedOnly: _verifiedOnly,
        materialList: materialList,
        minWeight: _minWeight,
        maxWeight: _maxWeight,
        pickupDateFrom: _getPickupDateFrom(),
        minPrice: _minPrice,
        maxPrice: _maxPrice,
        page: nextPage,
      );

      setState(() {
        _currentPage = nextPage;
        _results.addAll(moreResults);
        _hasMorePages = moreResults.length >= 50;
      });
    } catch (_) {
      // Silently fail on pagination errors
    } finally {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  @override
  void dispose() {
    _fromController.dispose();
    _toController.dispose();
    _resultsScrollController.removeListener(_onScroll);
    _resultsScrollController.dispose();
    super.dispose();
  }

  Future<void> _searchLoads() async {
    setState(() => _isSearching = true);
    HapticFeedback.lightImpact();

    try {
      final db = ref.read(databaseServiceProvider);

      // P0-5: Resolve category filter to material list
      List<String>? materialList;
      if (_materialFilter != null && _materialFilter != 'Any') {
        materialList = LoadConstants.categoryMaterialMap[_materialFilter!];
      }

      final results = await db.getActiveLoads(
        originCity: _fromController.text.trim(),
        destCity: _toController.text.trim(),
        truckType: _truckType,
        sortOrder: _sortOrder,
        verifiedOnly: _verifiedOnly,
        materialList: materialList,
        minWeight: _minWeight,
        maxWeight: _maxWeight,
        pickupDateFrom: _getPickupDateFrom(),
        minPrice: _minPrice,
        maxPrice: _maxPrice,
      );

      // Save search defaults for next time
      SmartDefaults.saveLastSearch(
        _fromController.text.trim(),
        _toController.text.trim(),
      );

      setState(() {
        _results = results;
        _currentPage = 0;
        _hasMorePages = results.length >= 50;
        _initialLoadDone = true;
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
    // P0-6: Apply truck match filter client-side
    var filtered = _results;
    if (_truckMatchOnly && _myTrucks.isNotEmpty) {
      filtered = filtered.where((load) => _truckMatchesLoad(load)).toList();
    }
    // Phase 3E: Super Loads always on top
    filtered.sort((a, b) {
      final aSuper = a['is_super_load'] == true ? 0 : 1;
      final bSuper = b['is_super_load'] == true ? 0 : 1;
      if (aSuper != bSuper) return aSuper.compareTo(bSuper);
      return 0; // preserve DB sort order within same tier
    });
    return filtered;
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

  bool get _hasActiveFilters =>
      _verifiedOnly ||
      _truckMatchOnly ||
      _materialFilter != null ||
      _minWeight != null ||
      _maxWeight != null ||
      _pickupDateFilter != null ||
      _minPrice != null ||
      _maxPrice != null ||
      _fromController.text.trim().isNotEmpty ||
      _toController.text.trim().isNotEmpty ||
      _truckType != 'Any';

  @override
  Widget build(BuildContext context) {
    final sorted = _filteredAndSortedResults;

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.findLoads),
        actions: [
          TtsButton(
            text: 'Read aloud',
            spokenText: ref.watch(localeProvider).languageCode == 'hi'
                ? 'लोढ ढूंढें। ऑरिजिन से डेस्टिनेशन तक लोड खोजें। फिल्टर लगाकर सही ट्रक ढूंढें।'
                : 'Find loads. Search loads from origin to destination. Apply filters to find the right truck.',
            locale: ref.watch(localeProvider).languageCode == 'hi' ? 'hi-IN' : 'en-IN',
            size: 22,
          ),
          // Search toggle
          IconButton(
            icon: Icon(
              _showSearchBar ? Icons.search_off : Icons.search,
              color: _showSearchBar ? AppColors.brandTeal : null,
            ),
            onPressed: () => setState(() => _showSearchBar = !_showSearchBar),
            tooltip: AppLocalizations.of(context)!.search,
          ),
          const LanguageToggleButton(),
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () => context.push('/messages'),
          ),
        ],
      ),
      bottomNavigationBar: const BottomNavBar(currentRole: 'trucker'),
      floatingActionButton: ScrollToTopFab(scrollController: _resultsScrollController),
      body: Column(
        children: [
          // Task 5.1: Stats ribbon (trucker home)
          _StatsRibbon(),

          // Collapsible search bar
          if (_showSearchBar)
            Container(
              padding: const EdgeInsets.all(12),
              color: AppColors.cardBg,
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: CityAutocompleteField(
                          controller: _fromController,
                          labelText: AppLocalizations.of(context)!.originCity,
                          prefixIcon: Icons.location_on_outlined,
                          textInputAction: TextInputAction.next,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: CityAutocompleteField(
                          controller: _toController,
                          labelText: AppLocalizations.of(context)!.destinationCity,
                          prefixIcon: Icons.flag_outlined,
                          textInputAction: TextInputAction.next,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _truckType,
                          decoration: InputDecoration(
                            labelText: AppLocalizations.of(context)!.truckType,
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          ),
                          items: _truckTypes
                              .map((t) =>
                                  DropdownMenuItem(value: t, child: Text(t)))
                              .toList(),
                          onChanged: (v) => setState(() => _truckType = v!),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        height: 44,
                        child: GradientButton(
                          text: AppLocalizations.of(context)!.search,
                          isLoading: _isSearching,
                          onPressed: _isSearching ? null : _searchLoads,
                          width: 100,
                          height: 44,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

          // Filter chips row
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              children: [
                // P0-6: My Truck Match filter
                if (_myTrucks.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _filterChip(
                      '🚛 My Truck',
                      _truckMatchOnly,
                      () {
                        setState(() => _truckMatchOnly = !_truckMatchOnly);
                      },
                    ),
                  ),
                _filterChip(
                  AppLocalizations.of(context)!.verified,
                  _verifiedOnly,
                  () {
                    setState(() => _verifiedOnly = !_verifiedOnly);
                    _searchLoads();
                  },
                ),
                const SizedBox(width: 8),
                ..._commonMaterials.where((m) => m != 'Any').map((material) {
                  final isSelected = _materialFilter == material;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _filterChip(
                      material,
                      isSelected,
                      () {
                        setState(() =>
                            _materialFilter = isSelected ? null : material);
                        _searchLoads();
                      },
                    ),
                  );
                }),
              ],
            ),
          ),

          // Weight + sort + clear row
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                ..._weightRanges.where((r) => r != 'Any').map((range) {
                  final isSelected =
                      _getWeightRangeLabel() == range;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(range),
                      selected: isSelected,
                      onSelected: (selected) {
                        _applyWeightFilter(selected ? range : 'Any');
                        _searchLoads();
                      },
                      selectedColor: AppColors.brandTeal,
                      labelStyle: TextStyle(
                        color:
                            isSelected ? Colors.white : AppColors.textPrimary,
                        fontSize: 12,
                      ),
                    ),
                  );
                }),
                const SizedBox(width: 4),
                _filterChip(
                  'Price ↑',
                  _sortOrder == 'price_high',
                  () {
                    setState(() => _sortOrder =
                        _sortOrder == 'price_high' ? 'none' : 'price_high');
                    _searchLoads();
                  },
                ),
                const SizedBox(width: 8),
                _filterChip(
                  'Price ↓',
                  _sortOrder == 'price_low',
                  () {
                    setState(() => _sortOrder =
                        _sortOrder == 'price_low' ? 'none' : 'price_low');
                    _searchLoads();
                  },
                ),
                if (_hasActiveFilters) ...[
                  const SizedBox(width: 12),
                  ActionChip(
                    label: Text(AppLocalizations.of(context)!.clear),
                    onPressed: () {
                      _fromController.clear();
                      _toController.clear();
                      _truckType = 'Any';
                      _clearFilters();
                      _searchLoads();
                    },
                    backgroundColor: AppColors.errorLight,
                    labelStyle:
                        const TextStyle(color: AppColors.error, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),

          // P1-8: Pickup date + P1-9: Price range filter row
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                ..._dateFilters.where((d) => d != 'Any').map((label) {
                  final isSelected = _pickupDateFilter == label;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(label),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() => _pickupDateFilter = selected ? label : null);
                        _searchLoads();
                      },
                      selectedColor: AppColors.brandTeal,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : AppColors.textPrimary,
                        fontSize: 12,
                      ),
                    ),
                  );
                }),
                const SizedBox(width: 4),
                ..._priceRanges.where((p) => p != 'Any').map((range) {
                  final isSelected = _getPriceRangeLabel() == range;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(range),
                      selected: isSelected,
                      onSelected: (selected) {
                        _applyPriceFilter(selected ? range : 'Any');
                        _searchLoads();
                      },
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

          // Result count + loading indicator
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                if (_isSearching)
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.brandTeal,
                    ),
                  ),
                if (_isSearching) const SizedBox(width: 8),
                Text(
                  _initialLoadDone
                      ? '${sorted.length} load${sorted.length == 1 ? '' : 's'} available'
                      : 'Loading...',
                  style: AppTypography.caption
                      .copyWith(color: AppColors.textSecondary),
                ),
                const Spacer(),
                // P2-9: Save search button
                if (_initialLoadDone &&
                    (_fromController.text.trim().isNotEmpty ||
                        _toController.text.trim().isNotEmpty))
                  GestureDetector(
                    onTap: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      await SmartDefaults.saveSearchPreset(
                        origin: _fromController.text.trim(),
                        dest: _toController.text.trim(),
                        truckType: _truckType,
                        material: _materialFilter,
                      );
                      if (mounted) {
                        messenger
                          ..hideCurrentSnackBar()
                          ..showSnackBar(const SnackBar(
                            content: Text('Search saved!'),
                            duration: Duration(seconds: 1),
                          ));
                      }
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.bookmark_add_outlined,
                            size: 16, color: AppColors.brandTeal),
                        const SizedBox(width: 4),
                        Text('Save',
                            style: AppTypography.caption
                                .copyWith(color: AppColors.brandTeal)),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          // Load list
          Expanded(
            child: !_initialLoadDone
                ? const Center(
                    child: CircularProgressIndicator(
                        color: AppColors.brandTeal),
                  )
                : sorted.isEmpty
                    ? _buildEmptyState(context)
                    : RefreshIndicator(
                        color: AppColors.brandTeal,
                        onRefresh: _searchLoads,
                        child: ListView.builder(
                          controller: _resultsScrollController,
                          physics: const AlwaysScrollableScrollPhysics(
                            parent: BouncingScrollPhysics(),
                          ),
                          padding:
                              const EdgeInsets.all(AppSpacing.screenPaddingH),
                          itemCount: sorted.length,
                          itemBuilder: (context, index) {
                            final loadId = sorted[index]['id'] as String? ?? '';
                            return _LoadCard(
                              load: sorted[index],
                              timeAgo: _formatTimeAgo(
                                  sorted[index]['created_at'] as String?),
                              isMatch: _truckMatchesLoad(sorted[index]),
                              isBookmarked: _bookmarkedIds.contains(loadId),
                              onToggleBookmark: () => _toggleBookmark(loadId),
                            ).staggerEntrance(index);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  String? _getWeightRangeLabel() {
    if (_minWeight == null && _maxWeight == null) return 'Any';
    if (_minWeight == 0 && _maxWeight == 10) return '0-10T';
    if (_minWeight == 10 && _maxWeight == 20) return '10-20T';
    if (_minWeight == 20 && _maxWeight == 30) return '20-30T';
    if (_minWeight == 30 && _maxWeight == null) return '30T+';
    return null;
  }

  void _applyWeightFilter(String range) {
    setState(() {
      switch (range) {
        case '0-10T':
          _minWeight = 0;
          _maxWeight = 10;
          break;
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
      _truckMatchOnly = false;
      _materialFilter = null;
      _minWeight = null;
      _maxWeight = null;
      _pickupDateFilter = null;
      _minPrice = null;
      _maxPrice = null;
      _sortOrder = 'none';
    });
  }

  // P1-8: Convert date filter label to ISO date string for DB query
  String? _getPickupDateFrom() {
    if (_pickupDateFilter == null) return null;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    switch (_pickupDateFilter) {
      case 'Today':
        return today.toIso8601String().split('T').first;
      case 'Tomorrow':
        return today.add(const Duration(days: 1)).toIso8601String().split('T').first;
      case 'This Week':
        return today.toIso8601String().split('T').first;
      default:
        return null;
    }
  }

  // P1-9: Price range helpers
  String? _getPriceRangeLabel() {
    if (_minPrice == null && _maxPrice == null) return 'Any';
    if (_minPrice == 0 && _maxPrice == 1500) return '₹0-1500';
    if (_minPrice == 1500 && _maxPrice == 2500) return '₹1500-2500';
    if (_minPrice == 2500 && _maxPrice == 4000) return '₹2500-4000';
    if (_minPrice == 4000 && _maxPrice == null) return '₹4000+';
    return null;
  }

  void _applyPriceFilter(String range) {
    setState(() {
      switch (range) {
        case '₹0-1500':
          _minPrice = 0;
          _maxPrice = 1500;
          break;
        case '₹1500-2500':
          _minPrice = 1500;
          _maxPrice = 2500;
          break;
        case '₹2500-4000':
          _minPrice = 2500;
          _maxPrice = 4000;
          break;
        case '₹4000+':
          _minPrice = 4000;
          _maxPrice = null;
          break;
        default:
          _minPrice = null;
          _maxPrice = null;
      }
    });
  }

  // P2-9: Empty state with saved search presets
  Widget _buildEmptyState(BuildContext context) {
    if (_hasActiveFilters) {
      return EmptyState(
        icon: Icons.search_off,
        title: AppLocalizations.of(context)!.noLoadsFound,
        description: 'Try removing some filters to see more results.',
        actionLabel: AppLocalizations.of(context)!.clear,
        onAction: () {
          _fromController.clear();
          _toController.clear();
          _truckType = 'Any';
          _clearFilters();
          _searchLoads();
        },
      );
    }
    return FutureBuilder<List<Map<String, String>>>(
      future: SmartDefaults.getSavedSearchPresets(),
      builder: (context, snapshot) {
        final presets = snapshot.data ?? [];
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const SizedBox(height: 32),
              Icon(Icons.search_off, size: 48, color: AppColors.textTertiary),
              const SizedBox(height: 12),
              Text(
                AppLocalizations.of(context)!.noLoadsFound,
                style: AppTypography.h3Subsection,
              ),
              const SizedBox(height: 4),
              Text(
                'No active loads available right now.',
                style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
              ),
              if (presets.isNotEmpty) ...[
                const SizedBox(height: 24),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Saved Searches',
                    style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(height: 8),
                ...presets.map((preset) {
                  final origin = preset['origin'] ?? '';
                  final dest = preset['dest'] ?? '';
                  final label = [
                    if (origin.isNotEmpty) origin,
                    if (dest.isNotEmpty) dest,
                  ].join(' → ');
                  return ListTile(
                    dense: true,
                    leading: const Icon(Icons.bookmark, color: AppColors.brandTeal, size: 20),
                    title: Text(label, style: AppTypography.bodyMedium),
                    subtitle: [
                      if (preset['truck_type'] != null) preset['truck_type']!,
                      if (preset['material'] != null) preset['material']!,
                    ].isNotEmpty
                        ? Text(
                            [
                              if (preset['truck_type'] != null) preset['truck_type']!,
                              if (preset['material'] != null) preset['material']!,
                            ].join(' • '),
                            style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
                          )
                        : null,
                    trailing: IconButton(
                      icon: const Icon(Icons.close, size: 16),
                      onPressed: () async {
                        await SmartDefaults.removeSavedSearch(origin, dest);
                        setState(() {}); // rebuild
                      },
                    ),
                    onTap: () {
                      _fromController.text = origin;
                      _toController.text = dest;
                      if (preset['truck_type'] != null) {
                        setState(() => _truckType = preset['truck_type']!);
                      }
                      if (preset['material'] != null) {
                        setState(() => _materialFilter = preset['material']);
                      }
                      _searchLoads();
                    },
                  );
                }),
              ],
            ],
          ),
        );
      },
    );
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
  final bool isMatch;
  final bool isBookmarked;
  final VoidCallback? onToggleBookmark;

  const _LoadCard({
    required this.load,
    required this.timeAgo,
    this.isMatch = false,
    this.isBookmarked = false,
    this.onToggleBookmark,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSuperLoad = load['is_super_load'] as bool? ?? false;

    final loadId = load['id'] as String? ?? '';

    return GestureDetector(
      onTap: loadId.isNotEmpty
          ? () => context.push('/load-detail/$loadId')
          : null,
      child: Container(
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
          Row(
            children: [
              if (isSuperLoad)
                Container(
                  margin: const EdgeInsets.only(bottom: 8, right: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFFA726), Color(0xFFFF8F00)],
                    ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.verified, size: 14, color: Colors.white),
                      const SizedBox(width: 4),
                      Text(
                        'SUPER LOAD — PAYMENT GUARANTEED',
                        style: AppTypography.overline
                            .copyWith(color: Colors.white, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              if (isMatch)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.successLight,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check_circle, size: 14, color: AppColors.success),
                      const SizedBox(width: 4),
                      Text(
                        'TRUCK MATCH',
                        style: AppTypography.overline
                            .copyWith(color: AppColors.success),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ],
                  ),
                ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${load['origin_city']} → ${load['dest_city']}',
                  style: AppTypography.h3Subsection,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              GestureDetector(
                onTap: onToggleBookmark,
                child: Icon(
                  isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                  size: 20,
                  color: isBookmarked
                      ? AppColors.brandOrange
                      : AppColors.textTertiary,
                ),
              ),
              const SizedBox(width: 4),
              TtsButton(
                text: 'Read aloud',
                spokenText: () {
                  final isHi = ref.read(localeProvider).languageCode == 'hi';
                  final truck = load['required_truck_type'] as String? ?? '';
                  final tyres = (load['required_tyres'] as List?)?.join(' and ') ?? '';
                  final pickup = load['pickup_date'] as String? ?? '';
                  final priceType = load['price_type'] as String? ?? 'negotiable';
                  if (isHi) {
                    return '${load['origin_city']} से ${load['dest_city']}। '
                        '${load['material']}, ${load['weight_tonnes']} टन। '
                        'रेट ${load['price']} रुपये प्रति टन, ${priceType == 'fixed' ? 'पक्का रेट' : 'बातचीत योग्य'}। '
                        '${truck.isNotEmpty ? 'ट्रक: $truck। ' : ''}'
                        '${tyres.isNotEmpty ? 'टायर: $tyres पहिया। ' : ''}'
                        '${pickup.isNotEmpty ? 'उठान: $pickup।' : ''}';
                  }
                  return 'Load from ${load['origin_city']} to ${load['dest_city']}. '
                      '${load['material']}, ${load['weight_tonnes']} tonnes. '
                      'Price ${load['price']} rupees per tonne, ${priceType == 'fixed' ? 'fixed rate' : 'negotiable'}. '
                      '${truck.isNotEmpty ? 'Truck: $truck. ' : ''}'
                      '${tyres.isNotEmpty ? 'Tyres: $tyres wheel. ' : ''}'
                      '${pickup.isNotEmpty ? 'Pickup: $pickup.' : ''}';
                }(),
                size: 18,
                locale: ref.read(localeProvider).languageCode == 'hi' ? 'hi-IN' : 'en-IN',
              ),
            ],
          ),
          // Phase 8: Show route distance if available
          if (load['route_distance_km'] != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  const Icon(Icons.route, size: 14, color: AppColors.brandTeal),
                  const SizedBox(width: 4),
                  Text(
                    '${(load['route_distance_km'] as num).round()} km'
                    '${load['route_duration_min'] != null ? ' \u2022 ~${((load['route_duration_min'] as num).toDouble() / 60).toStringAsFixed(1)} hrs' : ''}',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.brandTeal,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(_materialIcon(load['material'] as String? ?? ''),
                  size: 16, color: AppColors.brandTeal),
              const SizedBox(width: 4),
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('₹${load['price']}/ton',
                      style: AppTypography.number.copyWith(fontSize: 16)),
                  if (load['advance_percentage'] != null)
                    Text(
                      '${load['advance_percentage']}% advance',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.success,
                        fontWeight: FontWeight.w600,
                        fontSize: 10,
                      ),
                    ),
                ],
              ),
            ],
          ),
          // Phase 3B: Trip cost estimation
          Builder(builder: (_) {
            final price = (load['price'] as num?)?.toDouble();
            final weight = (load['weight_tonnes'] as num?)?.toDouble();
            if (price != null && weight != null && weight > 0) {
              final tripCost = (price * weight).round();
              final formatted = tripCost >= 100000
                  ? '₹${(tripCost / 100000).toStringAsFixed(1)}L'
                  : '₹${tripCost.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},')}';
              return Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    Icon(Icons.account_balance_wallet_outlined, size: 14, color: AppColors.success),
                    const SizedBox(width: 4),
                    Text(
                      '$formatted total trip value',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.success,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              );
            }
            return const SizedBox.shrink();
          }),
          // LC-1 to LC-4: Truck type, tyres, pickup date, price type
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              if (load['required_truck_type'] != null &&
                  (load['required_truck_type'] as String).isNotEmpty)
                _infoBadge(
                  Icons.local_shipping_outlined,
                  (load['required_truck_type'] as String),
                ),
              if (load['required_tyres'] != null &&
                  (load['required_tyres'] as List).isNotEmpty)
                _infoBadge(
                  Icons.tire_repair,
                  '${(load['required_tyres'] as List).join(',')}W',
                ),
              if (load['pickup_date'] != null)
                _infoBadge(
                  Icons.calendar_today,
                  _formatPickupDate(load['pickup_date'] as String),
                ),
              _infoBadge(
                load['price_type'] == 'fixed'
                    ? Icons.lock_outline
                    : Icons.swap_horiz,
                (load['price_type'] as String? ?? 'negotiable').toUpperCase(),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (timeAgo.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text('Posted $timeAgo',
                  style: AppTypography.caption
                      .copyWith(color: AppColors.textTertiary)),
            ),
          // Task 5.4: Book as primary CTA, Chat as secondary
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 38,
                  child: FilledButton.icon(
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      final loadId = load['id'] as String? ?? '';
                      if (loadId.isNotEmpty) {
                        context.push('/load-detail/$loadId');
                      }
                    },
                    icon: const Icon(Icons.local_shipping, size: 16),
                    label: const Text('Book Load'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.success,
                      textStyle: AppTypography.bodySmall.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 38,
                child: OutlinedButton.icon(
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
                  icon: const Icon(Icons.chat_bubble_outline, size: 16),
                  label: const Text('Chat'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.brandTeal,
                    side: const BorderSide(color: AppColors.brandTeal),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      ),
    );
  }

  Widget _infoBadge(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.scaffoldBg,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.divider, width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppColors.textTertiary),
          const SizedBox(width: 3),
          Text(
            label,
            style: AppTypography.caption.copyWith(
              color: AppColors.textSecondary,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  /// Task 5.4: Material-specific icon for visual recognition.
  static IconData _materialIcon(String material) {
    final m = material.toLowerCase();
    if (m.contains('steel') || m.contains('iron') || m.contains('metal')) return Icons.construction;
    if (m.contains('coal') || m.contains('coke')) return Icons.terrain;
    if (m.contains('cement') || m.contains('clinker')) return Icons.domain;
    if (m.contains('grain') || m.contains('wheat') || m.contains('rice') || m.contains('dal')) return Icons.grass;
    if (m.contains('sand') || m.contains('gravel') || m.contains('stone') || m.contains('aggregate')) return Icons.landscape;
    if (m.contains('timber') || m.contains('wood') || m.contains('plywood')) return Icons.park;
    if (m.contains('chemical') || m.contains('acid') || m.contains('fertilizer')) return Icons.science;
    if (m.contains('oil') || m.contains('fuel') || m.contains('diesel') || m.contains('petrol')) return Icons.local_gas_station;
    if (m.contains('cotton') || m.contains('textile') || m.contains('fabric')) return Icons.checkroom;
    if (m.contains('machinery') || m.contains('equipment') || m.contains('machine')) return Icons.precision_manufacturing;
    if (m.contains('container') || m.contains('parcel') || m.contains('goods')) return Icons.inventory_2;
    return Icons.category;
  }

  String _formatPickupDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final pickupDay = DateTime(date.year, date.month, date.day);
      final diff = pickupDay.difference(today).inDays;
      if (diff == 0) return 'Today';
      if (diff == 1) return 'Tomorrow';
      if (diff < 7) return '${diff}d';
      return '${date.day}/${date.month}';
    } catch (_) {
      return dateStr.length > 10 ? dateStr.substring(0, 10) : dateStr;
    }
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
            Text(AppLocalizations.of(context)!.verification,
                style: AppTypography.h3Subsection),
            const SizedBox(height: 8),
            Text(
              AppLocalizations.of(context)!.completeVerification,
              textAlign: TextAlign.center,
              style: AppTypography.bodyMedium
                  .copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
            GradientButton(
              text: AppLocalizations.of(context)!.verification,
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

/// Task 5.1: Compact stats ribbon at top of Find Loads (trucker home).
class _StatsRibbon extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tripsAsync = ref.watch(truckerActiveTripsCountProvider);
    final trucksAsync = ref.watch(truckerFleetCountProvider);
    final unreadAsync = ref.watch(unreadChatsCountProvider);

    final trips = tripsAsync.valueOrNull ?? 0;
    final trucks = trucksAsync.valueOrNull ?? 0;
    final unread = unreadAsync.valueOrNull ?? 0;

    return Container(
      height: 36,
      color: AppColors.brandTealLight,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _StatBadge(
            icon: Icons.assignment,
            label: '$trips trips',
            onTap: () => context.go('/my-trips'),
          ),
          _StatBadge(
            icon: Icons.local_shipping,
            label: '$trucks trucks',
            onTap: () => context.push('/my-trucks'),
          ),
          _StatBadge(
            icon: Icons.chat_bubble,
            label: '$unread messages',
            highlight: unread > 0,
            onTap: () => context.go('/messages'),
          ),
        ],
      ),
    );
  }
}

class _StatBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool highlight;

  const _StatBadge({
    required this.icon,
    required this.label,
    required this.onTap,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14,
              color: highlight ? AppColors.brandOrange : AppColors.brandTeal),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppTypography.caption.copyWith(
              color: highlight ? AppColors.brandOrange : AppColors.brandTeal,
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

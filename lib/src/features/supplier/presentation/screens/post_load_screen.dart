import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tranzfort/l10n/app_localizations.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/providers/auth_service_provider.dart';
import '../../../../core/utils/dialogs.dart';
import '../../../../core/services/smart_defaults_service.dart';
import '../../../../shared/widgets/app_drawer.dart';
import '../../../../shared/widgets/city_autocomplete_field.dart';
import '../../../../shared/widgets/gradient_button.dart';
import '../../../../core/constants/load_constants.dart';
import '../../../../core/providers/locale_provider.dart';
import '../../../../shared/widgets/tts_button.dart';
import 'package:latlong2/latlong.dart';
import '../../../../shared/widgets/feedback_prompt.dart';
import '../../../navigation/services/routing_service.dart';

class PostLoadScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic>? prefill;
  final String? editLoadId; // SUP-3: non-null = edit mode

  const PostLoadScreen({super.key, this.prefill, this.editLoadId});

  @override
  ConsumerState<PostLoadScreen> createState() => _PostLoadScreenState();
}

class _PostLoadScreenState extends ConsumerState<PostLoadScreen> {
  final _formKey = GlobalKey<FormState>();
  int _currentStep = 0;
  bool _isLoading = false;

  // Step 1: Route & Goods
  final _originCityController = TextEditingController();
  final _originStateController = TextEditingController();
  final _destCityController = TextEditingController();
  final _destStateController = TextEditingController();
  // V4-3: Capture lat/lng from location selection
  double? _originLat;
  double? _originLng;
  double? _destLat;
  double? _destLng;
  // Phase 8: Precise address and pre-computed distance
  String? _originAddress;
  String? _destAddress;
  double? _routeDistanceKm;
  double? _routeDurationMin;
  bool _isComputingRoute = false;
  String _material = 'Cement';
  final _weightMinController = TextEditingController();
  final _weightMaxController = TextEditingController();

  // Step 2: Truck Requirements
  String _truckType = 'Any';
  final Set<int> _selectedTyres = {};

  // Step 3: Pricing
  final _priceController = TextEditingController();
  String _priceType = 'negotiable';
  DateTime _pickupDate = DateTime.now().add(const Duration(days: 1));
  int _advancePercentage = 80;

  final _otherMaterialController = TextEditingController();
  final _notesController = TextEditingController();

  // Task 7.9: Bulk load groups
  int? _trucksNeeded;

  @override
  void initState() {
    super.initState();
    final pf = widget.prefill;
    if (pf != null) {
      _applyPrefill(pf);
    } else {
      _loadDefaults();
    }
  }

  void _applyPrefill(Map<String, dynamic> pf) {
    _originCityController.text = pf['origin_city']?.toString() ?? '';
    _originStateController.text = pf['origin_state']?.toString() ?? '';
    _destCityController.text = pf['dest_city']?.toString() ?? '';
    _destStateController.text = pf['dest_state']?.toString() ?? '';
    _material = pf['material']?.toString() ?? 'Cement';
    if (pf['weight_tonnes'] != null) {
      _weightMinController.text = pf['weight_tonnes'].toString();
    }
    if (pf['weight_max_tonnes'] != null) {
      _weightMaxController.text = pf['weight_max_tonnes'].toString();
    }
    _truckType = pf['required_truck_type']?.toString() ?? 'Any';
    if (_truckType.isEmpty) _truckType = 'Any';
    // Capitalize first letter for display
    _truckType = _truckType[0].toUpperCase() + _truckType.substring(1);
    if (pf['price'] != null) {
      _priceController.text = pf['price'].toString();
    }
    _priceType = pf['price_type']?.toString() ?? 'negotiable';
    _advancePercentage = (pf['advance_percentage'] as int?) ?? 80;
  }

  Future<void> _loadDefaults() async {
    final (origin, dest) = await SmartDefaults.getLastRoute();
    if (origin != null && _originCityController.text.isEmpty) {
      _originCityController.text = origin;
    }
    if (dest != null && _destCityController.text.isEmpty) {
      _destCityController.text = dest;
    }
  }

  @override
  void dispose() {
    _originCityController.dispose();
    _originStateController.dispose();
    _destCityController.dispose();
    _destStateController.dispose();
    _weightMinController.dispose();
    _weightMaxController.dispose();
    _priceController.dispose();
    _otherMaterialController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  bool _validateCurrentStep() {
    switch (_currentStep) {
      case 0:
        if (_originCityController.text.trim().isEmpty) {
          AppDialogs.showSnackBar(context, l10n.originCity);
          return false;
        }
        if (_destCityController.text.trim().isEmpty) {
          AppDialogs.showSnackBar(context, l10n.destinationCity);
          return false;
        }
        final wMin = double.tryParse(_weightMinController.text);
        if (wMin == null || wMin <= 0) {
          AppDialogs.showSnackBar(context, '${l10n.weight}: min 0.1 ${l10n.tonnes}');
          return false;
        }
        final wMax = double.tryParse(_weightMaxController.text);
        if (wMax != null && wMax < wMin) {
          AppDialogs.showSnackBar(context, 'Max weight must be ≥ min weight');
          return false;
        }
        return true;
      case 1:
        return true;
      case 2:
        final p = double.tryParse(_priceController.text);
        if (p == null || p < 1) {
          AppDialogs.showSnackBar(context, '${l10n.price}: min ₹1');
          return false;
        }
        return true;
      default:
        return true;
    }
  }

  AppLocalizations get l10n => AppLocalizations.of(context)!;

  /// Phase 8: Auto-compute route distance via OSRM when both endpoints have lat/lng.
  Future<void> _tryComputeRoute() async {
    if (_originLat == null || _originLng == null ||
        _destLat == null || _destLng == null) {
      return;
    }
    if (_isComputingRoute) return;

    setState(() => _isComputingRoute = true);
    try {
      final routing = RoutingService();
      final routes = await routing.getRoute(
        origin: LatLng(_originLat!, _originLng!),
        destination: LatLng(_destLat!, _destLng!),
        alternatives: false,
      );
      routing.dispose();

      if (routes.isNotEmpty && mounted) {
        setState(() {
          _routeDistanceKm = routes.first.distanceKm;
          _routeDurationMin = routes.first.durationMin;
        });
      }
    } catch (_) {
      // Silently fail — distance is optional enrichment
    } finally {
      if (mounted) setState(() => _isComputingRoute = false);
    }
  }

  Map<String, dynamic> _buildLoadData() {
    return {
      'origin_city': _originCityController.text.trim(),
      'origin_state': _originStateController.text.trim(),
      'dest_city': _destCityController.text.trim(),
      'dest_state': _destStateController.text.trim(),
      'material': _material == 'Other'
          ? (_otherMaterialController.text.trim().isNotEmpty
              ? _otherMaterialController.text.trim()
              : 'Other')
          : _material,
      'weight_tonnes': double.tryParse(_weightMinController.text) ?? 0,
      if (_weightMaxController.text.trim().isNotEmpty)
        'weight_max_tonnes': double.tryParse(_weightMaxController.text),
      'required_truck_type':
          _truckType == 'Any' ? null : _truckType.toLowerCase(),
      'required_tyres':
          _selectedTyres.isEmpty ? null : _selectedTyres.toList(),
      'price': double.tryParse(_priceController.text) ?? 0,
      'price_type': _priceType,
      'advance_percentage': _advancePercentage,
      'pickup_date': _pickupDate.toIso8601String().split('T').first,
      if (_notesController.text.trim().isNotEmpty)
        'notes': _notesController.text.trim(),
      // V4-3: Include lat/lng when available
      if (_originLat != null) 'origin_lat': _originLat,
      if (_originLng != null) 'origin_lng': _originLng,
      if (_destLat != null) 'dest_lat': _destLat,
      if (_destLng != null) 'dest_lng': _destLng,
      // Phase 8: Precise address and pre-computed distance
      if (_originAddress != null) 'origin_address': _originAddress,
      if (_destAddress != null) 'dest_address': _destAddress,
      if (_routeDistanceKm != null) 'route_distance_km': _routeDistanceKm,
      if (_routeDurationMin != null) 'route_duration_min': _routeDurationMin,
      // Task 7.9: Bulk load groups
      if (_trucksNeeded != null && _trucksNeeded! > 1) 'trucks_needed': _trucksNeeded,
    };
  }

  Future<void> _handleSaveDraft() async {
    setState(() => _isLoading = true);
    try {
      final authService = ref.read(authServiceProvider);
      final db = ref.read(databaseServiceProvider);
      final userId = authService.currentUser!.id;

      final loadData = _buildLoadData();
      loadData['status'] = 'draft';

      if (widget.editLoadId != null) {
        await db.updateLoad(widget.editLoadId!, loadData);
      } else {
        loadData['supplier_id'] = userId;
        await db.createLoad(loadData);
      }

      ref.invalidate(supplierActiveLoadsCountProvider);
      ref.invalidate(supplierRecentLoadsProvider);

      if (mounted) {
        AppDialogs.showSuccessSnackBar(context, 'Draft saved');
        context.pop();
      }
    } catch (e) {
      if (mounted) AppDialogs.showErrorSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handlePost() async {
    setState(() => _isLoading = true);

    try {
      final authService = ref.read(authServiceProvider);
      final db = ref.read(databaseServiceProvider);
      final userId = authService.currentUser!.id;

      // Fail-safe verification gate (fresh read) to prevent bypass.
      final profile = await db.getUserProfile(userId);
      final verificationStatus =
          profile?['verification_status'] as String? ?? 'unverified';
      if (verificationStatus != 'verified') {
        if (mounted) {
          AppDialogs.showSnackBar(
              context, AppLocalizations.of(context)!.completeVerification);
          context.go('/supplier-verification');
        }
        return;
      }

      final loadData = _buildLoadData();

      // SUP-3: Edit mode vs create mode
      if (widget.editLoadId != null) {
        await db.updateLoad(widget.editLoadId!, loadData);
      } else {
        // Task 5.11: Deduplication check — warn if similar active load exists
        final origin = _originCityController.text.trim().toLowerCase();
        final dest = _destCityController.text.trim().toLowerCase();
        final existingLoads = await db.getMyLoads(userId);
        final cutoff = DateTime.now().subtract(const Duration(hours: 24));
        final duplicate = existingLoads.any((l) {
          if (l['status'] != 'active') return false;
          final createdAt = l['created_at'] != null
              ? DateTime.tryParse(l['created_at'] as String)
              : null;
          if (createdAt != null && createdAt.isBefore(cutoff)) return false;
          final lOrigin = (l['origin_city'] as String?)?.toLowerCase() ?? '';
          final lDest = (l['dest_city'] as String?)?.toLowerCase() ?? '';
          final lMaterial = (l['material'] as String?)?.toLowerCase() ?? '';
          return lOrigin == origin &&
              lDest == dest &&
              lMaterial == _material.toLowerCase();
        });

        if (duplicate && mounted) {
          final isHi = ref.read(localeProvider).languageCode == 'hi';
          final proceed = await AppDialogs.confirm(
            context,
            title: isHi ? 'डुप्लिकेट लोड' : 'Duplicate Load',
            description: isHi
                ? 'आपने पिछले 24 घंटे में इसी रूट और सामान का लोड पोस्ट किया है। फिर भी पोस्ट करें?'
                : 'You already have a similar active load (same route & material) posted in the last 24 hours. Post anyway?',
          );
          if (proceed != true) {
            setState(() => _isLoading = false);
            return;
          }
        }

        loadData['supplier_id'] = userId;
        await db.createLoad(loadData);
      }

      // Save smart defaults for next time
      SmartDefaults.saveLastRoute(
        _originCityController.text.trim(),
        _destCityController.text.trim(),
      );

      ref.invalidate(supplierActiveLoadsCountProvider);
      ref.invalidate(supplierRecentLoadsProvider);

      if (mounted) {
        // SUP-3: Edit mode — simple success + pop
        if (widget.editLoadId != null) {
          AppDialogs.showSuccessSnackBar(context, l10n.loadPostedSuccess);
          context.pop();
          return;
        }
        // SUP-1: Post-success load card preview
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.check_circle, color: AppColors.success, size: 28),
                const SizedBox(width: 8),
                Text(l10n.loadPostedSuccess),
              ],
            ),
            content: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.brandTealLight,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppColors.brandTeal.withValues(alpha: 0.30),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_originCityController.text} → ${_destCityController.text}',
                    style: AppTypography.bodyMedium
                        .copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '$_material • ${_weightMinController.text}${_weightMaxController.text.isNotEmpty ? '-${_weightMaxController.text}' : ''} tonnes',
                    style: AppTypography.caption
                        .copyWith(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        '₹${_priceController.text}/ton',
                        style: AppTypography.bodyMedium.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.brandTeal,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.scaffoldBg,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _priceType.toUpperCase(),
                          style: const TextStyle(
                              fontSize: 10, color: AppColors.textTertiary),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '🚛 $_truckType • 📅 ${_pickupDate.day}/${_pickupDate.month}/${_pickupDate.year}',
                    style: AppTypography.caption
                        .copyWith(color: AppColors.textSecondary),
                  ),
                  Text(
                    'Advance: $_advancePercentage%',
                    style: AppTypography.caption
                        .copyWith(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            actions: [
              FilledButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  context.go('/my-loads');
                },
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.brandTeal,
                ),
                child: const Text('View My Loads'),
              ),
            ],
          ),
        );

        // Task 5.9: Feedback prompt after posting a load
        if (mounted) {
          final locale = ref.read(localeProvider).languageCode;
          FeedbackPrompt.maybeShow(
            context,
            actionLabel: locale == 'hi' ? 'लोड पोस्ट किया' : 'Load Posted',
            locale: locale,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        AppDialogs.showErrorSnackBar(context, e);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: Text(l10n.postLoad),
        actions: [
          TtsButton(
            text: 'Read aloud',
            spokenText: _buildStepSpokenText(),
            locale: ref.watch(localeProvider).languageCode == 'hi' ? 'hi-IN' : 'en-IN',
            size: 22,
          ),
          if (widget.editLoadId == null)
            TextButton.icon(
              onPressed: _isLoading ? null : _handleSaveDraft,
              icon: const Icon(Icons.save_outlined, size: 18),
              label: Text(l10n.saveDraft),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: Stepper(
          currentStep: _currentStep,
          onStepContinue: () {
            if (_currentStep < 3) {
              if (_validateCurrentStep()) {
                setState(() => _currentStep++);
              }
            } else {
              _handlePost();
            }
          },
          onStepCancel: () {
            if (_currentStep > 0) {
              setState(() => _currentStep--);
            } else {
              context.pop();
            }
          },
          controlsBuilder: (context, details) {
            final isLast = _currentStep == 3;
            return Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Row(
                children: [
                  Expanded(
                    child: isLast
                        ? GradientButton(
                            text: l10n.postLoadButton,
                            isLoading: _isLoading,
                            onPressed: _isLoading ? null : details.onStepContinue,
                          )
                        : ElevatedButton(
                            onPressed: details.onStepContinue,
                            child: Text(l10n.continueAction),
                          ),
                  ),
                  const SizedBox(width: 12),
                  if (_currentStep > 0)
                    TextButton(
                      onPressed: details.onStepCancel,
                      child: Text(l10n.back),
                    ),
                ],
              ),
            );
          },
          steps: [
            // Step 1: Route & Goods
            Step(
              title: Text(l10n.routeDetails),
              isActive: _currentStep >= 0,
              state:
                  _currentStep > 0 ? StepState.complete : StepState.indexed,
              content: Column(
                children: [
                  CityAutocompleteField(
                    controller: _originCityController,
                    labelText: l10n.originCity,
                    prefixIcon: Icons.location_on_outlined,
                    textInputAction: TextInputAction.next,
                    useGooglePlaces: true,
                    onCitySelected: (loc) {
                      _originStateController.text = loc.state;
                      _originLat = loc.lat;
                      _originLng = loc.lng;
                      _originAddress = loc.address;
                      _tryComputeRoute();
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _originStateController,
                    decoration: InputDecoration(
                      labelText: l10n.from,
                    ),
                    readOnly: true,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 12),
                  CityAutocompleteField(
                    controller: _destCityController,
                    labelText: l10n.destinationCity,
                    prefixIcon: Icons.flag_outlined,
                    textInputAction: TextInputAction.next,
                    useGooglePlaces: true,
                    onCitySelected: (loc) {
                      _destStateController.text = loc.state;
                      _destLat = loc.lat;
                      _destLng = loc.lng;
                      _destAddress = loc.address;
                      _tryComputeRoute();
                    },
                  ),
                  // Phase 8: Show computed distance if available
                  if (_routeDistanceKm != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        children: [
                          const Icon(Icons.route, size: 16, color: AppColors.brandTeal),
                          const SizedBox(width: 6),
                          Text(
                            '${_routeDistanceKm!.round()} km • ~${(_routeDurationMin! / 60).toStringAsFixed(1)} hrs',
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.brandTeal,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (_isComputingRoute)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 14, height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          SizedBox(width: 8),
                          Text('Computing route...'),
                        ],
                      ),
                    ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _destStateController,
                    decoration: InputDecoration(
                      labelText: l10n.to,
                    ),
                    readOnly: true,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: LoadConstants.materials.contains(_material)
                        ? _material
                        : LoadConstants.materials.first,
                    decoration: InputDecoration(
                      labelText: l10n.material,
                    ),
                    items: LoadConstants.materials
                        .map((m) =>
                            DropdownMenuItem(value: m, child: Text(m)))
                        .toList(),
                    onChanged: (v) => setState(() => _material = v!),
                    isExpanded: true,
                  ),
                  if (_material == 'Other') ...[
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _otherMaterialController,
                      decoration: InputDecoration(
                        labelText: '${l10n.material} (${l10n.from})',
                        hintText: 'e.g. Plywood, Paper',
                      ),
                      textInputAction: TextInputAction.next,
                    ),
                  ],
                  const SizedBox(height: 12),
                  // LOAD-1: Min–Max weight range
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _weightMinController,
                          decoration: InputDecoration(
                            labelText: 'Min ${l10n.weight}',
                            suffixText: l10n.tonnes,
                            hintText: '0.1',
                          ),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          textInputAction: TextInputAction.next,
                          validator: (v) {
                            final w = double.tryParse(v ?? '');
                            if (w == null || w <= 0) return 'Min 0.1';
                            if (w > 100) return 'Max 100';
                            return null;
                          },
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Text('–'),
                      ),
                      Expanded(
                        child: TextFormField(
                          controller: _weightMaxController,
                          decoration: InputDecoration(
                            labelText: 'Max ${l10n.weight}',
                            suffixText: l10n.tonnes,
                            hintText: 'Optional',
                          ),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          textInputAction: TextInputAction.next,
                          validator: (v) {
                            if (v == null || v.isEmpty) return null; // optional
                            final w = double.tryParse(v);
                            if (w == null || w <= 0) return 'Invalid';
                            if (w > 100) return 'Max 100';
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _notesController,
                    decoration: const InputDecoration(
                      labelText: 'Notes / Special Instructions',
                      hintText: 'e.g. Fragile cargo, needs tarpaulin, night loading only',
                      prefixIcon: Icon(Icons.notes_outlined),
                    ),
                    maxLines: 2,
                    textInputAction: TextInputAction.done,
                  ),
                ],
              ),
            ),

            // Step 2: Truck Requirements
            Step(
              title: Text(l10n.truckType),
              isActive: _currentStep >= 1,
              state:
                  _currentStep > 1 ? StepState.complete : StepState.indexed,
              content: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.truckType, style: AppTypography.bodyMedium),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: LoadConstants.truckTypes.map((type) {
                      final selected = _truckType == type;
                      return FilterChip(
                        label: Text(type),
                        selected: selected,
                        onSelected: (_) =>
                            setState(() => _truckType = type),
                        selectedColor: AppColors.brandTeal,
                        labelStyle: TextStyle(
                          color:
                              selected ? Colors.white : AppColors.textPrimary,
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  Text(l10n.tyres, style: AppTypography.bodyMedium),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: LoadConstants.tyreOptions.map((tyre) {
                      final selected = _selectedTyres.contains(tyre);
                      return FilterChip(
                        label: Text('$tyre'),
                        selected: selected,
                        onSelected: (v) {
                          setState(() {
                            if (v) {
                              _selectedTyres.add(tyre);
                            } else {
                              _selectedTyres.remove(tyre);
                            }
                          });
                        },
                        selectedColor: AppColors.brandTeal,
                        labelStyle: TextStyle(
                          color:
                              selected ? Colors.white : AppColors.textPrimary,
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),

            // Step 3: Pricing
            Step(
              title: Text(l10n.expectedPrice),
              isActive: _currentStep >= 2,
              state:
                  _currentStep > 2 ? StepState.complete : StepState.indexed,
              content: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: _priceController,
                    decoration: InputDecoration(
                      labelText: l10n.price,
                      prefixText: '₹ ',
                      suffixText: '/${l10n.tonnes}',
                    ),
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      final p = double.tryParse(v ?? '');
                      if (p == null || p < 1) return 'Min ₹1/${l10n.tonnes}';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  RadioGroup<String>(
                    groupValue: _priceType,
                    onChanged: (v) => setState(() => _priceType = v ?? _priceType),
                    child: Row(
                      children: [
                        Expanded(
                          child: RadioListTile<String>(
                            title: Text(l10n.negotiable),
                            value: 'negotiable',
                            activeColor: AppColors.brandTeal,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                        Expanded(
                          child: RadioListTile<String>(
                            title: Text(l10n.fixedPrice),
                            value: 'fixed',
                            activeColor: AppColors.brandTeal,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(l10n.pickupDate),
                    subtitle: Text(
                      '${_pickupDate.day}/${_pickupDate.month}/${_pickupDate.year}',
                    ),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: _pickupDate,
                        firstDate: DateTime.now(),
                        lastDate:
                            DateTime.now().add(const Duration(days: 90)),
                      );
                      if (date != null) {
                        setState(() => _pickupDate = date);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  Text('Advance Payment: $_advancePercentage%',
                      style: AppTypography.bodyMedium),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Text('50%', style: TextStyle(fontSize: 12)),
                      Expanded(
                        child: Slider(
                          value: _advancePercentage.toDouble(),
                          min: 50,
                          max: 100,
                          divisions: 5,
                          label: '$_advancePercentage%',
                          activeColor: AppColors.brandTeal,
                          onChanged: (v) =>
                              setState(() => _advancePercentage = v.round()),
                        ),
                      ),
                      const Text('100%', style: TextStyle(fontSize: 12)),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.infoLight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$_advancePercentage% on loading, ${100 - _advancePercentage}% on delivery',
                      style: AppTypography.bodySmall
                          .copyWith(color: AppColors.info),
                    ),
                  ),
                  // Task 7.9: Bulk load groups — trucks needed
                  const SizedBox(height: 16),
                  Text('Trucks Needed', style: AppTypography.bodyMedium),
                  const SizedBox(height: 4),
                  Text('Need multiple trucks? Set the count for a bulk load group.',
                      style: AppTypography.caption.copyWith(color: AppColors.textSecondary)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      _trucksChip(null, '1 (default)'),
                      _trucksChip(5, '5'),
                      _trucksChip(10, '10'),
                      _trucksChip(25, '25'),
                    ],
                  ),
                  if (_trucksNeeded != null && _trucksNeeded! > 1)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.brandTealLight,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.local_shipping, size: 16, color: AppColors.brandTeal),
                            const SizedBox(width: 6),
                            Text(
                              'Bulk Load: $_trucksNeeded trucks needed',
                              style: AppTypography.bodySmall.copyWith(
                                color: AppColors.brandTeal,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Step 4: Review
            Step(
              title: Text(l10n.review),
              isActive: _currentStep >= 3,
              content: Container(
                padding: const EdgeInsets.all(AppSpacing.cardPadding),
                decoration: BoxDecoration(
                  color: AppColors.cardBg,
                  borderRadius:
                      BorderRadius.circular(AppSpacing.cardRadius),
                  border: const Border(
                    left: BorderSide(color: AppColors.brandTeal, width: 3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_originCityController.text} → ${_destCityController.text}',
                      style: AppTypography.h3Subsection,
                    ),
                    const SizedBox(height: 8),
                    _reviewRow('Material', _material),
                    _reviewRow('Weight', '${_weightMinController.text}${_weightMaxController.text.isNotEmpty ? ' - ${_weightMaxController.text}' : ''} tonnes'),
                    _reviewRow('Truck Type', _truckType),
                    _reviewRow('Price',
                        '₹${_priceController.text}/ton ($_priceType)'),
                    _reviewRow('Advance',
                        '$_advancePercentage% on loading'),
                    _reviewRow('Pickup',
                        '${_pickupDate.day}/${_pickupDate.month}/${_pickupDate.year}'),
                    if (_notesController.text.trim().isNotEmpty)
                      _reviewRow('Notes', _notesController.text.trim()),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _reviewRow(String label, String value) {
    final l10n = AppLocalizations.of(context)!;
    String translatedLabel;
    switch (label) {
      case 'Material':
        translatedLabel = l10n.material;
        break;
      case 'Weight':
        translatedLabel = l10n.weight;
        break;
      case 'Truck Type':
        translatedLabel = l10n.truckType;
        break;
      case 'Price':
        translatedLabel = l10n.price;
        break;
      case 'Pickup':
        translatedLabel = l10n.pickupDate;
        break;
      default:
        translatedLabel = label;
    }
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(translatedLabel,
                style: AppTypography.caption
                    .copyWith(color: AppColors.textSecondary)),
          ),
          Expanded(child: Text(value, style: AppTypography.bodyMedium)),
        ],
      ),
    );
  }

  Widget _trucksChip(int? count, String label) {
    final selected = _trucksNeeded == count;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => _trucksNeeded = count),
      selectedColor: AppColors.brandTeal,
      labelStyle: TextStyle(
        color: selected ? Colors.white : AppColors.textPrimary,
        fontSize: 13,
      ),
    );
  }

  String _buildStepSpokenText() {
    final isHi = ref.watch(localeProvider).languageCode == 'hi';
    switch (_currentStep) {
      case 0:
        return isHi
            ? 'रूट और माल। ऑरिजिन: ${_originCityController.text}, डेस्टिनेशन: ${_destCityController.text}, मटेरियल: $_material, वेट: ${_weightMinController.text} टन।'
            : 'Route and goods. Origin: ${_originCityController.text}, destination: ${_destCityController.text}, material: $_material, weight: ${_weightMinController.text} tonnes.';
      case 1:
        return isHi
            ? 'ट्रक रिक्वायरमेंट्स। ट्रक टाइप: $_truckType, टायर: ${_selectedTyres.isEmpty ? "any" : _selectedTyres.join(" and ")}।'
            : 'Truck requirements. Truck type: $_truckType, tyres: ${_selectedTyres.isEmpty ? "any" : _selectedTyres.join(" and ")}.';
      case 2:
        return isHi
            ? 'प्राइसिंग। प्राइस: ₹${_priceController.text} प्रति टन, टाइप: $_priceType, एडवांस: $_advancePercentage%, पिकअप डेट: ${_pickupDate.day}/${_pickupDate.month}/${_pickupDate.year}।'
            : 'Pricing. Price: ₹${_priceController.text} per tonne, type: $_priceType, advance: $_advancePercentage%, pickup date: ${_pickupDate.day}/${_pickupDate.month}/${_pickupDate.year}.';
      case 3:
        return isHi
            ? 'रिव्यू। ${_originCityController.text} से ${_destCityController.text}, $_material, ${_weightMinController.text} टन, $_truckType, ₹${_priceController.text} प्रति टन। पोस्ट करने के लिए तैयार।'
            : 'Review. From ${_originCityController.text} to ${_destCityController.text}, $_material, ${_weightMinController.text} tonnes, $_truckType, ₹${_priceController.text} per tonne. Ready to post.';
      default:
        return isHi ? 'लोड पोस्ट करें।' : 'Post a load.';
    }
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/providers/auth_service_provider.dart';
import '../../../../core/utils/dialogs.dart';
import '../../../../core/services/smart_defaults_service.dart';
import '../../../../shared/widgets/app_drawer.dart';
import '../../../../shared/widgets/city_autocomplete_field.dart';
import '../../../../shared/widgets/gradient_button.dart';

class PostLoadScreen extends ConsumerStatefulWidget {
  const PostLoadScreen({super.key});

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
  String _material = 'Cement';
  final _weightController = TextEditingController();

  // Step 2: Truck Requirements
  String _truckType = 'Any';
  final Set<int> _selectedTyres = {};

  // Step 3: Pricing
  final _priceController = TextEditingController();
  String _priceType = 'negotiable';
  DateTime _pickupDate = DateTime.now().add(const Duration(days: 1));

  static const _materials = [
    'Cement',
    'Steel',
    'Coal',
    'Grain',
    'Chemicals',
    'Other'
  ];
  static const _truckTypes = [
    'Any',
    'Open',
    'Container',
    'Trailer',
    'Tanker',
    'Refrigerated'
  ];
  static const _tyreOptions = [6, 10, 12, 14, 16, 18, 22];

  @override
  void initState() {
    super.initState();
    _loadDefaults();
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
    _weightController.dispose();
    _priceController.dispose();
    super.dispose();
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

      await db.createLoad({
        'supplier_id': userId,
        'origin_city': _originCityController.text.trim(),
        'origin_state': _originStateController.text.trim(),
        'dest_city': _destCityController.text.trim(),
        'dest_state': _destStateController.text.trim(),
        'material': _material,
        'weight_tonnes': double.tryParse(_weightController.text) ?? 0,
        'required_truck_type':
            _truckType == 'Any' ? null : _truckType.toLowerCase(),
        'required_tyres':
            _selectedTyres.isEmpty ? null : _selectedTyres.toList(),
        'price': double.tryParse(_priceController.text) ?? 0,
        'price_type': _priceType,
        'pickup_date': _pickupDate.toIso8601String().split('T').first,
      });

      // Save smart defaults for next time
      SmartDefaults.saveLastRoute(
        _originCityController.text.trim(),
        _destCityController.text.trim(),
      );

      ref.invalidate(supplierActiveLoadsCountProvider);
      ref.invalidate(supplierRecentLoadsProvider);

      if (mounted) {
        AppDialogs.showSuccessSnackBar(context, AppLocalizations.of(context)!.loadPostedSuccess);
        context.go('/my-loads');
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
      appBar: AppBar(title: Text(l10n.postLoad)),
      body: Form(
        key: _formKey,
        child: Stepper(
          currentStep: _currentStep,
          onStepContinue: () {
            if (_currentStep < 3) {
              setState(() => _currentStep++);
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
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _originStateController,
                    decoration: InputDecoration(
                      labelText: l10n.from,
                    ),
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 12),
                  CityAutocompleteField(
                    controller: _destCityController,
                    labelText: l10n.destinationCity,
                    prefixIcon: Icons.flag_outlined,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _destStateController,
                    decoration: InputDecoration(
                      labelText: l10n.to,
                    ),
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _material,
                    decoration: InputDecoration(
                      labelText: l10n.material,
                    ),
                    items: _materials
                        .map((m) =>
                            DropdownMenuItem(value: m, child: Text(m)))
                        .toList(),
                    onChanged: (v) => setState(() => _material = v!),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _weightController,
                    decoration: InputDecoration(
                      labelText: l10n.weight,
                      suffixText: l10n.tonnes,
                    ),
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.next,
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
                    children: _truckTypes.map((type) {
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
                    children: _tyreOptions.map((tyre) {
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
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: RadioListTile<String>(
                          title: Text(l10n.negotiable),
                          value: 'negotiable',
                          groupValue: _priceType,
                          onChanged: (v) => setState(() => _priceType = v ?? _priceType),
                          activeColor: AppColors.brandTeal,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      Expanded(
                        child: RadioListTile<String>(
                          title: Text(l10n.fixedPrice),
                          value: 'fixed',
                          groupValue: _priceType,
                          onChanged: (v) => setState(() => _priceType = v ?? _priceType),
                          activeColor: AppColors.brandTeal,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ],
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
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.infoLight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '80% Advance on Loading, 20% on Delivery',
                      style: AppTypography.bodySmall
                          .copyWith(color: AppColors.info),
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
                    _reviewRow('Weight', '${_weightController.text} tonnes'),
                    _reviewRow('Truck Type', _truckType),
                    _reviewRow('Price',
                        '₹${_priceController.text}/ton ($_priceType)'),
                    _reviewRow('Pickup',
                        '${_pickupDate.day}/${_pickupDate.month}/${_pickupDate.year}'),
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
}

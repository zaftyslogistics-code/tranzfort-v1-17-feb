import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/providers/auth_service_provider.dart';
import '../../../../core/utils/dialogs.dart';
import '../../../../shared/widgets/app_drawer.dart';
import '../../../../shared/widgets/gradient_button.dart';

class SuperLoadRequestScreen extends ConsumerStatefulWidget {
  final String loadId;

  const SuperLoadRequestScreen({super.key, required this.loadId});

  @override
  ConsumerState<SuperLoadRequestScreen> createState() =>
      _SuperLoadRequestScreenState();
}

class _SuperLoadRequestScreenState
    extends ConsumerState<SuperLoadRequestScreen> {
  bool _isLoading = false;
  int _paymentTermDays = 10; // default
  bool _isCustomTerm = false;
  final _customTermController = TextEditingController();
  Map<String, dynamic>? _loadData;

  @override
  void initState() {
    super.initState();
    _fetchLoadData();
  }

  @override
  void dispose() {
    _customTermController.dispose();
    super.dispose();
  }

  Future<void> _fetchLoadData() async {
    final db = ref.read(databaseServiceProvider);
    final load = await db.getLoadById(widget.loadId);
    if (mounted) setState(() => _loadData = load);
  }

  int get _effectiveTermDays {
    if (_isCustomTerm) {
      return int.tryParse(_customTermController.text) ?? _paymentTermDays;
    }
    return _paymentTermDays;
  }

  Future<void> _handleRequest() async {
    // Validate custom term
    if (_isCustomTerm) {
      final custom = int.tryParse(_customTermController.text);
      if (custom == null || custom < 2 || custom > 20) {
        AppDialogs.showSnackBar(context, 'Payment term must be 2–20 working days');
        return;
      }
    }

    final authService = ref.read(authServiceProvider);
    final db = ref.read(databaseServiceProvider);
    final userId = authService.currentUser?.id;
    if (userId == null) {
      if (mounted) {
        AppDialogs.showSnackBar(context, 'Please login again');
        context.go('/login');
      }
      return;
    }

    final load = _loadData ?? await db.getLoadById(widget.loadId);
    if (load == null) {
      if (mounted) {
        AppDialogs.showSnackBar(context, 'Load not found');
        context.go('/my-loads');
      }
      return;
    }

    final loadOwnerId = load['supplier_id'] as String?;
    if (loadOwnerId != userId) {
      if (mounted) {
        AppDialogs.showSnackBar(context, 'You can only request Super Load for your own loads');
        context.go('/my-loads');
      }
      return;
    }

    final isSuperLoad = load['is_super_load'] == true;
    if (isSuperLoad) {
      if (mounted) {
        AppDialogs.showSnackBar(context, 'This load is already a Super Load');
        context.go('/supplier/super-dashboard');
      }
      return;
    }

    final payout = await db.getPayoutProfile(userId);
    if (payout == null) {
      if (mounted) {
        AppDialogs.showSnackBar(context, 'Please add a payout profile first');
        context.push('/payout-profile');
      }
      return;
    }

    setState(() => _isLoading = true);

    try {
      await db.requestSuperLoad(widget.loadId, paymentTermDays: _effectiveTermDays);

      if (mounted) {
        AppDialogs.showSuccessSnackBar(context, 'Super Load requested!');
        context.go('/supplier/super-dashboard');
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
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      drawer: const AppDrawer(),
      appBar: AppBar(title: const Text('Make Super Load')),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.screenPaddingH),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.brandOrangeLight,
                borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
                border: Border.all(color: AppColors.brandOrange),
              ),
              child: Column(
                children: [
                  const Icon(Icons.star, size: 48, color: AppColors.brandOrange),
                  const SizedBox(height: 16),
                  Text('Super Load', style: AppTypography.h2Section),
                  const SizedBox(height: 8),
                  Text(
                    'TranZfort guarantees a truck for your load. We handle matching, verification, and payment.',
                    textAlign: TextAlign.center,
                    style: AppTypography.bodyMedium
                        .copyWith(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _benefitRow(Icons.check_circle, 'Guaranteed truck assignment'),
            _benefitRow(Icons.check_circle, 'Verified truckers only'),
            _benefitRow(Icons.check_circle, 'Secure payment via TranZfort'),
            _benefitRow(Icons.check_circle, 'Real-time tracking'),
            const SizedBox(height: 20),

            // Task 7.1: Payment term selector
            Text('Payment Terms', style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text('Remaining payment after POD delivery',
                style: AppTypography.caption.copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                _termChip(2, '2 days'),
                _termChip(10, '10 days'),
                ChoiceChip(
                  label: const Text('Custom'),
                  selected: _isCustomTerm,
                  onSelected: (v) => setState(() {
                    _isCustomTerm = v;
                    if (!v) _customTermController.clear();
                  }),
                  selectedColor: AppColors.brandOrange,
                  labelStyle: TextStyle(
                    color: _isCustomTerm ? Colors.white : AppColors.textPrimary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            if (_isCustomTerm) ...[              const SizedBox(height: 8),
              SizedBox(
                width: 160,
                child: TextField(
                  controller: _customTermController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    hintText: '2–20 days',
                    suffixText: 'days',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),

            // Task 7.7: Commission display
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.brandTealLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.info_outline, size: 16, color: AppColors.brandTeal),
                      const SizedBox(width: 6),
                      Text('TranZfort Commission: 5%',
                          style: AppTypography.bodySmall.copyWith(fontWeight: FontWeight.w600)),
                    ],
                  ),
                  if (_loadData != null) ...[                    const SizedBox(height: 4),
                    Builder(builder: (_) {
                      final price = (_loadData!['price'] as num?)?.toDouble() ?? 0;
                      final weight = (_loadData!['weight_tonnes'] as num?)?.toDouble() ?? 0;
                      final total = price * weight;
                      final commission = total * 0.05;
                      return Text(
                        'Est. commission: ₹${commission.round()} on ₹${total.round()} total',
                        style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
                      );
                    }),
                  ],
                ],
              ),
            ),

            // Confirmation summary
            if (_loadData != null) ...[              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.cardBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.borderDefault),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Summary', style: AppTypography.bodySmall.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    Text(
                      '${_loadData!['origin_city']} → ${_loadData!['dest_city']}',
                      style: AppTypography.bodySmall,
                    ),
                    Text(
                      '${_loadData!['material']} • ${_loadData!['weight_tonnes']}T • ₹${_loadData!['price']}/ton',
                      style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Payment: $_effectiveTermDays working days after POD',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.brandOrange,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const Spacer(),
            GradientButton(
              text: 'Request Super Load',
              isLoading: _isLoading,
              onPressed: _isLoading ? null : _handleRequest,
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _termChip(int days, String label) {
    final selected = !_isCustomTerm && _paymentTermDays == days;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (v) => setState(() {
        _isCustomTerm = false;
        _paymentTermDays = days;
        _customTermController.clear();
      }),
      selectedColor: AppColors.brandOrange,
      labelStyle: TextStyle(
        color: selected ? Colors.white : AppColors.textPrimary,
        fontSize: 13,
      ),
    );
  }

  Widget _benefitRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: AppColors.success, size: 20),
          const SizedBox(width: 12),
          Text(text, style: AppTypography.bodyMedium),
        ],
      ),
    );
  }
}

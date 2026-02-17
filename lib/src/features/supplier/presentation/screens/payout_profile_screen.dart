import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/providers/auth_service_provider.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/utils/dialogs.dart';
import '../../../../shared/widgets/app_drawer.dart';
import '../../../../shared/widgets/gradient_button.dart';
import '../../../../shared/widgets/status_chip.dart';

class PayoutProfileScreen extends ConsumerStatefulWidget {
  const PayoutProfileScreen({super.key});

  @override
  ConsumerState<PayoutProfileScreen> createState() =>
      _PayoutProfileScreenState();
}

class _PayoutProfileScreenState extends ConsumerState<PayoutProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _holderNameController = TextEditingController();
  final _accountController = TextEditingController();
  final _ifscController = TextEditingController();
  final _bankNameController = TextEditingController();
  bool _isLoading = false;
  Map<String, dynamic>? _existingPayout;

  @override
  void initState() {
    super.initState();
    _loadExisting();
  }

  Future<void> _loadExisting() async {
    final userId = ref.read(authServiceProvider).currentUser?.id;
    if (userId == null) return;

    final payout =
        await ref.read(databaseServiceProvider).getPayoutProfile(userId);
    if (payout != null && mounted) {
      setState(() {
        _existingPayout = payout;
        _holderNameController.text =
            payout['account_holder_name'] as String? ?? '';
        _ifscController.text = payout['ifsc_code'] as String? ?? '';
        _bankNameController.text = payout['bank_name'] as String? ?? '';
      });
    }
  }

  @override
  void dispose() {
    _holderNameController.dispose();
    _accountController.dispose();
    _ifscController.dispose();
    _bankNameController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final db = ref.read(databaseServiceProvider);
      final userId = ref.read(authServiceProvider).currentUser!.id;

      // Only store last 4 digits of account number
      final accountFull = _accountController.text.trim();
      final last4 = accountFull.length >= 4
          ? accountFull.substring(accountFull.length - 4)
          : accountFull;

      final data = {
        'account_holder_name': _holderNameController.text.trim(),
        'account_number_last4': last4,
        'ifsc_code': _ifscController.text.trim().toUpperCase(),
        'bank_name': _bankNameController.text.trim(),
      };

      if (_existingPayout != null) {
        await db.updatePayoutProfile(_existingPayout!['id'], data);
      } else {
        await db.createPayoutProfile(userId, data);
      }

      if (mounted) {
        AppDialogs.showSuccessSnackBar(context, 'Payout profile saved!');
        _loadExisting();
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
      appBar: AppBar(
        title: const Text('Payout Profile'),
        actions: [
          if (_existingPayout != null)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: StatusChip(
                  status: _existingPayout!['status'] as String? ?? 'pending'),
            ),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.screenPaddingH),
        child: Form(
          key: _formKey,
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.warningLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline,
                      size: 18, color: AppColors.warning),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Only the last 4 digits of your account number are stored for security.',
                      style: AppTypography.bodySmall
                          .copyWith(color: AppColors.warning),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _holderNameController,
              decoration: const InputDecoration(
                labelText: 'Account Holder Name',
                prefixIcon: Icon(Icons.person),
              ),
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              validator: (v) => Validators.required(v, 'Account holder name'),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _accountController,
              decoration: InputDecoration(
                labelText: _existingPayout != null
                    ? 'Account Number (ends in ${_existingPayout!['account_number_last4']})'
                    : 'Account Number',
                prefixIcon: const Icon(Icons.account_balance),
              ),
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.next,
              validator: (v) => Validators.required(v, 'Account number'),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _ifscController,
              decoration: const InputDecoration(
                labelText: 'IFSC Code',
                prefixIcon: Icon(Icons.code),
              ),
              textCapitalization: TextCapitalization.characters,
              textInputAction: TextInputAction.next,
              validator: Validators.ifsc,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _bankNameController,
              decoration: const InputDecoration(
                labelText: 'Bank Name',
                prefixIcon: Icon(Icons.account_balance_wallet),
              ),
              textInputAction: TextInputAction.done,
            ),
            const SizedBox(height: 32),
            GradientButton(
              text: _existingPayout != null ? 'Update' : 'Save',
              isLoading: _isLoading,
              onPressed: _isLoading ? null : _handleSave,
            ),
            const SizedBox(height: 24),
          ],
        ),
        ),
      ),
    );
  }
}

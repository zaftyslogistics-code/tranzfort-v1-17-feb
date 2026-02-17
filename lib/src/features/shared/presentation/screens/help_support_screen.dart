import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/providers/auth_service_provider.dart';
import '../../../../core/utils/dialogs.dart';
import '../../../../shared/widgets/app_drawer.dart';
import '../../../../shared/widgets/gradient_button.dart';

class HelpSupportScreen extends ConsumerStatefulWidget {
  const HelpSupportScreen({super.key});

  @override
  ConsumerState<HelpSupportScreen> createState() =>
      _HelpSupportScreenState();
}

class _HelpSupportScreenState extends ConsumerState<HelpSupportScreen> {
  final _subjectController = TextEditingController();
  final _descriptionController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _subjectController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (_subjectController.text.trim().isEmpty ||
        _descriptionController.text.trim().isEmpty) {
      AppDialogs.showSnackBar(context, 'Please fill all fields');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final db = ref.read(databaseServiceProvider);
      final userId = ref.read(authServiceProvider).currentUser!.id;

      await db.createTicket(
        userId: userId,
        subject: _subjectController.text.trim(),
        description: _descriptionController.text.trim(),
      );

      if (mounted) {
        _subjectController.clear();
        _descriptionController.clear();
        AppDialogs.showSuccessSnackBar(context, 'Support ticket submitted!');
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
      appBar: AppBar(title: const Text('Help & Support')),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.screenPaddingH),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Contact info
            Container(
              padding: const EdgeInsets.all(AppSpacing.cardPadding),
              decoration: BoxDecoration(
                color: AppColors.cardBg,
                borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
                boxShadow: AppColors.cardShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Contact Us', style: AppTypography.h3Subsection),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.email,
                        color: AppColors.brandTeal),
                    title: const Text('support@tranzfort.com'),
                    onTap: () => _openUrl(
                        'mailto:support@tranzfort.com'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Submit ticket
            Text('Submit a Ticket', style: AppTypography.h3Subsection),
            const SizedBox(height: 12),
            TextFormField(
              controller: _subjectController,
              decoration: const InputDecoration(
                labelText: 'Subject',
                prefixIcon: Icon(Icons.subject),
              ),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description',
                alignLabelWithHint: true,
              ),
              maxLines: 5,
              textInputAction: TextInputAction.done,
            ),
            const SizedBox(height: 16),
            GradientButton(
              text: 'Submit Ticket',
              isLoading: _isLoading,
              onPressed: _isLoading ? null : _handleSubmit,
            ),
            const SizedBox(height: 32),

            // FAQ
            Text('FAQ', style: AppTypography.h3Subsection),
            const SizedBox(height: 12),
            _faqItem('How do I post a load?',
                'Go to Dashboard → Post New Load. Fill in route, material, weight, and pricing details.'),
            _faqItem('How do I add a truck?',
                'Go to My Fleet → tap the + button. Enter truck details and submit for verification.'),
            _faqItem('How does Super Load work?',
                'Super Load guarantees a verified truck for your load. TranZfort handles matching and payment.'),
            _faqItem('How do I get verified?',
                'Go to your Profile → Verification. Submit your Aadhaar, PAN, and business documents.'),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _faqItem(String question, String answer) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        boxShadow: AppColors.cardShadow,
      ),
      child: ExpansionTile(
        title: Text(question,
            style: AppTypography.bodyMedium
                .copyWith(fontWeight: FontWeight.w500)),
        childrenPadding:
            const EdgeInsets.only(left: 16, right: 16, bottom: 12),
        children: [
          Text(answer,
              style: AppTypography.bodySmall
                  .copyWith(color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/providers/auth_service_provider.dart';
import '../../../../shared/widgets/app_drawer.dart';
import '../../../../shared/widgets/gradient_button.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../core/utils/dialogs.dart';

final myTicketsProvider = FutureProvider((ref) async {
  final db = ref.read(databaseServiceProvider);
  final userId = ref.read(authServiceProvider).currentUser!.id;
  return await db.getMyTickets(userId);
});

class MyTicketsScreen extends ConsumerWidget {
  const MyTicketsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ticketsAsync = ref.watch(myTicketsProvider);

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: const Text('My Tickets'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(myTicketsProvider),
          ),
        ],
      ),
      body: ticketsAsync.when(
        data: (tickets) {
          if (tickets.isEmpty) {
            return EmptyState(
              icon: Icons.support_agent_outlined,
              title: 'No tickets yet',
              description: 'Need help? Create a support ticket and we\'ll assist you.',
              actionLabel: 'Create Ticket',
              onAction: () => _showCreateTicketDialog(context, ref),
            );
          }

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(myTicketsProvider),
            child: ListView.builder(
              padding: const EdgeInsets.all(AppSpacing.screenPaddingH),
              itemCount: tickets.length,
              itemBuilder: (context, index) {
                final ticket = tickets[index];
                return _TicketCard(
                  ticket: ticket,
                  onTap: () => context.push('/ticket/${ticket['id']}'),
                );
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Error loading tickets: $error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.invalidate(myTicketsProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateTicketDialog(context, ref),
        backgroundColor: AppColors.brandTeal,
        icon: const Icon(Icons.add),
        label: const Text('New Ticket'),
      ),
    );
  }

  void _showCreateTicketDialog(BuildContext context, WidgetRef ref) {
    final subjectController = TextEditingController();
    final descriptionController = TextEditingController();
    final categoryController = TextEditingController(text: 'General');
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            left: 24,
            right: 24,
            top: 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Create Support Ticket', style: AppTypography.h3Subsection),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: categoryController.text,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  prefixIcon: Icon(Icons.category_outlined),
                ),
                items: const [
                  DropdownMenuItem(value: 'General', child: Text('General')),
                  DropdownMenuItem(value: 'Billing', child: Text('Billing')),
                  DropdownMenuItem(value: 'Technical', child: Text('Technical Issue')),
                  DropdownMenuItem(value: 'Account', child: Text('Account')),
                  DropdownMenuItem(value: 'Load', child: Text('Load/Booking')),
                  DropdownMenuItem(value: 'Other', child: Text('Other')),
                ],
                onChanged: (v) => categoryController.text = v!,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: subjectController,
                decoration: const InputDecoration(
                  labelText: 'Subject',
                  prefixIcon: Icon(Icons.subject),
                  hintText: 'Brief summary of your issue',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  prefixIcon: Icon(Icons.description_outlined),
                  hintText: 'Provide details about your issue...',
                ),
                maxLines: 4,
              ),
              const SizedBox(height: 24),
              GradientButton(
                text: 'Submit Ticket',
                isLoading: isSubmitting,
                onPressed: isSubmitting
                    ? null
                    : () async {
                        if (subjectController.text.trim().isEmpty ||
                            descriptionController.text.trim().isEmpty) {
                          AppDialogs.showErrorSnackBar(
                              ctx, 'Please fill in all fields');
                          return;
                        }

                        setState(() => isSubmitting = true);

                        try {
                          final db = ref.read(databaseServiceProvider);
                          final userId =
                              ref.read(authServiceProvider).currentUser!.id;

                          await db.createTicket(
                            userId: userId,
                            subject: subjectController.text.trim(),
                            description: descriptionController.text.trim(),
                          );

                          ref.invalidate(myTicketsProvider);

                          if (ctx.mounted) {
                            Navigator.pop(ctx);
                            AppDialogs.showSuccessSnackBar(
                                ctx, 'Ticket created successfully!');
                          }
                        } catch (e) {
                          setState(() => isSubmitting = false);
                          if (ctx.mounted) {
                            AppDialogs.showErrorSnackBar(ctx, e);
                          }
                        }
                      },
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _TicketCard extends StatelessWidget {
  final Map<String, dynamic> ticket;
  final VoidCallback onTap;

  const _TicketCard({required this.ticket, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final status = ticket['status'] as String? ?? 'open';
    final priority = ticket['priority'] as String? ?? 'medium';
    final createdAt = DateTime.tryParse(ticket['created_at'] as String? ?? '');
    final category = ticket['category'] as String? ?? 'General';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
          boxShadow: AppColors.cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getStatusColor(status).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: AppTypography.caption.copyWith(
                      color: _getStatusColor(status),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getPriorityColor(priority).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    priority.toUpperCase(),
                    style: AppTypography.caption.copyWith(
                      color: _getPriorityColor(priority),
                    ),
                  ),
                ),
                const Spacer(),
                if (createdAt != null)
                  Text(
                    DateFormat('MMM dd, yyyy').format(createdAt),
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              ticket['subject'] as String? ?? 'No subject',
              style: AppTypography.bodyLarge.copyWith(
                fontWeight: FontWeight.w600,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              ticket['description'] as String? ?? '',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.folder_outlined, size: 14, color: AppColors.textTertiary),
                const SizedBox(width: 4),
                Text(
                  category,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'open':
        return AppColors.info;
      case 'in_progress':
        return AppColors.warning;
      case 'resolved':
        return AppColors.success;
      case 'closed':
        return AppColors.textTertiary;
      default:
        return AppColors.info;
    }
  }

  Color _getPriorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'urgent':
        return AppColors.error;
      case 'high':
        return AppColors.brandOrange;
      case 'medium':
        return AppColors.warning;
      case 'low':
        return AppColors.success;
      default:
        return AppColors.textTertiary;
    }
  }
}

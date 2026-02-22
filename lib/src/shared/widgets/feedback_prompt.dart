import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_typography.dart';

/// Task 5.9: Lightweight feedback prompt shown after key actions.
/// Shows a 1-5 star rating + optional comment, throttled to once per day.
class FeedbackPrompt {
  FeedbackPrompt._();

  static const _lastPromptKey = 'feedback_last_prompt_ts';
  static const _cooldownHours = 24;

  /// Shows feedback prompt if cooldown has elapsed.
  /// [actionLabel] describes what just happened (e.g. "Load Posted").
  static Future<void> maybeShow(
    BuildContext context, {
    required String actionLabel,
    String? locale,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final lastTs = prefs.getInt(_lastPromptKey) ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - lastTs < _cooldownHours * 3600 * 1000) return;

    if (!context.mounted) return;

    final isHi = locale == 'hi';

    final result = await showModalBottomSheet<int>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => _FeedbackSheet(
        actionLabel: actionLabel,
        isHi: isHi,
      ),
    );

    if (result != null) {
      await prefs.setInt(_lastPromptKey, now);
      // Future: send rating to analytics/Supabase
    }
  }
}

class _FeedbackSheet extends StatefulWidget {
  final String actionLabel;
  final bool isHi;

  const _FeedbackSheet({required this.actionLabel, required this.isHi});

  @override
  State<_FeedbackSheet> createState() => _FeedbackSheetState();
}

class _FeedbackSheetState extends State<_FeedbackSheet> {
  int _rating = 0;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.textTertiary.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            widget.isHi ? 'आपका अनुभव कैसा रहा?' : 'How was your experience?',
            style: AppTypography.h3Subsection,
          ),
          const SizedBox(height: 4),
          Text(
            widget.actionLabel,
            style: AppTypography.bodySmall
                .copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) {
              final starIdx = i + 1;
              return GestureDetector(
                onTap: () => setState(() => _rating = starIdx),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Icon(
                    starIdx <= _rating ? Icons.star : Icons.star_border,
                    size: 36,
                    color: starIdx <= _rating
                        ? AppColors.brandOrange
                        : AppColors.textTertiary,
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _rating > 0
                  ? () => Navigator.pop(context, _rating)
                  : null,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.brandTeal,
                minimumSize: const Size.fromHeight(44),
              ),
              child: Text(widget.isHi ? 'भेजें' : 'Submit'),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              widget.isHi ? 'बाद में' : 'Not now',
              style: AppTypography.bodySmall
                  .copyWith(color: AppColors.textTertiary),
            ),
          ),
        ],
      ),
    );
  }
}

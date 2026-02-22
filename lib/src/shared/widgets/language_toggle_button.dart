import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/providers/locale_provider.dart';

class LanguageToggleButton extends ConsumerWidget {
  const LanguageToggleButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    final isHindi = locale.languageCode == 'hi';

    return GestureDetector(
      onTap: () {
        final newLang = isHindi ? 'en' : 'hi';
        ref.read(localeProvider.notifier).setLocale(newLang);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isHindi ? 'Language changed: English' : 'भाषा बदली: हिंदी',
            ),
            duration: const Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: AppColors.brandTeal.withValues(alpha: 0.12),
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Text(
            isHindi ? 'A' : 'अ',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.brandTeal,
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/providers/locale_provider.dart';
import '../../../../shared/widgets/tts_button.dart';

/// UX-3: Onboarding tutorial shown on first app launch.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  static const _seenKey = 'onboarding_seen';

  static Future<bool> hasBeenSeen() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_seenKey) ?? false;
  }

  static Future<void> markSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_seenKey, true);
  }

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _controller = PageController();
  int _currentPage = 0;
  String _selectedLang = 'hi'; // LANG-1: Default Hinglish/Hindi

  static const _pages = [
    _OnboardingPage(
      icon: Icons.local_shipping_rounded,
      color: AppColors.brandTeal,
      title: 'Post and Find Loads',
      titleHi: 'लोड पोस्ट करें और खोजें',
      subtitle: 'Suppliers post loads, truckers find them. Direct connection, no middlemen.',
      subtitleHi: 'सप्लायर लोड पोस्ट करें, ट्रकर खोजें। सीधा कनेक्शन, कोई बिचौलिया नहीं।',
      spokenEn: 'Suppliers post loads. Truckers find them. No middlemen.',
      spokenHi: 'सप्लायर लोड पोस्ट करते हैं। ट्रकर खोजते हैं। कोई बिचौलिया नहीं।',
    ),
    _OnboardingPage(
      icon: Icons.chat_bubble_rounded,
      color: AppColors.brandOrange,
      title: 'Chat and Negotiate',
      titleHi: 'चैट करें और बातचीत करें',
      subtitle: 'Real-time chat with deal proposals. Share truck details, RC, and location.',
      subtitleHi: 'रियल-टाइम चैट और डील प्रस्ताव। ट्रक विवरण, RC और लोकेशन साझा करें।',
      spokenEn: 'Chat in real time. Share truck details and location. Negotiate deals directly.',
      spokenHi: 'रियल-टाइम चैट करें। ट्रक विवरण और लोकेशन साझा करें। सीधे डील करें।',
    ),
    _OnboardingPage(
      icon: Icons.smart_toy_rounded,
      color: AppColors.info,
      title: 'Voice-First Bot',
      titleHi: 'वॉइस-फर्स्ट बॉट',
      subtitle: 'Speak in Hindi or English to post loads, find trucks, and get help instantly.',
      subtitleHi: 'हिंदी या अंग्रेजी में बोलकर लोड पोस्ट करें, ट्रक खोजें और तुरंत मदद पाएं।',
      spokenEn: 'Speak in Hindi or English. Post loads, find trucks, get help instantly.',
      spokenHi: 'हिंदी या अंग्रेजी में बोलें। लोड पोस्ट करें, ट्रक खोजें, तुरंत मदद पाएं।',
    ),
    _OnboardingPage(
      icon: Icons.verified_rounded,
      color: AppColors.success,
      title: 'Verified and Secure',
      titleHi: 'सत्यापित और सुरक्षित',
      subtitle: 'KYC verification, secure payments, and trip tracking for peace of mind.',
      subtitleHi: 'KYC सत्यापन, सुरक्षित भुगतान और ट्रिप ट्रैकिंग — पूरी सुरक्षा।',
      spokenEn: 'KYC verified. Secure payments. Trip tracking for peace of mind.',
      spokenHi: 'KYC सत्यापित। सुरक्षित भुगतान। ट्रिप ट्रैकिंग — पूरी सुरक्षा।',
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDone() async {
    // LANG-1: Persist selected language
    await ref.read(localeProvider.notifier).setLocale(_selectedLang);
    await OnboardingScreen.markSeen();
    if (mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _currentPage == _pages.length; // +1 for language page

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: SafeArea(
        child: Column(
          children: [
            // Top row: TTS speaker (left) + Skip (right)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TtsButton(
                    text: 'Read aloud',
                    spokenText: _currentPage == 0
                        ? (_selectedLang == 'hi'
                            ? 'अपनी भाषा चुनें। हिंदी या अंग्रेजी?'
                            : 'Choose your language. Hindi or English?')
                        : (_selectedLang == 'hi'
                            ? _pages[_currentPage - 1].spokenHi
                            : _pages[_currentPage - 1].spokenEn),
                    locale: _selectedLang == 'hi' ? 'hi-IN' : 'en-IN',
                    size: 22,
                  ),
                  TextButton(
                    onPressed: _onDone,
                    child: Text(
                      'Skip',
                      style: AppTypography.bodyMedium
                          .copyWith(color: AppColors.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
            // Pages: language selection (page 0) + feature pages
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _pages.length + 1, // +1 for language page
                onPageChanged: (i) => setState(() => _currentPage = i),
                itemBuilder: (_, i) {
                  if (i == 0) return _buildLanguagePage();
                  return _buildPage(_pages[i - 1]);
                },
              ),
            ),
            // Indicator
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: SmoothPageIndicator(
                controller: _controller,
                count: _pages.length + 1,
                effect: WormEffect(
                  dotHeight: 8,
                  dotWidth: 8,
                  activeDotColor: AppColors.brandTeal,
                  dotColor: AppColors.divider,
                ),
              ),
            ),
            // Next / Get Started button
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: isLast
                      ? _onDone
                      : () => _controller.nextPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          ),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.brandTeal,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    isLast ? 'Get Started' : 'Next',
                    style: AppTypography.buttonLarge
                        .copyWith(color: Colors.white),
                  ), // TTS-OB-4: localize in future ARB pass
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguagePage() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: AppColors.brandTeal.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.translate_rounded,
                size: 56, color: AppColors.brandTeal),
          ),
          const SizedBox(height: 40),
          Text('Choose Your Language',
              style: AppTypography.h2Section, textAlign: TextAlign.center),
          const SizedBox(height: 4),
          Text('अपनी भाषा चुनें',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center),
          const SizedBox(height: 32),
          _langOption('hi', 'हिंदी / Hinglish', 'Hindi and English mix'),
          const SizedBox(height: 12),
          _langOption('en', 'English', 'Pure English'),
        ],
      ),
    );
  }

  Widget _langOption(String code, String label, String subtitle) {
    final selected = _selectedLang == code;
    return GestureDetector(
      onTap: () => setState(() => _selectedLang = code),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.brandTeal.withValues(alpha: 0.08)
              : AppColors.cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.brandTeal : AppColors.divider,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: selected ? AppColors.brandTeal : AppColors.textTertiary,
            ),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: AppTypography.bodyLarge.copyWith(
                      fontWeight: FontWeight.w600,
                      color: selected
                          ? AppColors.brandTeal
                          : AppColors.textPrimary,
                    )),
                Text(subtitle,
                    style: AppTypography.caption
                        .copyWith(color: AppColors.textSecondary)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPage(_OnboardingPage page) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: page.color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(page.icon, size: 56, color: page.color),
          ),
          const SizedBox(height: 40),
          Text(
            page.title,
            style: AppTypography.h2Section,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            page.titleHi,
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            page.subtitle,
            style: AppTypography.bodyMedium
                .copyWith(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            page.subtitleHi,
            style: AppTypography.caption
                .copyWith(color: AppColors.textTertiary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _OnboardingPage {
  final IconData icon;
  final Color color;
  final String title;
  final String titleHi;
  final String subtitle;
  final String subtitleHi;
  final String spokenEn;
  final String spokenHi;

  const _OnboardingPage({
    required this.icon,
    required this.color,
    required this.title,
    required this.titleHi,
    required this.subtitle,
    required this.subtitleHi,
    required this.spokenEn,
    required this.spokenHi,
  });
}

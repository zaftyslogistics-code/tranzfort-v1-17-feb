import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'src/core/config/supabase_config.dart';
import 'src/core/theme/app_theme.dart';
import 'src/core/routing/app_router.dart';
import 'src/core/providers/locale_provider.dart';
import 'src/shared/widgets/ban_check_wrapper.dart';
import 'src/shared/widgets/connectivity_banner.dart';
import 'src/shared/widgets/error_boundary.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Prevent Google Fonts from fetching over network — use bundled/system fonts
  GoogleFonts.config.allowRuntimeFetching = false;

  // Global error widget builder for unhandled widget errors
  ErrorWidget.builder = ErrorBoundary.errorWidgetBuilder();

  // Lock to portrait
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Initialize Supabase
  await Supabase.initialize(
    url: SupabaseConfig.supabaseUrl,
    anonKey: SupabaseConfig.supabaseAnonKey,
  );

  runApp(const ProviderScope(child: TranZfortApp()));
}

class TranZfortApp extends ConsumerWidget {
  const TranZfortApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final locale = ref.watch(localeProvider);

    return MaterialApp.router(
      title: 'TranZfort',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      routerConfig: router,
      locale: locale,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en'),
        Locale('hi'),
      ],
      builder: (context, child) {
        return BanCheckWrapper(
          child: ConnectivityBanner(child: child ?? const SizedBox.shrink()),
        );
      },
    );
  }
}

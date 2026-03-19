import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/theme/enhanced_theme.dart';
import 'core/theme/theme_provider.dart';
import 'core/router/app_router.dart';
import 'core/network/api_client.dart';
import 'core/services/auth_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs      = await SharedPreferences.getInstance();
  final savedUrl   = prefs.getString('api_base_url');
  final savedTheme = prefs.getString('theme_mode');

  final initialTheme =
      savedTheme == 'dark' ? ThemeMode.dark : ThemeMode.light;

  runApp(ProviderScope(
    overrides: [
      if (savedUrl != null && savedUrl.isNotEmpty)
        baseUrlProvider.overrideWith((ref) => savedUrl),
      themeModeProvider
          .overrideWith((ref) => ThemeModeNotifier(initialTheme)),
    ],
    child: const _AppStartup(),
  ));
}

/// Restores the auth session from SharedPreferences before showing the app.
class _AppStartup extends ConsumerWidget {
  const _AppStartup();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder(
      future: ref.read(authServiceProvider).checkAuthStatus().timeout(
        const Duration(seconds: 5),
        onTimeout: () => false,
      ),
      builder: (_, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            home: Scaffold(
              backgroundColor: EnhancedTheme.primaryDark,
              body: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(color: EnhancedTheme.primaryTeal),
                    const SizedBox(height: 16),
                    Text('Loading...', style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 14)),
                  ],
                ),
              ),
            ),
          );
        }
        return const PharmApp();
      },
    );
  }
}

class PharmApp extends ConsumerWidget {
  const PharmApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router    = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'PharmApp',
      theme:      EnhancedTheme.enhancedLightTheme,
      darkTheme:  EnhancedTheme.enhancedDarkTheme,
      themeMode:  themeMode,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}

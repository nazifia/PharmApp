import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/enhanced_theme.dart';
import 'core/router/app_router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: PharmApp()));
}

class PharmApp extends ConsumerWidget {
  const PharmApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'PharmApp',
      theme: EnhancedTheme.enhancedLightTheme,
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: const ColorScheme.dark(
          primary: EnhancedTheme.primaryTeal,
          surface: EnhancedTheme.surfaceColor,
        ),
        scaffoldBackgroundColor: EnhancedTheme.primaryDark,
      ),
      themeMode: ThemeMode.dark,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppMode { development, production }

class AppModeNotifier extends StateNotifier<AppMode> {
  AppModeNotifier(super.initial);

  Future<void> switchTo(AppMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_mode', mode.name);
    state = mode;
  }
}

/// Provides the current [AppMode].
/// Override in [main] after loading from SharedPreferences.
final appModeProvider =
    StateNotifierProvider<AppModeNotifier, AppMode>(
        (ref) => AppModeNotifier(AppMode.development));

/// Convenience: true when running in dev (local SQLite) mode.
final isDevModeProvider =
    Provider<bool>((ref) => ref.watch(appModeProvider) == AppMode.development);

import 'package:flutter/material.dart';

/// Wraps the app root so it can be hot-restarted at runtime (native platforms).
///
/// Changing [_restartKey] forces Flutter to discard the old [ProviderScope] +
/// [PharmApp] subtree and build a fresh one — identical to a cold start.
/// The offline queue survives because it lives in SharedPreferences.
class AppRestartWrapper extends StatefulWidget {
  final Widget child;
  const AppRestartWrapper({super.key, required this.child});

  static _AppRestartWrapperState? _of(BuildContext context) =>
      context.findAncestorStateOfType<_AppRestartWrapperState>();

  /// Triggers a full rebuild of the [ProviderScope] + app widget tree.
  static void restart(BuildContext context) =>
      _of(context)?._restart();

  @override
  State<AppRestartWrapper> createState() => _AppRestartWrapperState();
}

class _AppRestartWrapperState extends State<AppRestartWrapper> {
  Key _restartKey = UniqueKey();

  void _restart() {
    setState(() => _restartKey = UniqueKey());
  }

  @override
  Widget build(BuildContext context) =>
      KeyedSubtree(key: _restartKey, child: widget.child);
}

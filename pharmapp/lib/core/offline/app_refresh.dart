import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Bump this counter from any screen's pull-to-refresh to signal AppShell
/// that a full sync + data refresh should happen.
///
/// AppShell listens to this and calls _syncIfNeeded(forceRefresh: true).
final appRefreshTriggerProvider = StateProvider<int>((ref) => 0);

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:isar/isar.dart';

import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'core/database/database_provider.dart';
import 'shared/models/item_entity.dart';
import 'shared/models/checkout_queue_entity.dart';
import 'core/sync/sync_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Isar for offline-first caching
  final dir = await getApplicationDocumentsDirectory();
  isarInstance = await Isar.open(
    [ItemEntitySchema, CheckoutQueueEntitySchema],
    directory: dir.path,
  );

  runApp(const ProviderScope(child: PharmApp()));
}

class PharmApp extends ConsumerWidget {
  const PharmApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Keep the Background Sync Worker alive globally
    ref.watch(syncServiceProvider);

    final router = ref.watch(routerProvider);
    
    return MaterialApp.router(
      title: 'PharmApp',
      theme: AppTheme.lightTheme,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}

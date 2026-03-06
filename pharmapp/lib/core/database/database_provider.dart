import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';

// Late initialized in main() during startup before runApp
late Isar isarInstance;

// Exposes the singleton pattern of Isar to Riverpod for injection
final isarProvider = Provider<Isar>((ref) => isarInstance);

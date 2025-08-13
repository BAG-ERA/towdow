// Storage-related providers
// Exposes LocalStorageService provider

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/storage/local_storage_service.dart';

// Local storage service provider
// This must be overridden in main.dart with an initialized instance
final localStorageServiceProvider = Provider<LocalStorageService>((ref) {
  throw UnimplementedError(
    'LocalStorageService must be provided via ProviderScope override in main.dart',
  );
});



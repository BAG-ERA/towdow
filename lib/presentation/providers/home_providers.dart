// Riverpod providers for Home screen
// Provides simple state management without ViewModel

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provider for current selected tab index
final selectedTabIndexProvider = StateProvider<int>((ref) => 0);

/// Provider for checking if any commands are executing  
final isAnyCommandExecutingProvider = Provider<bool>((ref) {
  // Pour l'instant, retourne false
  // On peut ajouter la logique des commands plus tard si nécessaire
  return false;
}); 

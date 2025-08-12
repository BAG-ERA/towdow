// ViewModel for appearance settings (theme mode and font scaling)
// Encapsulates logic to read/write user preferences via UserRepository

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/logger.dart';
import '../../data/providers/providers.dart';
import '../../data/repositories/user_repository.dart';

class AppearanceSettingsState {
  final ThemeMode themeMode;
  final double fontScale;

  const AppearanceSettingsState({
    required this.themeMode,
    required this.fontScale,
  });
}

class AppearanceSettingsViewModel extends StateNotifier<AppearanceSettingsState> {
  AppearanceSettingsViewModel(this._userRepository)
      : super(const AppearanceSettingsState(themeMode: ThemeMode.system, fontScale: 1.0));

  final UserRepository _userRepository;

  Future<void> initialize() async {
    final prefsResult = await _userRepository.getUserPreferences();
    prefsResult.when(
      success: (prefs) {
        state = AppearanceSettingsState(
          themeMode: _mapPreferredThemeToThemeMode(prefs.preferredTheme),
          fontScale: _mapFontScaleToFactor(prefs.fontScale),
        );
      },
      failure: (failure) {
        AppLogger.warning('AppearanceSettingsViewModel: Using defaults due to error: ${failure.message}');
      },
    );
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    final prefsResult = await _userRepository.getUserPreferences();
    await prefsResult.when(
      success: (prefs) async {
        final updated = prefs.copyWith(preferredTheme: _mapThemeModeToPreferredTheme(mode));
        final res = await _userRepository.saveUserPreferences(updated);
        res.when(
          success: (_) => state = AppearanceSettingsState(themeMode: mode, fontScale: state.fontScale),
          failure: (f) => AppLogger.error('AppearanceSettingsViewModel: Failed to save theme mode: ${f.message}'),
        );
      },
      failure: (f) async => AppLogger.error('AppearanceSettingsViewModel: Failed to load prefs: ${f.message}'),
    );
  }

  Future<void> setFontScale(String scaleKey) async {
    final factor = _mapFontScaleToFactor(scaleKey);
    final prefsResult = await _userRepository.getUserPreferences();
    await prefsResult.when(
      success: (prefs) async {
        final updated = prefs.copyWith(fontScale: scaleKey);
        final res = await _userRepository.saveUserPreferences(updated);
        res.when(
          success: (_) => state = AppearanceSettingsState(themeMode: state.themeMode, fontScale: factor),
          failure: (f) => AppLogger.error('AppearanceSettingsViewModel: Failed to save font scale: ${f.message}'),
        );
      },
      failure: (f) async => AppLogger.error('AppearanceSettingsViewModel: Failed to load prefs: ${f.message}'),
    );
  }

  static ThemeMode _mapPreferredThemeToThemeMode(String? preferredTheme) {
    switch (preferredTheme) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      case 'system':
      default:
        return ThemeMode.system;
    }
  }

  static String _mapThemeModeToPreferredTheme(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
        return 'system';
    }
  }

  static double _mapFontScaleToFactor(String? scaleKey) {
    switch (scaleKey) {
      case 'small':
        return 0.9;
      case 'large':
        return 1.15;
      case 'medium':
      default:
        return 1.0;
    }
  }
}

final appearanceSettingsViewModelProvider =
    StateNotifierProvider<AppearanceSettingsViewModel, AppearanceSettingsState>((ref) {
  final repo = ref.watch(userRepositoryProvider);
  final vm = AppearanceSettingsViewModel(repo);
  // Fire and forget initialization
  vm.initialize();
  return vm;
});

// Convenience providers for direct usage in widgets
final themeModeProvider = Provider<ThemeMode>((ref) {
  return ref.watch(appearanceSettingsViewModelProvider).themeMode;
});

final fontScaleProvider = Provider<double>((ref) {
  return ref.watch(appearanceSettingsViewModelProvider).fontScale;
});



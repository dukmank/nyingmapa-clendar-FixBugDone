import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Cached SharedPreferences instance — avoids redundant async calls from
/// ThemeNotifier, AppLanguageNotifier, HighContrastNotifier, etc.
Completer<SharedPreferences>? _sharedPrefsCompleter;
Future<SharedPreferences> _getPrefs() {
  if (_sharedPrefsCompleter == null) {
    _sharedPrefsCompleter = Completer<SharedPreferences>();
    SharedPreferences.getInstance().then(
      (prefs) => _sharedPrefsCompleter!.complete(prefs),
      onError: (e) => _sharedPrefsCompleter!.completeError(e),
    );
  }
  return _sharedPrefsCompleter!.future;
}

// ============ App Language State ============

class AppLanguageNotifier extends StateNotifier<String> {
  AppLanguageNotifier() : super('en') {
    _loadLanguage();
  }

  Future<void> _loadLanguage() async {
    final prefs = await _getPrefs();
    state = prefs.getString('language') ?? 'en';
  }

  Future<void> setLanguage(String lang) async {
    state = lang;
    final prefs = await _getPrefs();
    await prefs.setString('language', lang);
  }

  bool get isTibetan => state == 'bo';
}

/// Language provider — triggers rebuild when language changes
final languageProvider = StateNotifierProvider<AppLanguageNotifier, String>((ref) {
  return AppLanguageNotifier();
});

// ============ Theme State ============

class ThemeNotifier extends StateNotifier<ThemeMode> {
  ThemeNotifier() : super(ThemeMode.light) {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await _getPrefs();
    state = (prefs.getBool('darkMode') ?? false) ? ThemeMode.dark : ThemeMode.light;
  }

  Future<void> toggleTheme() async {
    state = state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    final prefs = await _getPrefs();
    await prefs.setBool('darkMode', state == ThemeMode.dark);
  }

  bool get isDark => state == ThemeMode.dark;
}

final themeNotifierProvider = StateNotifierProvider<ThemeNotifier, ThemeMode>((ref) {
  return ThemeNotifier();
});

// ============ High Contrast ============

class HighContrastNotifier extends StateNotifier<bool> {
  HighContrastNotifier() : super(false) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await _getPrefs();
    state = prefs.getBool('highContrast') ?? false;
  }

  Future<void> toggle() async {
    state = !state;
    final prefs = await _getPrefs();
    await prefs.setBool('highContrast', state);
  }
}

final highContrastProvider = StateNotifierProvider<HighContrastNotifier, bool>((ref) {
  return HighContrastNotifier();
});

// ============ Onboarding ============

class OnboardingNotifier extends StateNotifier<bool> {
  OnboardingNotifier() : super(false) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await _getPrefs();
    state = prefs.getBool('onboarding_complete') ?? false;
  }

  Future<void> setComplete() async {
    state = true;
    final prefs = await _getPrefs();
    await prefs.setBool('onboarding_complete', true);
  }
}

final onboardingProvider = StateNotifierProvider<OnboardingNotifier, bool>((ref) {
  return OnboardingNotifier();
});

// ============ Legacy ThemeService (for backward compat) ============
// Some screens still reference this — keep a bridge

class ThemeService {
  ThemeMode _themeMode = ThemeMode.light;
  bool _highContrast = false;
  String _language = 'en';

  final _themeModeController = StreamController<ThemeMode>.broadcast();

  Stream<ThemeMode> get themeModeStream => _themeModeController.stream;

  ThemeService() {
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await _getPrefs();
    _themeMode = (prefs.getBool('darkMode') ?? false) ? ThemeMode.dark : ThemeMode.light;
    _highContrast = prefs.getBool('highContrast') ?? false;
    _language = prefs.getString('language') ?? 'en';
    _themeModeController.add(_themeMode);
  }

  Future<void> toggleTheme() async {
    _themeMode = isDark ? ThemeMode.light : ThemeMode.dark;
    final prefs = await _getPrefs();
    await prefs.setBool('darkMode', isDark);
    _themeModeController.add(_themeMode);
  }

  Future<void> toggleHighContrast() async {
    _highContrast = !_highContrast;
    final prefs = await _getPrefs();
    await prefs.setBool('highContrast', _highContrast);
  }

  Future<void> setLanguage(String lang) async {
    _language = lang;
    final prefs = await _getPrefs();
    await prefs.setString('language', lang);
  }

  Future<void> setOnboardingComplete() async {
    final prefs = await _getPrefs();
    await prefs.setBool('onboarding_complete', true);
  }

  Future<bool> isOnboardingComplete() async {
    final prefs = await _getPrefs();
    return prefs.getBool('onboarding_complete') ?? false;
  }

  bool get isDark => _themeMode == ThemeMode.dark;
  bool get highContrast => _highContrast;
  String get language => _language;
  bool get isTibetan => _language == 'bo';
}

final themeServiceProvider = Provider<ThemeService>((ref) => ThemeService());

final themeModeProvider = StreamProvider<ThemeMode>((ref) async* {
  final service = ref.watch(themeServiceProvider);
  yield* service.themeModeStream;
});

final onboardingCompleteProvider = StreamProvider<bool>((ref) async* {
  yield false;
});

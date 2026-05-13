import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Estado global de tema da aplicação.
///
/// Centraliza o [ThemeMode] para toda a árvore de widgets por meio de
/// [ValueNotifier], permitindo alternância imediata sem rebuild completo do app.
/// Persiste a preferência em SharedPreferences.
class AtrThemeState {
  static const _themeKey = 'atr_theme_mode';
  static final notifier = ValueNotifier<ThemeMode>(ThemeMode.dark);

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_themeKey);
    if (stored == 'light') {
      notifier.value = ThemeMode.light;
    } else if (stored == 'dark') {
      notifier.value = ThemeMode.dark;
    }
  }

  static Future<void> setTheme(ThemeMode mode) async {
    notifier.value = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeKey, mode == ThemeMode.light ? 'light' : 'dark');
  }

  static Future<void> toggleTheme() async {
    await setTheme(
      notifier.value == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark,
    );
  }
}

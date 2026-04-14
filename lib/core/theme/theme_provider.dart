import 'package:flutter/material.dart';
import 'atr_theme_state.dart';

/// Compat layer para código legado.
///
/// Mantém API estática existente, mas delega ao estado único em [AtrThemeState]
/// para evitar múltiplos notifiers de tema em paralelo.
class ThemeProvider {
  static ValueNotifier<ThemeMode> get notifier => AtrThemeState.notifier;

  static void setTheme(ThemeMode mode) {
    AtrThemeState.setTheme(mode);
  }

  static void toggleTheme() {
    AtrThemeState.toggleTheme();
  }
}

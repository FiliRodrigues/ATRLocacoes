import 'package:flutter/material.dart';

/// Estado global de tema da aplicação.
///
/// Centraliza o [ThemeMode] para toda a árvore de widgets por meio de
/// [ValueNotifier], permitindo alternância imediata sem rebuild completo do app.
class AtrThemeState {
  static final notifier = ValueNotifier<ThemeMode>(ThemeMode.dark);

  static void setTheme(ThemeMode mode) {
    notifier.value = mode;
  }

  static void toggleTheme() {
    notifier.value = notifier.value == ThemeMode.dark
        ? ThemeMode.light
        : ThemeMode.dark;
  }
}

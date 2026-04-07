import 'dart:developer' as dev;
import 'package:flutter/foundation.dart';

/// Sistema de Log Corporativo ATR
/// Centraliza a visualização de erros e eventos importantes.
class AppLogger {
  static void info(String message) {
    _log('INFO', message);
  }

  static void success(String message) {
    _log('SUCCESS', '✅ $message');
  }

  static void warning(String message) {
    _log('WARNING', '⚠️ $message');
  }

  static void error(String message, [dynamic error, StackTrace? stackTrace]) {
    _log('ERROR', '❌ $message', isError: true);
    if (error != null) {
      dev.log('Details: $error', name: 'ATR_SYSTEM');
    }
    if (stackTrace != null) {
      dev.log('Stack: $stackTrace', name: 'ATR_SYSTEM');
    }
  }

  static void _log(String level, String message, {bool isError = false}) {
    if (kDebugMode) {
      final time = DateTime.now().toString().split(' ').last.split('.').first;
      dev.log('[$time] [$level] $message', name: 'ATR_SYSTEM');
    }
  }
}

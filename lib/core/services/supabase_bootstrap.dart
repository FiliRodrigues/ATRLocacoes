import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';
import '../utils/app_logger.dart';

class SupabaseBootstrap {
  static bool _initialized = false;

  static bool get isReady => _initialized && AppConfig.hasSupabaseConfig;

  static SupabaseClient? get client => isReady ? Supabase.instance.client : null;

  static Future<void> initialize() async {
    if (_initialized || !AppConfig.hasSupabaseConfig) {
      if (!AppConfig.hasSupabaseConfig) {
        AppLogger.warning(
          'Supabase não configurado. O app continuará usando os dados locais até receber SUPABASE_URL ou SUPABASE_PROJECT_REF e SUPABASE_PUBLISHABLE_KEY ou SUPABASE_ANON_KEY.',
        );
      }
      return;
    }

    try {
      await Supabase.initialize(
        url: AppConfig.supabaseUrl,
        anonKey: AppConfig.supabaseKey,
      );
      _initialized = true;
      AppLogger.success('Supabase inicializado com sucesso.');
    } catch (error, stackTrace) {
      AppLogger.error(
        'Falha ao inicializar Supabase.',
        error,
        stackTrace,
      );
    }
  }
}
class AppConfig {
  static const String _supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const String _supabaseProjectRef = String.fromEnvironment('SUPABASE_PROJECT_REF');
  static const String _supabasePublishableKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
  static const String _supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  static String get supabaseUrl {
    if (_supabaseUrl.isNotEmpty) {
      return _supabaseUrl;
    }
    if (_supabaseProjectRef.isNotEmpty) {
      return 'https://$_supabaseProjectRef.supabase.co';
    }
    return '';
  }

  static String get supabaseKey {
    if (_supabasePublishableKey.isNotEmpty) {
      return _supabasePublishableKey;
    }
    return _supabaseAnonKey;
  }

  static bool get hasSupabaseConfig =>
      supabaseUrl.isNotEmpty && supabaseKey.isNotEmpty;
}
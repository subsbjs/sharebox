class AppConfig {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static const storageBucket = 'sharebox';
  static const maxImageBytes = 20 * 1024 * 1024;

  static const maxFileBytes = 50 * 1024 * 1024;

  static bool get isConfigured =>
      supabaseUrl.trim().isNotEmpty && supabaseAnonKey.trim().isNotEmpty;
}

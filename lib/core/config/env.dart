/// Values passed at build time with --dart-define-from-file=config/dev.json
class Env {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  static void check() {
    if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
      throw StateError(
        'Missing Supabase config. Run with --dart-define-from-file=config/dev.json',
      );
    }
    if (supabaseUrl.contains('YOUR-PROJECT-ID') || supabaseAnonKey.startsWith('YOUR-')) {
      throw StateError(
        'config/dev.json still has the example values. '
        'Put in your Supabase Project URL and anon (publishable) key.',
      );
    }
  }
}

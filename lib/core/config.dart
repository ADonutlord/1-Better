/// App-level configuration.
///
/// These values point at the shared Supabase project used by both the Android
/// and Linux builds. The publishable key is safe to ship in a client app.
library;

class AppConfig {
  AppConfig._();

  static const String supabaseUrl = 'https://jkipantmyzhwyplmzfvh.supabase.co';
  static const String supabaseAnonKey =
      'sb_publishable_AN_b61tGAq9HWZfWZ_WJRA_dvepbzX9';
}

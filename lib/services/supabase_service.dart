import 'package:one_percent_better/core/config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Thin wrapper around the shared Supabase client.
class SupabaseService {
  SupabaseService._();

  static final SupabaseService instance = SupabaseService._();

  SupabaseClient get client => Supabase.instance.client;

  Future<void> initialize() async {
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      publishableKey: AppConfig.supabaseAnonKey,
      debug: false,
    );
  }
}

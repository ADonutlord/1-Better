import 'package:one_percent_better/services/supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// XP-related operations (focus timer rewards and profile refresh).
class XpService {
  XpService._();

  static final XpService instance = XpService._();

  SupabaseClient get _client => SupabaseService.instance.client;

  /// Awards +15 XP once per day for finishing a focus session.
  Future<Map<String, dynamic>> awardFocusXp() async {
    return await _client.rpc('add_focus_xp');
  }

  /// Whether the focus XP has already been claimed today.
  Future<bool> hasFocusXpTodaay() async {
    final userId = _client.auth.currentUser!.id;
    final rows = await _client
        .from('xp_events')
        .select('id')
        .eq('user_id', userId)
        .eq('event_type', 'focus')
        .gte('created_at', DateTime.now().toUtc().subtract(const Duration(hours: 24)).toIso8601String())
        .limit(1);
    return rows.isNotEmpty;
  }
}

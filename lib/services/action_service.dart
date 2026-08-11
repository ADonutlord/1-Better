import 'package:one_percent_better/logic/action_recommender.dart';
import 'package:one_percent_better/models/models.dart';
import 'package:one_percent_better/services/supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Fetching the action library, personalization and daily assignment.
class ActionService {
  ActionService._();

  static final ActionService instance = ActionService._();

  SupabaseClient get _client => SupabaseService.instance.client;
  final ActionRecommender _recommender = ActionRecommender();

  Future<List<AppAction>> fetchActions() async {
    final rows = await _client
        .from('actions')
        .select('*')
        .eq('active', true)
        .order('title');
    return rows.map((r) => AppAction.fromJson(r)).toList();
  }

  Future<List<AppAction>> fetchActionsByCategory(String category) async {
    final rows = await _client
        .from('actions')
        .select('*')
        .eq('active', true)
        .eq('category', category)
        .order('title');
    return rows.map((r) => AppAction.fromJson(r)).toList();
  }

  Future<List<ActionHistory>> fetchHistory({int limit = 200}) async {
    final rows = await _client
        .from('action_history')
        .select('*, action:actions(*)')
        .order('assigned_at', ascending: false)
        .limit(limit);
    return rows.map((r) => ActionHistory.fromJson(r)).toList();
  }

  /// The daily loop bundle: profile, today's progress, today's action, mood.
  Future<DailyLoop> fetchDailyLoop() async {
    final data = await _client.rpc('get_daily_loop');
    return DailyLoop.fromJson(data);
  }

  /// Checks the user in with a mood (+ optional situations).
  Future<void> checkInMood(String mood, List<String> situations) async {
    await _client.rpc('check_in_mood', params: {
      'p_mood': mood,
      'p_situations': situations,
    });
  }

  /// Picks today's action with the recommender and assigns it server-side.
  Future<ActionHistory> ensureDailyAction({
    required DailyLoop loop,
    required List<AppAction> actions,
    required List<ActionHistory> history,
  }) async {
    final today = loop.todayAction;
    if (today != null) return today;

    final selected = _recommender.recommend(
      actions: actions,
      mood: loop.latestMood?.mood,
      situations: loop.latestMood?.situation ?? const [],
      history: history,
    );

    final data = await _client.rpc(
      'assign_daily_action',
      params: {'p_action_id': selected.id},
    );
    return ActionHistory.fromJson(data);
  }

  /// Recommend an action for scoring/UI preview (no server write).
  AppAction recommend({
    required List<AppAction> actions,
    String? mood,
    List<String> situations = const [],
    required List<ActionHistory> history,
  }) {
    return _recommender.recommend(
      actions: actions,
      mood: mood,
      situations: situations,
      history: history,
    );
  }

  /// Marks today's action complete via the server (validates + awards XP).
  Future<Map<String, dynamic>> completeDailyAction() async {
    return await _client.rpc('complete_daily_action');
  }

  /// A peer recommends an action for the other person in an active conversation.
  Future<void> recommendActionForUser({
    required String conversationId,
    required String actionId,
    required String userId,
  }) async {
    await _client.rpc('recommend_action', params: {
      'p_conversation_id': conversationId,
      'p_action_id': actionId,
      'p_user_id': userId,
    });
  }
}

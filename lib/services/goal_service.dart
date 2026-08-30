import 'package:one_percent_better/models/models.dart';
import 'package:one_percent_better/services/supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Manages the user's goal tree: a lifetime goal broken into yearly, monthly
/// and daily actionable tasks, stored in the self-referencing `goals` table.
///
/// Reads go through direct selects (RLS confines them to the caller's own
/// rows); all writes go through SECURITY DEFINER RPCs.
class GoalService {
  GoalService._();

  static final GoalService instance = GoalService._();

  SupabaseClient get _client => SupabaseService.instance.client;

  /// Fetches all of the caller's goals as a flat list ordered by creation.
  Future<List<Goal>> _fetchFlat() async {
    final rows = await _client
        .from('goals')
        .select()
        .order('created_at', ascending: true);
    return rows.map(Goal.fromJson).toList();
  }

  /// Fetches the caller's goals and nests them into a tree. The returned list
  /// contains the top-level (lifetime) goals, each with its children populated
  /// recursively.
  Future<List<Goal>> fetchGoals() async {
    final flat = await _fetchFlat();
    final byParent = <String?, List<Goal>>{};
    for (final g in flat) {
      byParent.putIfAbsent(g.parentGoalId, () => []).add(g);
    }

    Goal build(Goal g) {
      final kids = byParent[g.id] ?? const <Goal>[];
      return Goal(
        id: g.id,
        parentGoalId: g.parentGoalId,
        level: g.level,
        title: g.title,
        description: g.description,
        completed: g.completed,
        createdAt: g.createdAt,
        children: kids.map(build).toList(),
      );
    }

    return (byParent[null] ?? const <Goal>[]).map(build).toList();
  }

  /// Creates a top-level lifetime goal, returns its id.
  Future<void> createGoal({
    required String title,
    String description = '',
  }) async {
    await _client.rpc('create_goal', params: {
      'p_title': title,
      'p_description': description,
    });
  }

  /// Creates a sub-goal under [parentId] at the next level down.
  Future<void> createChildGoal({
    required String parentId,
    required String title,
    String description = '',
  }) async {
    await _client.rpc('create_goal_child', params: {
      'p_parent_goal_id': parentId,
      'p_title': title,
      'p_description': description,
    });
  }

  Future<void> updateGoal({
    required String id,
    required String title,
    String? description,
  }) async {
    await _client.rpc('update_goal', params: {
      'p_goal_id': id,
      'p_title': title,
      'p_description': description,
    });
  }

  Future<void> setCompleted(String id, bool completed) async {
    await _client.rpc('set_goal_completed', params: {
      'p_goal_id': id,
      'p_completed': completed,
    });
  }

  Future<void> deleteGoal(String id) async {
    await _client.rpc('delete_goal', params: {'p_goal_id': id});
  }
}

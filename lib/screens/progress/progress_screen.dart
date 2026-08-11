import 'package:flutter/material.dart';

import '../../core/app_state.dart';
import '../../logic/level_calculator.dart';
import '../../models/models.dart';
import '../../services/action_service.dart';
import '../../services/supabase_service.dart';
import '../../widgets/xp_bar.dart';

/// LEVEL / XP / streak / statistics / recent 1% history.
class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  final AppState _app = AppState.instance;
  int _actionsCompleted = 0;
  int _focusSessions = 0;
  int _chats = 0;
  List<ActionHistory> _recent = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final client = SupabaseService.instance.client;
    final me = _app.user!.id;
    try {
      final done = await client
          .from('action_history')
          .select('id')
          .eq('user_id', me)
          .eq('completed', true);
      final focus = await client
          .from('xp_events')
          .select('id')
          .eq('user_id', me)
          .eq('event_type', 'focus');
      final chats = await client
          .from('xp_events')
          .select('id')
          .eq('user_id', me)
          .inFilter('event_type', ['chat_complete']);
      final history = await ActionService.instance.fetchHistory(limit: 30);
      if (!mounted) return;
      setState(() {
        _actionsCompleted = (done as List).length;
        _focusSessions = (focus as List).length;
        _chats = (chats as List).length;
        _recent = history.where((h) => h.completed).toList();
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final profile = _app.loop?.profile;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Progress'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
        ],
      ),
      body: profile == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(22),
                    child: XpBar(totalXp: profile.totalXp),
                  ),
                ),
                const SizedBox(height: 14),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(22),
                    child: Row(
                      children: [
                        const Text('🔥', style: TextStyle(fontSize: 30)),
                        const SizedBox(width: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${profile.currentStreak} DAY STREAK',
                                style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFFE8590C))),
                            const SizedBox(height: 4),
                            Text('Best streak: ${profile.longestStreak} days',
                                style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                if (_loading)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else ...[
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(22),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('STATISTICS',
                              style: theme.textTheme.labelLarge?.copyWith(
                                  letterSpacing: 1.1, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 14),
                          _statRow('🌱', '$_actionsCompleted',
                              'actions completed'),
                          _statRow('⏱️', '$_focusSessions', 'focus sessions'),
                          _statRow('💬', '$_chats', 'conversations'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text('RECENT 1% COMPLETIONS',
                      style: theme.textTheme.labelLarge?.copyWith(
                          letterSpacing: 1.1, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 10),
                  if (_recent.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: Text('Complete your first 1% to see history here.'),
                      ),
                    )
                  else
                    for (final h in _recent) _HistoryTile(history: h),
                ],

                const SizedBox(height: 12),
                Center(
                  child: Text(
                    LevelCalculator.levelForXp(profile.totalXp) >= 5
                        ? 'Keep going — your growth is compounding. 🌱'
                        : 'Your progress is still here. Start again today.',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _statRow(String emoji, String value, String label) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 14),
          Text(value,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(width: 8),
          Text(label,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.history});

  final ActionHistory history;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final action = history.action;
    final title = action?.title ?? '1% action';
    final xp = history.xpEarned;
    final date = history.completedAt ?? history.assignedAt;

    return Card(
      child: ListTile(
        leading: const Icon(Icons.check_circle, color: Color(0xFF2E5C3A)),
        title: Text(title,
            style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text('${_day(date)} · ${history.source}'),
        trailing: Text('+$xp XP',
            style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.primary, fontWeight: FontWeight.w800)),
      ),
    );
  }

  static String _day(DateTime t) {
    final d = t.toLocal();
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${d.day} ${months[d.month - 1]}';
  }
}

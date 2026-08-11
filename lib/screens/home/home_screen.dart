import 'package:flutter/material.dart';

import '../../core/app_state.dart';
import '../../models/models.dart';
import '../../services/action_service.dart';
import '../../widgets/action_card.dart';
import '../../widgets/xp_bar.dart';
import '../focus/focus_timer_screen.dart';
import '../home/mood_screen.dart';
import '../profile/urgent_help_screen.dart';
import 'talk_to_someone_flow.dart';

/// The main daily loop screen.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AppState _app = AppState.instance;
  bool _preparing = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    if (_app.loop == null) {
      await _app.loadDailyLoop();
    }
    if (!mounted) return;
    // Ensure today's 1% exists (assign via the recommender if missing).
    if (_app.loop?.todayAction == null) {
      await _ensureDailyAction();
    }
  }

  Future<void> _ensureDailyAction() async {
    if (_preparing) return;
    setState(() => _preparing = true);
    try {
      final actions = await ActionService.instance.fetchActions();
      final history = await ActionService.instance.fetchHistory();
      final loop = _app.loop;
      if (loop != null) {
        await ActionService.instance.ensureDailyAction(
          loop: loop,
          actions: actions,
          history: history,
        );
      }
      await _app.loadDailyLoop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not prepare today\'s 1%: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _preparing = false);
    }
  }

  Future<void> _checkInMood() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const MoodScreen()),
    );
    if (result == true) {
      await _app.loadDailyLoop();
      await _ensureDailyAction();
    }
  }

  Future<void> _completeAction(AppAction action) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Complete your 1%?'),
        content: Text(
            '"${action.title}" — small step, real progress.\n\nTake a moment to actually do it.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Not yet'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Done it 🌱'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final result = await ActionService.instance.completeDailyAction();
      await _app.loadDailyLoop();
      if (!mounted) return;
      showDialog<void>(
        context: context,
        builder: (context) => _CompletionDialog(result: result),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
      await _app.loadDailyLoop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _app,
      builder: (context, _) {
        final loop = _app.loop;
        if (loop == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return Scaffold(
          appBar: AppBar(
            title: const Text('1% Better 🌱'),
            actions: [
              IconButton(
                tooltip: 'Focus timer',
                icon: const Icon(Icons.timer_outlined),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const FocusTimerScreen()),
                ),
              ),
              IconButton(
                tooltip: 'I need urgent help',
                icon: const Icon(Icons.emergency_outlined),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const UrgentHelpScreen()),
                ),
              ),
            ],
          ),
          body: _HomeBody(
            loop: loop,
            preparing: _preparing,
            onMoodTap: _checkInMood,
            onEnsureAction: _ensureDailyAction,
            onCompleteAction: _completeAction,
            onTalk: _openTalk,
          ),
        );
      },
    );
  }

  Future<void> _openTalk() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const TalkToSomeoneFlow()),
    );
    await _app.loadDailyLoop();
  }
}

class _HomeBody extends StatelessWidget {
  const _HomeBody({
    required this.loop,
    required this.preparing,
    required this.onMoodTap,
    required this.onEnsureAction,
    required this.onCompleteAction,
    required this.onTalk,
  });

  final DailyLoop loop;
  final bool preparing;
  final VoidCallback onMoodTap;
  final VoidCallback onEnsureAction;
  final ValueChanged<AppAction> onCompleteAction;
  final VoidCallback onTalk;

  @override
  Widget build(BuildContext context) {
    final profile = loop.profile;
    final todayAction = loop.todayAction?.action;
    final progress = loop.dailyProgress;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        Text(
          '${greeting()}, ${profile.displayName} 👋',
          style: Theme.of(context)
              .textTheme
              .headlineSmall
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        Text(
          'One small step is enough today.',
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 16),

        // Mood check-in card
        _MoodCard(loop: loop, onTap: onMoodTap),

        const SizedBox(height: 16),

        // Talk to someone card
        _TalkCard(onTap: onTalk),

        const SizedBox(height: 16),

        // Today's 1%
        _TodayActionCard(
          loop: loop,
          action: todayAction,
          preparing: preparing,
          onEnsureAction: onEnsureAction,
          onCompleteAction: onCompleteAction,
        ),

        const SizedBox(height: 16),

        // Progress summary
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                XpBar(totalXp: profile.totalXp, compact: true),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _stat(profile.currentStreak, '🔥 streak', Theme.of(context)),
                    _stat(profile.level, '🌱 level', Theme.of(context)),
                    _stat(profile.totalXp, '⭐ xp', Theme.of(context)),
                  ],
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Daily loop checklist
        _DailyChecklist(progress: progress),
      ],
    );
  }

  Widget _stat(int value, String label, ThemeData theme) {
    return Column(
      children: [
        Text('$value',
            style: theme.textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w800)),
        Text(label,
            style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant)),
      ],
    );
  }

  static String greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 18) return 'Good afternoon';
    return 'Good evening';
  }
}

class _MoodCard extends StatelessWidget {
  const _MoodCard({required this.loop, required this.onTap});

  final DailyLoop loop;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mood = loop.latestMood;
    final done = loop.dailyProgress?.moodCompleted ?? false;

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('How are you feeling?',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  const Spacer(),
                  if (done)
                    Icon(Icons.check_circle,
                        color: theme.colorScheme.primary, size: 20),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (final key in [
                    'great', 'good', 'okay', 'low', 'stressed',
                  ])
                    _emoji(key, mood?.mood == key, theme),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _emoji(String key, bool selected, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: selected
            ? theme.colorScheme.primaryContainer
            : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '${MoodEmoji.forKey(key)}\n${MoodEmoji.label(key)}',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 18,
          fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
          color: selected
              ? theme.colorScheme.primary
              : theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _TalkCard extends StatelessWidget {
  const _TalkCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.primaryContainer,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.support_agent,
                    color: Colors.white, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('💬 Talk to someone',
                        style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: theme.colorScheme.primary)),
                    const SizedBox(height: 4),
                    Text(
                      'Connect privately with a real person who can listen.',
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onPrimaryContainer),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: theme.colorScheme.primary),
            ],
          ),
        ),
      ),
    );
  }
}

class _TodayActionCard extends StatelessWidget {
  const _TodayActionCard({
    required this.loop,
    required this.action,
    required this.preparing,
    required this.onEnsureAction,
    required this.onCompleteAction,
  });

  final DailyLoop loop;
  final AppAction? action;
  final bool preparing;
  final VoidCallback onEnsureAction;
  final ValueChanged<AppAction> onCompleteAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final completed = loop.dailyProgress?.actionCompleted ?? false;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('🌱 Your 1% today',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800)),
                if (loop.todayAction?.source == 'peer') ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text('recommended by a peer',
                        style: TextStyle(
                            fontSize: 11,
                            color: theme.colorScheme.onPrimaryContainer)),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            if (action == null)
              _ActionEmpty(preparing: preparing, onTap: onEnsureAction)
            else if (completed)
              _ActionDone(action: action!)
            else ...[
              ActionCard(action: action!, supportsTap: false),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => onCompleteAction(action!),
                  icon: const Icon(Icons.check),
                  label: const Text('Complete your 1%'),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Your progress is still here — no pressure, just do it when you can.',
                style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ActionEmpty extends StatelessWidget {
  const _ActionEmpty({required this.preparing, required this.onTap});

  final bool preparing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          'Get today\'s personalized 1% action — picked for how you feel.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton.tonal(
            onPressed: preparing ? null : onTap,
            child: preparing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2.2),
                  )
                : const Text('Get my 1%'),
          ),
        ),
      ],
    );
  }
}

class _ActionDone extends StatelessWidget {
  const _ActionDone({required this.action});

  final AppAction action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(Icons.celebration_outlined,
              color: theme.colorScheme.onPrimaryContainer, size: 36),
          const SizedBox(height: 10),
          Text('Today\'s 1% done — “${action.title}”.',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(
            'Come back tomorrow for a new one. Small help, big impact.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _DailyChecklist extends StatelessWidget {
  const _DailyChecklist({required this.progress});

  final DailyProgress? progress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mood = progress?.moodCompleted ?? false;
    final talk = progress?.conversationCompleted ?? false;
    final action = progress?.actionCompleted ?? false;

    Widget row(IconData icon, String label, bool done) {
      return Row(
        children: [
          Icon(
            done ? Icons.check_circle : Icons.circle_outlined,
            size: 18,
            color: done ? theme.colorScheme.primary : theme.colorScheme.outline,
          ),
          const SizedBox(width: 10),
          Text(label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: done
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
                fontWeight: done ? FontWeight.w700 : FontWeight.w500,
                decoration: done ? TextDecoration.lineThrough : null,
              )),
        ],
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('TODAY',
                style: theme.textTheme.labelLarge
                    ?.copyWith(letterSpacing: 1.2, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            row(Icons.mood_outlined, 'Mood check-in', mood),
            const SizedBox(height: 10),
            row(Icons.chat_bubble_outline, 'Talk to someone', talk),
            const SizedBox(height: 10),
            row(Icons.eco_outlined, 'Complete your 1%', action),
            const SizedBox(height: 10),
            row(Icons.stars_outlined, 'Earn today\'s XP', action),
          ],
        ),
      ),
    );
  }
}

class _CompletionDialog extends StatelessWidget {
  const _CompletionDialog({required this.result});

  final Map<String, dynamic> result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final xp = result['xp_earned'] ?? 0;
    final streak = result['current_streak'] ?? 0;
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🌱', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 12),
          Text('+$xp XP',
              style: theme.textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text('🔥 $streak day streak',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          const Text(
            'One small step done. Come back tomorrow for your next 1%.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Keep going'),
        ),
      ],
    );
  }
}

/// Emoji/labels for the inline mood strip.
class MoodEmoji {
  MoodEmoji._();

  static String forKey(String key) => switch (key) {
        'great' => '😄',
        'good' => '🙂',
        'okay' => '😐',
        'low' => '😔',
        _ => '😣',
      };

  static String label(String key) => switch (key) {
        'great' => 'Great',
        'good' => 'Good',
        'okay' => 'Okay',
        'low' => 'Low',
        _ => 'Stressed',
      };
}

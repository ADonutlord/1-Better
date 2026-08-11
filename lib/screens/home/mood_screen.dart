import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../services/action_service.dart';

/// Step 1: choose how you're feeling, optionally with situations.
class MoodScreen extends StatefulWidget {
  const MoodScreen({super.key, this.initialMood});

  final String? initialMood;

  @override
  State<MoodScreen> createState() => _MoodScreenState();
}

class _MoodScreenState extends State<MoodScreen> {
  String? _mood;
  final List<String> _situations = [];
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _mood = widget.initialMood;
  }

  Future<void> _submit() async {
    if (_mood == null) return;
    setState(() => _submitting = true);
    try {
      await ActionService.instance.checkInMood(_mood!, _situations);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save your mood: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('How are you feeling?'),
        actions: [
          TextButton(
            onPressed: _submitting ? null : _submit,
            child: const Text('Save'),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text('Check in with yourself',
                    style: theme.textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Text(
                  'Just choose what fits. This helps us pick a better 1% for you tomorrow.',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 24),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  alignment: WrapAlignment.center,
                  children: [
                    for (final mood in Moods.keys)
                      _MoodTile(
                        mood: mood,
                        selected: _mood == mood,
                        onTap: () => setState(() => _mood = mood),
                      ),
                  ],
                ),
                const SizedBox(height: 28),
                Text('What\'s affecting you? (optional)',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final s in Situations.keys)
                      ChoiceChip(
                        label: Text(_situationLabel(s)),
                        selected: _situations.contains(s),
                        showCheckmark: false,
                        onSelected: (sel) => setState(() {
                          if (sel) {
                            _situations.add(s);
                          } else {
                            _situations.remove(s);
                          }
                        }),
                      ),
                  ],
                ),
                const SizedBox(height: 28),
                FilledButton(
                  onPressed: (_mood == null || _submitting) ? null : _submit,
                  child: _submitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.4),
                        )
                      : const Text('Save my check-in'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _situationLabel(String key) => switch (key) {
        'school' => 'School',
        'work' => 'Work',
        'family' => 'Family',
        'friends' => 'Friends',
        'relationships' => 'Relationships',
        'money' => 'Money',
        'loneliness' => 'Loneliness',
        'stress' => 'Stress',
        'motivation' => 'Motivation',
        _ => 'Other',
      };
}

class _MoodTile extends StatelessWidget {
  const _MoodTile({
    required this.mood,
    required this.selected,
    required this.onTap,
  });

  final String mood;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        width: 88,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: selected ? theme.colorScheme.primaryContainer : theme.colorScheme.surface,
          border: Border.all(
            color: selected
                ? theme.colorScheme.primary
                : theme.colorScheme.outlineVariant,
            width: selected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          children: [
            Text(Moods.emojiFor(mood), style: const TextStyle(fontSize: 30)),
            const SizedBox(height: 6),
            Text(Moods.labelFor(mood),
                style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}

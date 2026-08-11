import 'package:flutter/material.dart';
import 'package:one_percent_better/core/constants/app_constants.dart';

/// The "How are you feeling?" selector: 5 tappable moods.
class MoodSelector extends StatelessWidget {
  const MoodSelector({
    super.key,
    this.onSelected,
    this.selected,
  });

  final ValueChanged<String>? onSelected;
  final String? selected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      alignment: WrapAlignment.center,
      children: [
        for (final mood in Moods.keys)
          _MoodButton(
            mood: mood,
            selected: selected == mood,
            onTap: () => onSelected?.call(mood),
          ),
      ],
    );
  }
}

class _MoodButton extends StatelessWidget {
  const _MoodButton({
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
        duration: const Duration(milliseconds: 150),
        width: 72,
        padding: const EdgeInsets.symmetric(vertical: 12),
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
            Text(Moods.emojiFor(mood), style: const TextStyle(fontSize: 26)),
            const SizedBox(height: 6),
            Text(
              Moods.labelFor(mood),
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Multi-select chips for optional situations.
class SituationChips extends StatelessWidget {
  const SituationChips({
    super.key,
    required this.selected,
    required this.onToggle,
  });

  final List<String> selected;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final s in Situations.keys)
          ChoiceChip(
            label: Text(_label(s)),
            selected: selected.contains(s),
            onSelected: (_) => onToggle(s),
            showCheckmark: false,
          ),
      ],
    );
  }

  static String _label(String key) => switch (key) {
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

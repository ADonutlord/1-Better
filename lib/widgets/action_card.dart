import 'package:flutter/material.dart';
import 'package:one_percent_better/core/constants/app_constants.dart';
import 'package:one_percent_better/models/models.dart';

/// Shows a 1% action with category, difficulty, duration and XP.
class ActionCard extends StatelessWidget {
  const ActionCard({
    super.key,
    required this.action,
    this.onTap,
    this.completed = false,
    this.supportsTap = true,
  });

  final AppAction action;
  final VoidCallback? onTap;
  final bool completed;
  final bool supportsTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final icon = _categoryIcon(action.category);

    return Card(
      child: InkWell(
        onTap: supportsTap ? onTap : null,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: completed
                      ? theme.colorScheme.surfaceContainerHighest
                      : theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon,
                    color: completed
                        ? theme.colorScheme.onSurfaceVariant
                        : theme.colorScheme.primary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            action.title,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              decoration:
                                  completed ? TextDecoration.lineThrough : null,
                            ),
                          ),
                        ),
                        if (completed)
                          Icon(Icons.check_circle,
                              color: theme.colorScheme.primary, size: 20),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      action.description,
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _meta(theme, Icons.timer_outlined,
                            '${action.estimatedMinutes} min'),
                        _meta(theme, Icons.local_fire_department_outlined,
                            Difficulty.labels[action.difficulty] ?? 'Easy'),
                        _meta(theme, Icons.bolt_outlined, '+${action.baseXp} XP'),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _meta(ThemeData theme, IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 3),
        Text(text,
            style: theme.textTheme.labelSmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
      ],
    );
  }

  static IconData _categoryIcon(String category) => switch (category) {
        'wellbeing' => Icons.spa_outlined,
        'productivity' => Icons.checklist_outlined,
        'study' => Icons.menu_book_outlined,
        'social' => Icons.group_outlined,
        'physical' => Icons.directions_walk_outlined,
        _ => Icons.edit_note,
      };
}

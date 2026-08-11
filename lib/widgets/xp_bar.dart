import 'package:flutter/material.dart';

import '../logic/level_calculator.dart';

/// LEVEL 8 🌱 with an XP progress bar.
class XpBar extends StatelessWidget {
  const XpBar({super.key, required this.totalXp, this.compact = false});

  final int totalXp;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final level = LevelCalculator.levelForXp(totalXp);
    final progress = LevelCalculator.levelProgress(totalXp, level);
    final toNext = LevelCalculator.xpToNextLevel(level);
    final into = LevelCalculator.xpIntoLevel(totalXp, level);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('LEVEL $level',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(width: 6),
            const Text('🌱'),
            const Spacer(),
            Text('$into / $toNext XP',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: progress.clamp(0.0, 1.0),
            minHeight: compact ? 6 : 10,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
            color: theme.colorScheme.primary,
          ),
        ),
        if (!compact) ...[
          const SizedBox(height: 6),
          Text('$toNext XP to Level ${level + 1}',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ],
      ],
    );
  }
}

/// 🔥 n DAY STREAK chip.
class StreakBadge extends StatelessWidget {
  const StreakBadge({
    super.key,
    required this.days,
    this.paused = false,
    this.large = false,
  });

  final int days;
  final bool paused;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final color =
        paused ? theme.colorScheme.onSurfaceVariant : const Color(0xFFE8590C);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: large ? 18 : 12,
        vertical: large ? 10 : 8,
      ),
      decoration: BoxDecoration(
        color: paused
            ? theme.colorScheme.surfaceContainerHighest
            : isDark
                ? const Color(0xFF3B2A15)
                : const Color(0xFFFFEFE3),
        borderRadius: BorderRadius.circular(large ? 18 : 14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(paused ? '⏸️' : '🔥',
              style: TextStyle(fontSize: large ? 24 : 18)),
          const SizedBox(width: 8),
          Text(
            paused
                ? 'STREAK PAUSED'
                : '$days DAY STREAK',
            style: theme.textTheme.labelLarge?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

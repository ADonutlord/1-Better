/// Pure Dart progression logic: levels, streaks, XP thresholds.
library;

class LevelCalculator {
  LevelCalculator._();

  /// Cumulative XP required to reach `level`.
  ///
  /// Threshold(level n) = 25 * (n - 1) * (n + 2)
  ///   L1: 0, L2: 100, L3: 250, L4: 450, L5: 700 ...
  static int xpForLevel(int level) => 25 * (level - 1) * (level + 2);

  /// Highest level whose XP threshold is <= totalXp.
  static int levelForXp(int totalXp) {
    if (totalXp < 0) return 1;
    var level = 1;
    while (xpForLevel(level + 1) <= totalXp) {
      level += 1;
      if (level >= 200) break;
    }
    return level;
  }

  /// XP already earned inside the current level.
  static int xpIntoLevel(int totalXp, int level) {
    final base = xpForLevel(level);
    final next = xpForLevel(level + 1);
    final span = next - base;
    if (span <= 0) return 0;
    final into = (totalXp - base).clamp(0, span);
    return into;
  }

  /// XP needed to reach the next level from the current level.
  static int xpToNextLevel(int level) =>
      xpForLevel(level + 1) - xpForLevel(level);

  /// Progress 0.0 -> 1.0 through the current level.
  static double levelProgress(int totalXp, int level) {
    final base = xpForLevel(level);
    final next = xpForLevel(level + 1);
    final span = next - base;
    if (span <= 0) return 0;
    return ((totalXp - base).clamp(0, span)) / span;
  }
}

/// Streak semantics shared by the server and the UI.
class StreakLogic {
  StreakLogic._();

  /// True if completing on `day` extends an existing streak.
  static bool isConsecutiveDay({DateTime? lastActionDate, required DateTime day}) {
    if (lastActionDate == null) return false;
    final last = DateTime(lastActionDate.year, lastActionDate.month, lastActionDate.day);
    final today = DateTime(day.year, day.month, day.day);
    return today.difference(last).inDays == 1;
  }

  static bool isSameDay(DateTime? lastActionDate, DateTime day) {
    if (lastActionDate == null) return false;
    final last = DateTime(lastActionDate.year, lastActionDate.month, lastActionDate.day);
    final today = DateTime(day.year, day.month, day.day);
    return last == today;
  }

  /// New current streak after a completion on `day`.
  static int nextStreak({DateTime? lastActionDate, required int currentStreak, required DateTime day}) {
    if (isConsecutiveDay(lastActionDate: lastActionDate, day: day)) {
      return currentStreak + 1;
    }
    if (isSameDay(lastActionDate, day)) {
      return currentStreak;
    }
    return 1;
  }
}

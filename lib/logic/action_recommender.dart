import 'dart:math';

import 'package:one_percent_better/core/constants/app_constants.dart';
import 'package:one_percent_better/models/models.dart';

/// The 1% Better personalization algorithm.
///
/// score =
///     moodMatch        * 40
///   + situationMatch   * 20
///   + personalSuccess  * 15
///   + categoryBalance  * 10
///   + difficultyFit    * 10
///   + novelty          *  5
///
/// Every component is normalized 0.0 -> 1.0, then weighted. The top candidates
/// are chosen by a small weighted-random draw so the same action is not forced
/// every single day.
class ActionRecommender {
  ActionRecommender({Random? random}) : _random = random ?? Random();

  final Random _random;

  static const int _topCandidates = 5;

  /// Picks the best action for today.
  ///
  /// [actions] are the active candidates, [history] is the user's full history
  /// (each entry should carry the action snapshot for scoring), [mood] is the
  /// current check-in and [situations] the optional situations.
  AppAction recommend({
    required List<AppAction> actions,
    String? mood,
    List<String> situations = const [],
    required List<ActionHistory> history,
  }) {
    assert(actions.isNotEmpty, 'need at least one action to recommend');

    final candidates = actions.where((a) => a.active).toList();
    if (candidates.isEmpty) {
      throw StateError('No active actions to recommend');
    }

    final scored = candidates
        .map((a) => _Scored(a, score(
              action: a,
              mood: mood,
              situations: situations,
              history: history,
            ).total))
        .toList()
      ..sort((a, b) => b.score.compareTo(a.score));

    final top = scored.take(_topCandidates).toList();
    return _weightedPick(top);
  }

  /// Full weighted score in the 0.0 -> 100.0 range, plus breakdown.
  ({double total, Map<String, double> parts}) score({
    required AppAction action,
    String? mood,
    List<String> situations = const [],
    required List<ActionHistory> history,
  }) {
    final moodMatch = moodMatchScore(action, mood);
    final situationMatch = situationMatchScore(action, situations);
    final personalSuccess = personalSuccessScore(action, history);
    final categoryBalance = categoryBalanceScore(action, history);
    final difficultyFit = difficultyFitScore(action, history);
    final novelty = noveltyScore(action, history);

    final total = moodMatch * 40 +
        situationMatch * 20 +
        personalSuccess * 15 +
        categoryBalance * 10 +
        difficultyFit * 10 +
        novelty * 5;

    return (
      total: total,
      parts: {
        'mood': moodMatch,
        'situation': situationMatch,
        'success': personalSuccess,
        'balance': categoryBalance,
        'difficulty': difficultyFit,
        'novelty': novelty,
      },
    );
  }

  // -------------------------------------------------------------------------
  // Components
  // -------------------------------------------------------------------------

  double moodMatchScore(AppAction action, String? mood) {
    if (mood == null || mood.isEmpty) return 0.5;

    var score = 0.0;
    if (action.moodTags.contains(mood)) {
      score = 1.0;
    } else if (_adjacentMoods(mood).any(action.moodTags.contains)) {
      score = 0.4;
    }

    // Negative moods lean toward soothing, low-effort actions.
    if (Moods.isNegative(mood)) {
      const soothing = {
        'breathing', 'grounding', 'relaxation', 'self-soothing', 'rest',
      };
      if (soothing.contains(action.subCategory)) {
        score = max(score, 0.85);
      }
      if (action.category == 'wellbeing') {
        score = max(score, 0.6);
      }
    }

    // Positive moods open the door to social, productive and physical picks.
    if (Moods.isPositive(mood)) {
      if (action.category == 'social' ||
          action.category == 'productivity' ||
          action.category == 'physical' ||
          action.subCategory == 'gratitude') {
        score = max(score, 0.85);
      }
    }

    // Neutral/mixed moods keep a mild baseline so something is always offered.
    if (Moods.groupOf(mood) == Moods.neutral && score == 0) {
      score = 0.3;
    }
    return score.clamp(0.0, 1.0);
  }

  double situationMatchScore(AppAction action, List<String> situations) {
    final list = situations.where((s) => s.isNotEmpty).toList();
    if (list.isEmpty) return 0.5;
    var matched = 0;
    for (final s in list) {
      if (action.situationTags.contains(s)) matched++;
    }
    if (matched == 0) return 0.0;
    return (matched / list.length).clamp(0.0, 1.0);
  }

  /// Completion success, combining this action's own history with its
  /// category's history. Skipped actions pull the score down.
  double personalSuccessScore(AppAction action, List<ActionHistory> history) {
    final myHistory = history.where((h) => h.actionId == action.id).toList();

    double rateOf(Iterable<ActionHistory> list) {
      if (list.isEmpty) return 0.5;
      final completed = list.where((h) => h.completed).length;
      return completed / list.length;
    }

    if (myHistory.isNotEmpty) {
      final actionRate = rateOf(myHistory);
      final catHistory = history
          .where((h) =>
              (h.actionCategory ?? action.category) == action.category)
          .toList();
      final catRate = rateOf(catHistory);
      return (actionRate * 0.7 + catRate * 0.3).clamp(0.0, 1.0);
    }

    final catHistory = history
        .where((h) => (h.actionCategory ?? action.category) == action.category)
        .toList();
    return rateOf(catHistory);
  }

  /// Avoid repeating the categories used recently.
  double categoryBalanceScore(AppAction action, List<ActionHistory> history) {
    if (history.isEmpty) return 0.5;
    final recent = history.take(5).toList();
    if (recent.isEmpty) return 0.5;
    final matches =
        recent.where((h) => (h.actionCategory ?? action.category) == action.category)
            .length;
    return (1 - (matches / recent.length)).clamp(0.0, 1.0);
  }

  /// Adapt difficulty to the user's completion trend.
  double difficultyFitScore(AppAction action, List<ActionHistory> history) {
    if (history.isEmpty) return 0.5;

    final completed = history.where((h) => h.completed).toList();
    final rate = completed.length / history.length;

    double avgDifficulty = 1.5;
    if (completed.isNotEmpty) {
      final diffs = completed.map((h) => (h.actionDifficulty ?? 1).toDouble());
      avgDifficulty = diffs.reduce((a, b) => a + b) / completed.length;
    }

    final adjustment = rate >= 0.7
        ? 0.5
        : (rate <= 0.4 ? -0.5 : 0.0);
    final desired = (avgDifficulty + adjustment).clamp(1.0, 5.0);

    return (1 - ((action.difficulty - desired).abs() / 4).clamp(0.0, 1.0));
  }

  /// Never-seen actions are novel; recently used actions are not.
  double noveltyScore(AppAction action, List<ActionHistory> history) {
    final used = history.where((h) => h.actionId == action.id).toList();
    if (used.isEmpty) return 1.0;
    final last = used.map((h) => h.assignedAt).reduce((a, b) => a.isAfter(b) ? a : b);
    final days = DateTime.now().difference(last).inDays;
    return (days / 30).clamp(0.0, 1.0);
  }

  // -------------------------------------------------------------------------
  // Helpers
  // -------------------------------------------------------------------------

  /// Moods in the same group, or any mood with the same polarity, count as
  /// adjacent (used as a soft match instead of a hard 1.0).
  static List<String> _adjacentMoods(String mood) {
    final group = Moods.groupOf(mood);
    if (group == null) return const [];
    return Moods.groups[group]!.where((m) => m != mood).toList();
  }

  AppAction _weightedPick(List<_Scored> top) {
    if (top.length == 1) return top.first.action;
    final weights = top
        .map((s) => max(s.score, 1.0))
        .toList(); // never zero-weight a top candidate
    final total = weights.reduce((a, b) => a + b);
    var roll = _random.nextDouble() * total;
    for (var i = 0; i < top.length; i++) {
      roll -= weights[i];
      if (roll <= 0) return top[i].action;
    }
    return top.last.action;
  }
}

class _Scored {
  _Scored(this.action, this.score);
  final AppAction action;
  final double score;
}

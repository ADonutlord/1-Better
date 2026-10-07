import 'package:flutter_test/flutter_test.dart';
import 'package:one_percent_better/models/models.dart';

void main() {
  group('DailyProgress.moodLocked', () {
    DailyProgress progress({
      bool moodCompleted = false,
      bool actionCompleted = false,
    }) => DailyProgress(
      userId: 'u1',
      date: DateTime(2026, 10, 6),
      moodCompleted: moodCompleted,
      actionCompleted: actionCompleted,
    );

    test('the mood stays editable while the 1% is unfinished', () {
      expect(progress().moodLocked, isFalse);
      expect(
        progress(moodCompleted: true).moodLocked,
        isFalse,
        reason: 'checked in, but the task is still open',
      );
    });

    test('the mood locks the moment the 1% is completed', () {
      expect(progress(actionCompleted: true).moodLocked, isTrue);
    });

    test('follows the server payload', () {
      final completed = DailyProgress.fromJson({
        'user_id': 'u1',
        'date': '2026-10-06',
        'mood_completed': true,
        'action_completed': true,
      });
      expect(completed.moodLocked, isTrue);

      final open = DailyProgress.fromJson({
        'user_id': 'u1',
        'date': '2026-10-06',
        'mood_completed': true,
        'action_completed': false,
      });
      expect(open.moodLocked, isFalse);
    });

    test('a missing flag never locks the mood', () {
      final parsed = DailyProgress.fromJson({
        'user_id': 'u1',
        'date': '2026-10-06',
      });
      expect(parsed.moodLocked, isFalse);
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:one_percent_better/models/models.dart';

void main() {
  group('StudySession', () {
    test('parses from json', () {
      final session = StudySession.fromJson({
        'id': 'abc',
        'user_id': 'user-1',
        'started_at': '2026-08-30T09:00:00Z',
        'ended_at': '2026-08-30T10:30:00Z',
        'duration_seconds': 5400,
      });

      expect(session.id, 'abc');
      expect(session.userId, 'user-1');
      expect(session.durationSeconds, 5400);
      expect(session.durationMinutes, 90);
      expect(session.durationHours, closeTo(1.5, 0.0001));
    });

    test('defaults to zero when fields are missing', () {
      final session = StudySession.fromJson(const {});
      expect(session.durationSeconds, 0);
      expect(session.durationMinutes, 0);
    });
  });
}

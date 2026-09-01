import 'package:flutter_test/flutter_test.dart';
import 'package:one_percent_better/models/models.dart';

void main() {
  group('Post', () {
    test('parses from json with author and answer count', () {
      final post = Post.fromJson({
        'id': 'post-1',
        'user_id': 'user-1',
        'question': 'How do I study better?',
        'body': 'I keep getting distracted.',
        'created_at': '2026-09-01T09:00:00Z',
        'answer_count': 3,
        'author': {
          'display_name': 'Ada',
          'profession': 'student',
          'role': 'user',
        },
      });

      expect(post.id, 'post-1');
      expect(post.userId, 'user-1');
      expect(post.question, 'How do I study better?');
      expect(post.answerCount, 3);
      expect(post.author?.displayName, 'Ada');
      expect(post.author!.role, 'user');
      expect(post.isOwnedBy('user-1'), isTrue);
      expect(post.isOwnedBy('someone-else'), isFalse);
    });

    test('defaults for missing fields', () {
      final post = Post.fromJson(const {});
      expect(post.id, '');
      expect(post.question, '');
      expect(post.answerCount, 0);
      expect(post.author, isNull);
    });
  });

  group('PostAnswer', () {
    test('parses from json with author', () {
      final answer = PostAnswer.fromJson({
        'id': 'answer-1',
        'post_id': 'post-1',
        'user_id': 'user-2',
        'answer': 'Try the pomodoro technique.',
        'created_at': '2026-09-01T10:00:00Z',
        'author': {
          'display_name': 'Lin',
          'profession': 'teacher',
          'role': 'helper',
        },
      });

      expect(answer.postId, 'post-1');
      expect(answer.userId, 'user-2');
      expect(answer.answer, 'Try the pomodoro technique.');
      expect(answer.author?.displayName, 'Lin');
      expect(answer.author!.role, 'helper');
    });

    test('fromJson handles missing answer text gracefully', () {
      final answer = PostAnswer.fromJson({'post_id': 'p1'});
      expect(answer.postId, 'p1');
      expect(answer.answer, '');
    });
  });
}
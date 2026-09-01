import 'dart:async';

import 'package:one_percent_better/models/models.dart';
import 'package:one_percent_better/services/supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Community feed service: Instagram-style posts where users ask questions
/// and other real people answer them. Streams updates via Supabase realtime.
class CommunityService {
  CommunityService._();

  static final CommunityService instance = CommunityService._();

  SupabaseClient get _client => SupabaseService.instance.client;

  String get currentUserId => _client.auth.currentUser!.id;

  // ---------------------------------------------------------------------
  // Posts
  // ---------------------------------------------------------------------

  /// The community feed, newest first. Each post carries its author profile
  /// and answer count so the feed shows "who asked" and "how many answers".
  Future<List<Post>> fetchPosts() async {
    final rows = await _client
        .from('posts')
        .select('*, author:profiles(display_name, profession, avatar_url, role, level)')
        .order('created_at', ascending: false)
        .limit(100);

    final counts = await _answerCounts();
    return rows.map((r) => Post.fromJson({
          ...r,
          'answer_count': counts[r['id'] as String?] ?? 0,
        })).toList();
  }

  /// Answer count per post (grouped aggregate over all posts).
  Future<Map<String, int>> _answerCounts() async {
    final grouped = await _client
        .from('post_answers')
        .select('post_id, count:count()');
    final out = <String, int>{};
    for (final g in grouped) {
      final pid = g['post_id'] as String?;
      if (pid != null) {
        out[pid] = (g['count'] as int?) ?? 0;
      }
    }
    return out;
  }

  /// Answers for one post (oldest first, like a thread).
  Future<List<PostAnswer>> fetchAnswers(String postId) async {
    final rows = await _client
        .from('post_answers')
        .select('*, author:profiles(display_name, profession, avatar_url, role, level)')
        .eq('post_id', postId)
        .order('created_at', ascending: true);
    return rows.map(PostAnswer.fromJson).toList();
  }

  /// Creates a new community post asking a question; the user who asks is the
  /// author (RLS enforces ownership).
  Future<Post> createPost({
    required String question,
    String body = '',
  }) async {
    final row = await _client.from('posts').insert({
      'user_id': currentUserId,
      'question': question,
      'body': body,
    }).select('*.author:profiles(display_name, profession, avatar_url, role, level)').single();
    return Post.fromJson({...row, 'answer_count': 0});
  }

  /// Deletes one of the caller's own posts.
  Future<void> deletePost(String postId) async {
    await _client.from('posts').delete().eq('id', postId).eq('user_id', currentUserId);
  }

  // ---------------------------------------------------------------------
  // Answers
  // ---------------------------------------------------------------------

  /// Posts an answer on someone else's post (RLS blocks answering your own).
  Future<PostAnswer> createAnswer({
    required String postId,
    required String answer,
  }) async {
    final row = await _client.from('post_answers').insert({
      'post_id': postId,
      'user_id': currentUserId,
      'answer': answer,
    }).select('*.author:profiles(display_name, profession, avatar_url, role, level)').single();
    return PostAnswer.fromJson(row);
  }

  // ---------------------------------------------------------------------
  // Realtime
  // ---------------------------------------------------------------------

  /// Live stream of new posts for the feed (top-most feed stays fresh).
  Stream<List<Post>> streamPosts() {
    return _client
        .from('posts')
        .stream(primaryKey: ['id'])
        .map((rows) => rows.map(Post.fromJson).toList());
  }

  /// Live stream of answers for one post's thread.
  Stream<List<PostAnswer>> streamAnswers(String postId) {
    return _client
        .from('post_answers')
        .stream(primaryKey: ['id'])
        .eq('post_id', postId)
        .map((rows) => rows.map(PostAnswer.fromJson).toList());
  }
}

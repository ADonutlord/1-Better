import 'dart:async';

import 'package:one_percent_better/models/models.dart';
import 'package:one_percent_better/services/e2ee_service.dart';
import 'package:one_percent_better/services/supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// A conversation together with its participants (for the chat UI).
class ConversationView {
  const ConversationView({
    required this.conversation,
    required this.participants,
  });

  final Conversation conversation;
  final List<ConversationParticipant> participants;

  ConversationParticipant? participantFor(String userId) {
    for (final p in participants) {
      if (p.userId == userId) return p;
    }
    return null;
  }
}

/// All chat operations: matching, messaging, realtime, safety.
class ChatService {
  ChatService._();

  static final ChatService instance = ChatService._();

  SupabaseClient get _client => SupabaseService.instance.client;

  String get currentUserId => _client.auth.currentUser!.id;

  // ---------------------------------------------------------------------
  // Conversation lifecycle
  // ---------------------------------------------------------------------

  /// User requests a conversation: creates a waiting conversation.
  Future<Conversation> startConversation() async {
    final data = await _client.rpc('start_conversation');
    return Conversation.fromJson(data);
  }

  /// Tries to match the caller's waiting conversation with a waiting peer.
  /// Returns null when no one else is waiting right now.
  Future<Conversation?> findMatch() async {
    final data = await _client.rpc('find_match');
    if (data == null) return null;
    return Conversation.fromJson(data);
  }

  /// Any participant ends an active conversation.
  Future<Map<String, dynamic>> endConversation(String conversationId) async {
    return await _client
        .rpc('end_conversation', params: {'p_conversation_id': conversationId});
  }

  Future<void> sendMessage(String conversationId, String message) async {
    final userId = _client.auth.currentUser!.id;
    final payload = await E2eeService.instance
        .encryptForConversation(conversationId, message);
    await _client.from('messages').insert({
      'conversation_id': conversationId,
      'sender_id': userId,
      'message': payload,
      'message_type': 'text',
    });
  }

  /// Withdraws the caller's waiting conversation (no match was found).
  Future<void> cancelWaitingConversation() async {
    await _client.rpc('cancel_waiting_conversation');
  }

  /// Removes a conversation from the caller's own list (any role).
  /// Active conversations are ended first so the other peer isn't stranded.
  Future<void> deleteConversation(String conversationId) async {
    await _client.rpc('delete_my_conversation',
        params: {'p_conversation_id': conversationId});
  }

  // ---------------------------------------------------------------------
  // Reads
  // ---------------------------------------------------------------------

  /// Conversations the current user participates in (newest active first).
  /// Conversations the user deleted (deleted_at set) are hidden.
  Future<List<ConversationView>> fetchMyConversations() async {    final userId = _client.auth.currentUser!.id;
    final rows = await _client
        .from('conversation_participants')
        .select('*, profiles:profiles!conversation_participants_user_id_fkey(display_name, profession, avatar_url), conversations:conversations(*, participants:conversation_participants(profile:profiles(display_name, profession, avatar_url))))')
        .eq('user_id', userId)
        .isFilter('deleted_at', null)
        .order('joined_at', ascending: false)
        .limit(30);

    final byConversation = <String, List<Map<String, dynamic>>>{};
    for (final row in rows) {
      byConversation.putIfAbsent(row['conversations'] != null
          ? (row['conversations'] as Map<String, dynamic>)['id'] as String
          : '', () => []).add(row);
    }

    final result = <ConversationView>[];
    for (final entry in byConversation.entries) {
      final convJson = entry.value.first['conversations'] as Map<String, dynamic>;
      final participantsJson = convJson['participants'] as List<dynamic>? ?? [];
      final participants = participantsJson
          .map((p) => ConversationParticipant.fromJson(p as Map<String, dynamic>))
          .toList();
      result.add(ConversationView(
        conversation: Conversation.fromJson(convJson),
        participants: participants,
      ));
    }
    return result;
  }

  /// Participants of a conversation (needs to be a participant).
  Future<ConversationView> fetchParticipants(String conversationId) async {
    final rows = await _client
        .from('conversation_participants')
        .select(
            'conversation_id, conversations:conversations(*), profiles:profiles(display_name, profession, avatar_url)')
        .eq('conversation_id', conversationId);
    final convJson = rows.isNotEmpty
        ? (rows.first['conversations'] as Map<String, dynamic>?)
        : null;
    final participants = rows
        .map((r) => ConversationParticipant.fromJson({
              ...r,
              if (r['profiles'] != null) ...{
                'display_name':
                    (r['profiles'] as Map<String, dynamic>)['display_name'],
                'profession':
                    (r['profiles'] as Map<String, dynamic>)['profession'],
                'avatar_url':
                    (r['profiles'] as Map<String, dynamic>)['avatar_url'],
              },
            }))
        .toList();
    return ConversationView(
      conversation: convJson != null
          ? Conversation.fromJson(convJson)
          : Conversation(id: conversationId, status: 'active', createdAt: DateTime.now()),
      participants: participants,
    );
  }

  /// The active (or most recent) conversation for this user, if any.
  Future<ConversationView?> fetchActiveConversation() async {
    final userId = _client.auth.currentUser!.id;
    final rows = await _client
        .from('conversation_participants')
        .select(
            'conversation_id, conversations:conversations(*, participants:conversation_participants(*, profile:profiles(display_name, profession, avatar_url)))')
        .eq('user_id', userId)
        .isFilter('deleted_at', null)
        .inFilter('conversations.status', ['waiting', 'active'])
        .order('joined_at', ascending: false)
        .limit(1);
    if (rows.isEmpty) return null;
    final convJson =
        (rows.first['conversations'] as Map<String, dynamic>?);
    if (convJson == null) return null;
    final participantsJson = (convJson['participants'] as List<dynamic>? ?? []);
    final participants = participantsJson
        .map((p) => ConversationParticipant.fromJson(p as Map<String, dynamic>))
        .toList();
    return ConversationView(
      conversation: Conversation.fromJson(convJson),
      participants: participants,
    );
  }

  Future<List<ChatMessage>> fetchMessages(String conversationId) async {
    final rows = await _client
        .from('messages')
        .select('*')
        .eq('conversation_id', conversationId)
        .order('created_at', ascending: true)
        .limit(500);
    return _decryptRows(conversationId, rows);
  }

  /// Realtime stream of messages for one conversation.
  Stream<List<ChatMessage>> streamMessages(String conversationId) {
    return _client
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('conversation_id', conversationId)
        .asyncMap((rows) => _decryptRows(conversationId, rows));
  }

  /// Decrypts user text payloads; system/action messages pass through.
  Future<List<ChatMessage>> _decryptRows(
      String conversationId, List<Map<String, dynamic>> rows) async {
    final out = <ChatMessage>[];
    for (final r in rows) {
      final type = (r['message_type'] as String?) ?? 'text';
      var msg = ChatMessage.fromJson(r);
      if (type == 'text') {
        final clear = await E2eeService.instance
            .decryptForConversation(conversationId, msg.message);
        msg = ChatMessage(
          id: msg.id,
          conversationId: msg.conversationId,
          senderId: msg.senderId,
          message: clear,
          messageType: msg.messageType,
          createdAt: msg.createdAt,
        );
      }
      out.add(msg);
    }
    return out;
  }

  /// Realtime stream of one conversation (status changes, etc).
  Stream<Conversation> streamConversation(String conversationId) {
    return _client
        .from('conversations')
        .stream(primaryKey: ['id'])
        .eq('id', conversationId)
        .map((rows) => rows.map((r) => Conversation.fromJson(r)).toList())
        .map((list) => list.isEmpty
            ? Conversation(
                id: conversationId, status: 'ended', createdAt: DateTime.now())
            : list.first);
  }

  /// Real-time notifications for the current user's own conversations.
  Stream<List<Conversation>> streamMyConversationStatus(String userId) {
    return _client
        .from('conversation_participants')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .map((rows) {
          final ids = rows
              .map((r) => (r['conversation_id'] as String?) ?? '')
              .where((id) => id.isNotEmpty)
              .toList();
          return ids.map((id) => Conversation(
                id: id, status: 'changed', createdAt: DateTime.now())).toList();
        });
  }

  // ---------------------------------------------------------------------
  // Safety
  // ---------------------------------------------------------------------

  Future<void> reportUser({
    required String reportedUserId,
    required String reason,
    String? conversationId,
  }) async {
    await _client.rpc('report_user', params: {
      'p_reported_user_id': reportedUserId,
      'p_reason': reason,
      'p_conversation_id': conversationId,
    });
  }

  Future<void> blockUser(String blockedUserId) async {
    await _client.rpc('block_user', params: {'p_blocked_user_id': blockedUserId});
  }

  Future<void> unblockUser(String blockedUserId) async {
    await _client.rpc('unblock_user', params: {'p_blocked_user_id': blockedUserId});
  }

  Future<List<UserProfile>> fetchBlockedUsers() async {
    final rows = await _client
        .from('blocks')
        .select('blocked:blocked_user_id!blocks_blocked_user_id_fkey(display_name)')
        .order('created_at', ascending: false);
    return rows
        .where((r) => r['blocked'] != null)
        .map((r) {
          final p = r['blocked'] as Map<String, dynamic>;
          return UserProfile(
            id: (p['id'] as String?) ?? '',
            displayName: (p['display_name'] as String?) ?? 'Blocked user',
            role: 'user',
            level: 1,
            totalXp: 0,
            currentStreak: 0,
            longestStreak: 0,
          );
        })
        .toList();
  }
}

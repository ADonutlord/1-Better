import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../services/chat_service.dart';
import '../../widgets/empty_state.dart';
import '../home/talk_to_someone_flow.dart';
import 'chat_screen.dart';

/// Lists the user's conversations (active first).
class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  List<ConversationView> _items = [];
  bool _loading = true;
  Object? _error;
  StreamSubscription<List<Conversation>>? _sub;
  final String _myId = ChatService.instance.currentUserId;

  @override
  void initState() {
    super.initState();
    _load();
    _sub = ChatService.instance
        .streamMyConversationStatus(_myId)
        .listen((_) => _load(), onError: (_) {});
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final items = await ChatService.instance.fetchMyConversations();
      items.sort((a, b) {
        int rank(Conversation c) =>
            c.status == 'active' ? 0 : (c.status == 'waiting' ? 1 : 2);
        final r = rank(a.conversation).compareTo(rank(b.conversation));
        if (r != 0) return r;
        return b.conversation.createdAt.compareTo(a.conversation.createdAt);
      });
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e;
      });
    }
  }

  Future<void> _deleteConversation(ConversationView view) async {
    final name = view.participants
        .firstWhere((p) => p.userId != _myId, orElse: () => view.participants.first)
        .displayName ?? 'Conversation';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete conversation?'),
        content: Text(
            'This removes the chat with $name from your list. It doesn\'t '
            'affect the other person.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await ChatService.instance.deleteConversation(view.conversation.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Conversation deleted.')),
      );
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    }
  }

  Future<void> _openConversation(ConversationView view) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatScreen(conversation: view.conversation),
      ),
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat'),
        actions: [
          IconButton(
            tooltip: 'Talk to someone',
            icon: const Icon(Icons.add_comment_outlined),
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const TalkToSomeoneFlow()),
              );
              _load();
            },
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return EmptyState(
        icon: Icons.cloud_off_outlined,
        title: 'Couldn\'t load conversations',
        message: 'Check your connection and try again.',
        action: OutlinedButton(
          onPressed: _load,
          child: const Text('Retry'),
        ),
      );
    }
    if (_items.isEmpty) {
      return EmptyState(
        icon: Icons.chat_bubble_outline,
        title: 'No conversations yet',
        message: 'When you talk to someone, it will show up here.',
        action: FilledButton.tonalIcon(
          onPressed: () async {
            await Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const TalkToSomeoneFlow()),
            );
            _load();
          },
          icon: const Icon(Icons.support_agent),
          label: const Text('Talk to someone'),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _items.length,
      itemBuilder: (context, i) {
        final view = _items[i];
        ConversationParticipant? other;
        for (final p in view.participants) {
          if (p.userId != _myId) {
            other = p;
            break;
          }
        }
        final name = other?.displayName ?? 'Conversation';
        final isActive = view.conversation.isActive;
        final isWaiting = view.conversation.isWaiting;
        final avatarUrl = other?.avatarUrl;

        return Card(
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              foregroundImage: (avatarUrl != null && avatarUrl.isNotEmpty)
                  ? NetworkImage(avatarUrl)
                  : null,
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            title: Text(name,
                style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text(
              isWaiting
                  ? 'Waiting for a peer…'
                  : isActive
                      ? 'Active now'
                      : 'Ended',
              style: TextStyle(
                color: isActive
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            trailing: PopupMenuButton<String>(
              tooltip: 'Conversation options',
              onSelected: (value) {
                if (value == 'delete') _deleteConversation(view);
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'delete',
                  child: Text('Delete conversation'),
                ),
              ],
            ),
            onTap: () => _openConversation(view),
          ),
        );
      },
    );
  }
}

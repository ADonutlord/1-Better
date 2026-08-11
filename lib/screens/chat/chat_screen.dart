import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../models/models.dart';
import '../../services/action_service.dart';
import '../../services/chat_service.dart';
import '../../services/e2ee_service.dart';
import '../../widgets/empty_state.dart';
import 'recommend_action_sheet.dart';

/// Realtime 1:1 chat between two peers.
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, required this.conversation});

  final Conversation conversation;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  late Conversation _conversation;
  List<ChatMessage> _messages = [];
  bool _loading = true;
  bool _sending = false;
  Object? _error;
  StreamSubscription<List<ChatMessage>>? _msgSub;
  StreamSubscription<Conversation>? _convSub;
  String? _otherUserId;
  String _otherName = '';
  String? _otherAvatarUrl;
  bool _e2eeActive = false;

  String get _myId => ChatService.instance.currentUserId;

  @override
  void initState() {
    super.initState();
    _conversation = widget.conversation;
    _init();
  }

  Future<void> _init() async {
    await _loadMeta();
    await _loadMessages();
    _checkE2ee();
    _msgSub = ChatService.instance
        .streamMessages(_conversation.id)
        .listen((rows) {
      if (!mounted) return;
      final hadMessages = _messages.isNotEmpty;
      setState(() => _messages = rows);
      if (hadMessages) _scrollToBottom(animated: true);
    }, onError: (_) {});

    _convSub = ChatService.instance
        .streamConversation(_conversation.id)
        .listen((c) {
      if (!mounted) return;
      setState(() => _conversation = c);
      if (c.status == 'ended') {
        _scrollToBottom(animated: true);
      }
    }, onError: (_) {});
  }

  Future<void> _checkE2ee() async {
    final key = await E2eeService.instance.conversationKey(_conversation.id);
    if (!mounted) return;
    setState(() => _e2eeActive = key != null);
  }

  Future<void> _loadMeta() async {
    try {
      final view = await ChatService.instance.fetchActiveConversation();
      ConversationView? found;
      if (view != null && view.conversation.id == _conversation.id) {
        found = view;
      }
      found ??= await _fetchViewById(_conversation.id);
      if (!mounted) return;
      setState(() {
        for (final p in found?.participants ?? <ConversationParticipant>[]) {
          if (p.userId != _myId) {
            _otherUserId = p.userId;
            _otherName = (p.displayName ?? 'Conversation') +
                (p.profession != null
                    ? ' · ${Professions.labelFor(p.profession)}'
                    : '');
            _otherAvatarUrl = (p.avatarUrl != null && p.avatarUrl!.isNotEmpty)
                ? p.avatarUrl
                : null;
          }
        }
      });
    } catch (_) {
      // Optional metadata; chat still works.
    }
  }

  Future<ConversationView?> _fetchViewById(String id) async {
    final service = ChatService.instance;
    final rows = await service.fetchParticipants(id);
    return rows;
  }

  Future<void> _loadMessages() async {
    try {
      final rows = await ChatService.instance.fetchMessages(_conversation.id);
      if (!mounted) return;
      setState(() {
        _messages = rows;
        _loading = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  void _scrollToBottom({bool animated = false}) {
    if (!_scroll.hasClients) return;
    final target = _scroll.position.maxScrollExtent;
    if (animated) {
      _scroll.animateTo(target,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut);
    } else {
      _scroll.jumpTo(target);
    }
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending || !_conversation.isActive) return;
    setState(() => _sending = true);
    try {
      await ChatService.instance.sendMessage(_conversation.id, text);
      _input.clear();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Message failed to send: $e')),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  bool _leaving = false;

  /// Ends (or cancels) the conversation if it's still open when the user
  /// leaves the screen, so the "talk to someone" task is marked complete.
  Future<void> _leaveConversation() async {
    if (_leaving) return;
    _leaving = true;
    if (_conversation.isActive) {
      try {
        await ChatService.instance.endConversation(_conversation.id);
      } catch (_) {}
    } else if (_conversation.status == 'waiting') {
      try {
        await ChatService.instance.cancelWaitingConversation();
      } catch (_) {}
    }
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _endConversation() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('End this conversation?'),
        content: const Text('You can talk to someone again any time.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep talking'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('End conversation'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await ChatService.instance.endConversation(_conversation.id);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _recommendAction() async {
    if (_otherUserId == null) return;
    final selected = await showModalBottomSheet<AppAction>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const RecommendActionSheet(),
    );
    if (selected == null || !mounted) return;
    try {
      await ActionService.instance.recommendActionForUser(
        conversationId: _conversation.id,
        actionId: selected.id,
        userId: _otherUserId!,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Recommended “${selected.title}” 🌱')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _report() async {
    if (_otherUserId == null) return;
    final reason = await _pickReason();
    if (reason == null || !mounted) return;
    try {
      await ChatService.instance.reportUser(
        reportedUserId: _otherUserId!,
        reason: reason,
        conversationId: _conversation.id,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Report sent. Thank you for helping.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _block() async {
    if (_otherUserId == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Block this person?'),
        content: const Text(
            'You will not be matched with them again. This doesn\'t end the conversation.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Block'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await ChatService.instance.blockUser(_otherUserId!);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Blocked.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<String?> _pickReason() async {
    const reasons = [
      'Harassment',
      'Threatening behavior',
      'Sexual content',
      'Spam',
      'Dangerous advice',
      'Other',
    ];
    return showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(
              title: Text('Report',
                  style: TextStyle(fontWeight: FontWeight.w800)),
            ),
            for (final r in reasons)
              ListTile(
                title: Text(r),
                onTap: () => Navigator.pop(context, r),
              ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _msgSub?.cancel();
    _convSub?.cancel();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ended = _conversation.status == 'ended';
    final waiting = _conversation.status == 'waiting';

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _leaveConversation();
      },
      child: Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            if (_otherAvatarUrl != null) ...[
              CircleAvatar(
                radius: 18,
                backgroundImage: NetworkImage(_otherAvatarUrl!),
              ),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_otherName,
                      overflow: TextOverflow.ellipsis),
                  if (waiting)
                    Text('Waiting for a peer…',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: theme.colorScheme.primary))
                  else if (ended)
                    Text('Conversation ended',
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant))
                  else
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_e2eeActive) ...[
                          Icon(Icons.lock_outline,
                              size: 13,
                              color: theme.colorScheme.primary),
                          const SizedBox(width: 4),
                        ],
                        Text(_e2eeActive ? 'Connected · End-to-end encrypted'
                            : 'Connected',
                            style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.primary)),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'end':
                  _endConversation();
                case 'recommend':
                  _recommendAction();
                case 'report':
                  _report();
                case 'block':
                  _block();
              }
            },
            itemBuilder: (context) => [
              if (_conversation.isActive)
                const PopupMenuItem(
                  value: 'recommend',
                  child: Text('🌱 Recommend a 1% action'),
                ),
              if (_conversation.isActive)
                const PopupMenuItem(
                  value: 'end',
                  child: Text('End conversation'),
                ),
              const PopupMenuItem(value: 'report', child: Text('Report')),
              const PopupMenuItem(value: 'block', child: Text('Block')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(child: _buildMessages()),
          if (!ended)
            _buildInput(theme)
          else
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'This conversation has ended. Take care. 🌱',
                style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
        ],
      ),
      ),
    );
  }

  Widget _buildMessages() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return EmptyState(
        icon: Icons.cloud_off_outlined,
        title: 'Couldn\'t load messages',
        message: 'You\'re offline. Reconnect to continue chatting.',
        action: OutlinedButton(onPressed: _loadMessages, child: const Text('Retry')),
      );
    }
    if (_messages.isEmpty) {
      return const EmptyState(
        icon: Icons.waving_hand_outlined,
        title: 'Say hello',
        message: 'You can start whenever you\'re ready.',
      );
    }
    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: _messages.length,
      itemBuilder: (context, i) => _MessageBubble(
        message: _messages[i],
        mine: _messages[i].senderId == _myId,
      ),
    );
  }

  Widget _buildInput(ThemeData theme) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          border: Border(
            top: BorderSide(color: theme.colorScheme.outlineVariant, width: 0.5),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: _input,
                minLines: 1,
                maxLines: 5,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText: 'Type a message…',
                  isDense: true,
                ),
                onSubmitted: (_) => _send(),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              tooltip: 'Send',
              onPressed: _conversation.isActive ? _send : null,
              icon: _sending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.2, color: Colors.white),
                    )
                  : const Icon(Icons.send),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, required this.mine});

  final ChatMessage message;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (message.isSystem) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              message.message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
        ),
      );
    }

    final isActionRec = message.isActionRecommendation;
    final color = mine
        ? theme.colorScheme.primary
        : theme.colorScheme.surfaceContainerHighest;
    final fg = mine
        ? theme.colorScheme.onPrimary
        : theme.colorScheme.onSurface;

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        decoration: BoxDecoration(
          color: isActionRec
              ? theme.colorScheme.primaryContainer
              : color,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isActionRec) ...[
              Text('🌱 PEER RECOMMENDED',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  )),
              const SizedBox(height: 4),
            ],
            Text(message.message,
                style: theme.textTheme.bodyMedium?.copyWith(color: fg)),
            const SizedBox(height: 2),
            Text(
              _time(message.createdAt),
              style: theme.textTheme.labelSmall?.copyWith(
                color: mine
                    ? theme.colorScheme.onPrimary.withValues(alpha: 0.7)
                    : theme.colorScheme.onSurfaceVariant,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _time(DateTime t) {
    final now = DateTime.now();
    final local = t.toLocal();
    final h = local.hour.toString().padLeft(2, '0');
    final m = local.minute.toString().padLeft(2, '0');
    final sameDay = now.year == local.year &&
        now.month == local.month &&
        now.day == local.day;
    if (sameDay) return '$h:$m';
    return '${local.day}/${local.month} $h:$m';
  }
}

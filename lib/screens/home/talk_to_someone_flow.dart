import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../services/chat_service.dart';
import '../chat/chat_screen.dart';

/// "Talk to Someone" flow.
///
/// Starts a waiting conversation and tries to match with another person who is
/// also looking to talk. If no one is waiting, watches the conversation in real
/// time until the other person's match activates it.
class TalkToSomeoneFlow extends StatefulWidget {
  const TalkToSomeoneFlow({super.key});

  @override
  State<TalkToSomeoneFlow> createState() => _TalkToSomeoneFlowState();
}

class _TalkToSomeoneFlowState extends State<TalkToSomeoneFlow> {
  bool _finding = false;
  bool _waiting = false;
  bool _noPeer = false;
  String? _error;
  StreamSubscription<Conversation>? _sub;
  bool _opened = false;

  @override
  void initState() {
    super.initState();
    _checkExisting();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _checkExisting() async {
    try {
      final existing = await ChatService.instance.fetchActiveConversation();
      if (!mounted || existing == null) return;
      _open(existing.conversation);
    } catch (_) {}
  }

  Future<void> _find() async {
    setState(() {
      _finding = true;
      _error = null;
    });
    try {
      final conversation = await ChatService.instance.startConversation();
      final matched = await ChatService.instance.findMatch();
      if (!mounted) return;
      if (matched != null && matched.status == 'active') {
        _open(matched);
        return;
      }
      // Still waiting — subscribe to this conversation for a later match.
      setState(() {
        _waiting = true;
        _noPeer = true;
      });
      _watch(conversation.id);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _waiting = false;
      });
    } finally {
      if (mounted) setState(() => _finding = false);
    }
  }

  void _watch(String conversationId) {
    _sub?.cancel();
    _sub = ChatService.instance
        .streamConversation(conversationId)
        .listen((conversation) {
      if (!mounted || _opened) return;
      if (conversation.status == 'active') {
        _open(conversation);
      } else if (conversation.status == 'ended' ||
          conversation.status == 'cancelled') {
        setState(() => _waiting = false);
      }
    });
  }

  Future<void> _tryAgain() async {
    setState(() => _finding = true);
    try {
      final matched = await ChatService.instance.findMatch();
      if (!mounted) return;
      if (matched != null && matched.status == 'active') {
        _open(matched);
        return;
      }
      setState(() => _noPeer = true);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _finding = false);
    }
  }

  Future<void> _cancelWaiting() async {
    try {
      await ChatService.instance.cancelWaitingConversation();
      await _sub?.cancel();
    } catch (_) {}
    if (mounted) Navigator.of(context).maybePop();
  }

  void _open(Conversation conversation) {
    if (_opened) return;
    _opened = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ChatScreen(conversation: conversation),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Talk to someone')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Container(
                  width: 72,
                  height: 72,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: const Text('💬', style: TextStyle(fontSize: 36)),
                ),
                const SizedBox(height: 20),
                Text(
                  'We can connect you with a real person who understands what you\'re going through.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 10),
                Text(
                  'You don\'t have to know exactly what to say. A peer who does something similar to you will talk with you privately, one on one.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 28),

                if (_error != null)
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(_error!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: theme.colorScheme.onErrorContainer)),
                  ),

                if (!_waiting && _error == null)
                  FilledButton.icon(
                    onPressed: _finding ? null : _find,
                    icon: _finding
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2.2),
                          )
                        : const Icon(Icons.people_outline),
                    label: const Text('Find Someone'),
                  ),

                if (_waiting) ...[
                  const SizedBox(height: 8),
                  if (_noPeer)
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          const SizedBox(
                            width: 28,
                            height: 28,
                            child: CircularProgressIndicator(strokeWidth: 2.4),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            'No one is online right now.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'We\'ll connect you with a peer as soon as someone else wants to talk.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant),
                          ),
                          const SizedBox(height: 16),
                          OutlinedButton.icon(
                            onPressed: _finding ? null : _tryAgain,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Try again'),
                          ),
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: _cancelWaiting,
                            child: const Text('Cancel request'),
                          ),
                        ],
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

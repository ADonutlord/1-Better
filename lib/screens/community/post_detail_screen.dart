import 'package:flutter/material.dart';

import '../../core/app_state.dart';
import '../../models/models.dart';
import '../../services/community_service.dart';
import '../../services/supabase_service.dart';

/// A single post's thread: the question and every real-person answer, with a
/// composer at the bottom. New answers stream in live.
class PostDetailScreen extends StatefulWidget {
  const PostDetailScreen({super.key, required this.post});

  final Post post;

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  final CommunityService _service = CommunityService.instance;
  final _answerController = TextEditingController();
  final _scroll = ScrollController();

  late List<PostAnswer> _answers;
  bool _loading = true;
  bool _posting = false;
  String? _error;
  Stream<List<PostAnswer>>? _stream;

  String get _userId => SupabaseService.instance.client.auth.currentUser!.id;
  bool get _isOwnPost => widget.post.userId == _userId;
  bool get _isStaff {
    final p = AppState.instance.loop?.profile;
    return (p?.isAdmin ?? false) || (p?.isOwner ?? false);
  }
  bool get _canDeletePost => _isOwnPost || _isStaff;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _stream = null;
    _answerController.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final answers = await _service.fetchAnswers(widget.post.id);
      if (!mounted) return;
      setState(() {
        _answers = answers;
        _loading = false;
      });
      _startStream();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load answers.';
        _loading = false;
      });
    }
  }

  void _startStream() {
    _stream = _service.streamAnswers(widget.post.id);
    _stream!.listen((rows) {
      if (!mounted) return;
      setState(() => _answers = rows);
    }, onError: (_) {});
  }

  Future<void> _submitAnswer() async {
    final text = _answerController.text.trim();
    if (text.isEmpty || _posting || _isOwnPost) return;
    setState(() => _posting = true);
    try {
      await _service.createAnswer(postId: widget.post.id, answer: text);
      _answerController.clear();
      setState(() => _posting = false);
    } catch (e) {
      if (!mounted) return;
      setState(() => _posting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not post your answer.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final author = widget.post.author;
    final name = (author?.displayName.isNotEmpty ?? false)
        ? author!.displayName
        : 'Community member';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Community'),
        actions: [
          if (_canDeletePost)
            IconButton(
              tooltip: _isStaff && !_isOwnPost ? 'Moderate post' : 'Delete post',
              icon: const Icon(Icons.delete_outline),
              onPressed: _deletePost,
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(_error!),
                            const SizedBox(height: 12),
                            FilledButton(
                              onPressed: _load,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                    : ListView(
                        controller: _scroll,
                        padding: const EdgeInsets.all(12),
                        children: [
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 18,
                                        backgroundColor:
                                            theme.colorScheme.primaryContainer,
                                        child: Text(
                                          name.isEmpty ? '?' : name[0].toUpperCase(),
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            color: theme.colorScheme
                                                .onPrimaryContainer,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Text(
                                        name,
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(fontWeight: FontWeight.w700),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    widget.post.question,
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(fontWeight: FontWeight.w800),
                                  ),
                                  if (widget.post.body.isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    Text(widget.post.body,
                                        style: theme.textTheme.bodyMedium),
                                  ],
                                ],
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                              'Answers (${_answers.length})',
                              style: theme.textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                          ),
                          if (_answers.isEmpty)
                            Padding(
                              padding: const EdgeInsets.all(24),
                              child: Center(
                                child: Text(
                                  _isOwnPost
                                      ? 'No answers yet. Check back soon!'
                                      : 'Be the first to answer.',
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            )
                          else
                            for (final a in _answers)
                              _AnswerTile(
                                answer: a,
                                isStaff: _isStaff,
                                onDelete: () => _deleteAnswer(a),
                              ),
                        ],
                      ),
          ),
          if (!_isOwnPost)
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 8, 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _answerController,
                        minLines: 1,
                        maxLines: 4,
                        maxLength: 4000,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                          hintText: 'Share your answer...',
                          counterText: '',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      onPressed:
                          _answerController.text.trim().isEmpty || _posting
                              ? null
                              : _submitAnswer,
                      icon: _posting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.send),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _deletePost() async {
    final title = (_isStaff && !_isOwnPost)
        ? 'Remove this post?'
        : 'Delete this post?';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: (_isStaff && !_isOwnPost)
            ? const Text(
                'You are moderating as staff. The post and all its answers '
                'will be removed for everyone.')
            : null,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      if (_isStaff && !_isOwnPost) {
        await _service.adminDeletePost(widget.post.id);
      } else {
        await _service.deletePost(widget.post.id);
      }
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not delete the post.')),
      );
    }
  }

  Future<void> _deleteAnswer(PostAnswer answer) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove this answer?'),
        content: Text(
            'Remove ${answer.author?.displayName ?? 'this member'}\'s answer '
            'for everyone?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _service.adminDeleteAnswer(answer.id);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not remove the answer.')),
      );
    }
  }
}

class _AnswerTile extends StatelessWidget {
  const _AnswerTile({
    required this.answer,
    this.isStaff = false,
    this.onDelete,
  });

  final PostAnswer answer;
  final bool isStaff;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final author = answer.author;
    final name = (author?.displayName.isNotEmpty ?? false)
        ? author!.displayName
        : 'Community member';
    final roleLabel = switch (author?.role) {
      'helper' => 'Helper',
      'admin' || 'owner' => 'Team',
      _ => null,
    };

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: theme.colorScheme.secondaryContainer,
                  child: Text(
                    name.isEmpty ? '?' : name[0].toUpperCase(),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onSecondaryContainer,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      if (roleLabel != null)
                        Text(
                          roleLabel,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                ),
                Text(
                  _timeAgo(answer.createdAt),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                if (isStaff) ...[
                  const SizedBox(width: 4),
                  InkWell(
                    onTap: onDelete,
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        Icons.close,
                        size: 18,
                        color: theme.colorScheme.error,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            Text(answer.answer, style: theme.textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}

String _timeAgo(DateTime time) {
  final diff = DateTime.now().difference(time.toLocal());
  if (diff.inMinutes < 1) return 'now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m';
  if (diff.inHours < 24) return '${diff.inHours}h';
  if (diff.inDays < 7) return '${diff.inDays}d';
  return '${time.day}/${time.month}';
}

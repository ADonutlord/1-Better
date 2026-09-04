import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../services/community_service.dart';
import 'community_helpers.dart';
import 'create_post_screen.dart';
import 'post_detail_screen.dart';

/// Instagram-style community feed: real people ask questions, real people
/// answer. New posts and answers stream in live via Supabase realtime.
class CommunityFeedScreen extends StatefulWidget {
  const CommunityFeedScreen({super.key});

  @override
  State<CommunityFeedScreen> createState() => _CommunityFeedScreenState();
}

class _CommunityFeedScreenState extends State<CommunityFeedScreen> {
  final CommunityService _service = CommunityService.instance;
  List<Post> _posts = [];
  Map<String, int> _counts = {};
  bool _loading = true;
  String? _error;
  Stream<List<Post>>? _stream;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _stream = null;
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final posts = await _service.fetchPosts();
      final counts =
          await _service.answerCounts(posts.map((p) => p.id).toList());
      // Populate the shared author cache so realtime rows (which lack the
      // join) can still resolve display name, role and picture for everyone.
      await _service.fetchAuthors(posts.map((p) => p.userId).toList());
      if (!mounted) return;
      setState(() {
        _posts = posts;
        _counts = counts;
        _loading = false;
      });
      _startStream();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load the community feed.';
        _loading = false;
      });
    }
  }

  void _startStream() {
    _stream = _service.streamPosts();
    _stream!.listen((rows) {
      if (!mounted) return;
      final existingById = {for (final p in _posts) p.id: p};
      final byId = <String, Post>{};
      for (final p in _posts) {
        byId[p.id] = p;
      }
      final missingAuthors = <String>{};
      for (final p in rows) {
        // Realtime payloads lack the `profiles` join. When we already have a
        // fetched copy with the author info, keep it.
        final existing = existingById[p.id];
        if (existing != null && existing.author != null) {
          byId[p.id] = existing;
          continue;
        }
        // A brand-new post arrived without its author join; queue its author
        // id so we can resolve the display name/role/picture from profiles.
        if (p.author == null) {
          missingAuthors.add(p.userId);
        }
        byId[p.id] = p;
      }
      // Resolve any unknown authors into the cache (name/role/avatar), then
      // rebuild so [resolveAuthor] picks them up.
      _resolveAuthors(missingAuthors);
      final merged = byId.values.toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      setState(() {
        _posts = merged;
      });
      // Refresh answer counts so new answers show up without a manual pull.
      _refreshCounts();
    }, onError: (_) {});
  }

  Future<void> _resolveAuthors(Set<String> userIds) async {
    if (userIds.isEmpty) return;
    try {
      await _service.fetchAuthors(userIds.toList());
      if (!mounted) return;
      setState(() {});
    } catch (_) {
      // Author resolution is cosmetic; never break the feed over it.
    }
  }

  Future<void> _refreshCounts() async {
    try {
      final counts =
          await _service.answerCounts(_posts.map((p) => p.id).toList());
      if (!mounted) return;
      setState(() => _counts = counts);
    } catch (_) {
      // Counts are cosmetic; never break the feed over them.
    }
  }

  Future<void> _openCreate() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const CreatePostScreen()),
    );
    if (created == true) await _load();
  }

  void _openPost(Post post) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => PostDetailScreen(post: post)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Community'),
        actions: [
          IconButton(
            tooltip: 'New post',
            icon: const Icon(Icons.add_circle_outline),
            onPressed: _openCreate,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreate,
        icon: const Icon(Icons.edit_outlined),
        label: const Text('Ask the community'),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!),
            const SizedBox(height: 12),
            FilledButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }
    if (_posts.isEmpty) {
      return _EmptyFeed(onAsk: _openCreate);
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 96),
        itemCount: _posts.length,
        itemBuilder: (context, i) => _PostCard(
          post: _posts[i],
          answerCount: _counts[_posts[i].id] ?? 0,
          onTap: () => _openPost(_posts[i]),
        ),
      ),
    );
  }
}

class _PostCard extends StatelessWidget {
  const _PostCard({
    required this.post,
    required this.answerCount,
    required this.onTap,
  });

  final Post post;
  final int answerCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final resolved =
        resolveAuthor(userId: post.userId, embeddedAuthor: post.author);
    final name = resolved.name;
    final roleLabel = resolved.roleLabel;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: theme.colorScheme.primaryContainer,
                    foregroundImage: resolved.hasAvatar
                        ? NetworkImage(resolved.avatarUrl!)
                        : null,
                    child: Text(
                      resolved.initial,
                      style: TextStyle(
                        color: theme.colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: theme.textTheme.bodyMedium
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
                    _timeAgo(post.createdAt),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                post.question,
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              if (post.body.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  post.body,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium,
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.chat_bubble_outline,
                      size: 18,
                      color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Text(
                    '$answerCount ${answerCount == 1 ? 'answer' : 'answers'}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyFeed extends StatelessWidget {
  const _EmptyFeed({required this.onAsk});

  final VoidCallback onAsk;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('🌱', style: theme.textTheme.displaySmall),
            const SizedBox(height: 12),
            Text(
              'No posts yet',
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              'Be the first to ask the community a question.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onAsk,
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Ask a question'),
            ),
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

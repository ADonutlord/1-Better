import 'package:flutter/material.dart';

import '../../services/community_service.dart';

/// Compose a question to post to the community feed.
class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final _question = TextEditingController();
  final _body = TextEditingController();
  bool _posting = false;

  @override
  void dispose() {
    _question.dispose();
    _body.dispose();
    super.dispose();
  }

  bool get _canSubmit => _question.text.trim().isNotEmpty && !_posting;

  Future<void> _submit() async {
    if (!_canSubmit) return;
    setState(() => _posting = true);
    try {
      await CommunityService.instance.createPost(
        question: _question.text.trim(),
        body: _body.text.trim(),
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _posting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not post. Please try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ask the community'),
        actions: [
          TextButton(
            onPressed: _canSubmit ? _submit : null,
            child: _posting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Post'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Ask a question and real people in the community will answer it.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _question,
            maxLength: 2000,
            decoration: const InputDecoration(
              labelText: 'Question',
              hintText: 'e.g. How do I beat procrastination?',
              border: OutlineInputBorder(),
            ),
            textCapitalization: TextCapitalization.sentences,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _body,
            maxLines: 5,
            maxLength: 4000,
            decoration: const InputDecoration(
              labelText: 'Details (optional)',
              hintText: 'Add more context so people can help you better...',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
            textCapitalization: TextCapitalization.sentences,
          ),
        ],
      ),
    );
  }
}

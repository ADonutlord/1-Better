import 'package:flutter/material.dart';

/// Honest crisis information. This app is NOT an emergency service.
class UrgentHelpScreen extends StatelessWidget {
  const UrgentHelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Urgent help')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Card(
              color: theme.colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Text('🚨',
                        style: theme.textTheme.displaySmall),
                    const SizedBox(height: 12),
                    Text('If you are in immediate danger, call your local '
                        'emergency number right now.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.onErrorContainer,
                            fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text('We are not an emergency service',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(
              '1% Better is peer support. The people you talk to are real '
              'people who listen — they are not therapists, doctors or crisis '
              'workers, and they will never pretend to be.\n\n'
              'If you are in crisis or thinking about hurting yourself, '
              'please reach out to a professional or a crisis line near you '
              'instead of (or as well as) talking here.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),
            Text('What you can do right now',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            const _Tip('Contact local emergency services or your country\'s '
                'emergency number.'),
            const _Tip('Call or message someone you trust — tell them how '
                'urgent it is.'),
            const _Tip('Find a mental-health crisis line or support service '
                'in your region and call it.'),
            const _Tip('If you\'re in immediate physical danger, get to a '
                'safe place if you can.'),
            const _Tip('Search the web for "mental health crisis line" plus '
                'your country — legitimate services appear first.'),
          ],
        ),
      ),
    );
  }
}

class _Tip extends StatelessWidget {
  const _Tip(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
          Expanded(
            child: Text(text, style: theme.textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}

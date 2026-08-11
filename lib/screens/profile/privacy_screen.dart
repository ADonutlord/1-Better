import 'package:flutter/material.dart';

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text('What we store',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            const _Item(
              icon: Icons.person_outline,
              text: 'Your display name, level, XP and streaks. We never show '
                  'your email or other contact details to anyone.',
            ),
            const _Item(
              icon: Icons.mood_outlined,
              text: 'Your mood check-ins. These are private to you and are '
                  'only used to personalise your next 1% action.',
            ),
            const _Item(
              icon: Icons.chat_bubble_outline,
              text: 'Your conversations. Only you and the person you talk to '
                  'can see them.',
            ),
            const _Item(
              icon: Icons.eco_outlined,
              text: 'Your completed actions. Used only to recommend better '
                  'ones later.',
            ),
            const SizedBox(height: 20),
            Text('How we protect it',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            const _Item(
              icon: Icons.lock_outline,
              text: 'Passwords are handled by Supabase Auth and are never '
                  'stored in our database.',
            ),
            const _Item(
              icon: Icons.shield_outlined,
              text: 'Row-level security means you can only ever read your own '
                  'data and conversations you belong to.',
            ),
            const SizedBox(height: 20),
            Text('Your control',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            const _Item(
              icon: Icons.block_outlined,
              text: 'You can block users from Profile → Blocked users.',
            ),
            const _Item(
              icon: Icons.delete_outline,
              text: 'You can delete your account from Profile → Delete '
                  'account. This removes everything, permanently.',
            ),
            const SizedBox(height: 20),
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  '1% Better is peer support, not therapy or emergency help. '
                  'If you are in crisis, please contact local emergency '
                  'services or a crisis line.',
                  style: TextStyle(fontSize: 13),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Item extends StatelessWidget {
  const _Item({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text, style: theme.textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}

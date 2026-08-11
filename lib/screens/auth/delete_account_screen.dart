import 'package:flutter/material.dart';
import 'package:one_percent_better/services/auth_service.dart';

/// Confirmation flow before permanently deleting the account.
class DeleteAccountScreen extends StatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  State<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends State<DeleteAccountScreen> {
  bool _confirming = false;
  bool _deleting = false;

  Future<void> _delete() async {
    setState(() => _deleting = true);
    try {
      await AuthService.instance.deleteAccount();
      // User deleted; the auth listener resets the app to the auth gate.
    } catch (e) {
      if (!mounted) return;
      setState(() => _deleting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not delete account: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Delete account')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.warning_amber_rounded,
                          size: 56, color: theme.colorScheme.error),
                      const SizedBox(height: 16),
                      Text('Delete your account?',
                          style: theme.textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 12),
                      const Text(
                        'This permanently removes your profile, mood history, '
                        'messages and progress. It cannot be undone.\n\n'
                        'Your progress is still here until you do this.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      if (!_confirming)
                        FilledButton.tonalIcon(
                          onPressed: () => setState(() => _confirming = true),
                          icon: const Icon(Icons.delete_outline),
                          label: const Text('Continue'),
                        )
                      else ...[
                        const Text('Are you sure? This is permanent.'),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () =>
                                    setState(() => _confirming = false),
                                child: const Text('Keep my account'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: FilledButton(
                                style: FilledButton.styleFrom(
                                  backgroundColor: theme.colorScheme.error,
                                ),
                                onPressed: _deleting ? null : _delete,
                                child: _deleting
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2.2,
                                            color: Colors.white),
                                      )
                                    : const Text('Delete'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

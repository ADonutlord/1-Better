import 'dart:async';

import 'package:flutter/material.dart';
import 'package:one_percent_better/core/utils/validators.dart';
import 'package:one_percent_better/screens/auth/widgets/auth_scaffold.dart';
import 'package:one_percent_better/services/auth_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _newPassword = TextEditingController();
  bool _submitting = false;
  bool _requested = false;
  bool _recoveryMode = false;
  bool _obscure = true;
  StreamSubscription<AuthState>? _authSub;

  @override
  void initState() {
    super.initState();
    // If the user arrived here via a recovery link, listen for it.
    _authSub = AuthService.instance.authStateChanges.listen((state) {
      if (state.event == AuthChangeEvent.passwordRecovery && mounted) {
        setState(() => _recoveryMode = true);
      }
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _email.dispose();
    _newPassword.dispose();
    super.dispose();
  }

  Future<void> _requestReset() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _submitting = true);
    try {
      await AuthService.instance.resetPassword(_email.text.trim());
      setState(() => _requested = true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(Validator.readableError(e))),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _savePassword() async {
    if (_newPassword.text.length < 6) return;
    setState(() => _submitting = true);
    try {
      await AuthService.instance.updatePassword(_newPassword.text);
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password updated. Sign in again.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(Validator.readableError(e))),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_recoveryMode) {
      return AuthScaffold(
        title: 'Choose a new password',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _newPassword,
              obscureText: _obscure,
              decoration: InputDecoration(
                labelText: 'New password',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _submitting ? null : _savePassword,
              child: const Text('Save new password'),
            ),
          ],
        ),
      );
    }

    return AuthScaffold(
      title: 'Reset your password',
      subtitle: _requested
          ? 'Check your inbox — we sent you a reset link.'
          : 'We\'ll email you a link to reset it.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_requested)
            const Padding(
              padding: EdgeInsets.only(bottom: 16),
              child: Icon(Icons.mark_email_read_outlined,
                  size: 56, color: Color(0xFF3E7C4F)),
            )
          else ...[
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.mail_outline),
              ),
              validator: Validator.email,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _requestReset(),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _submitting ? null : _requestReset,
              child: const Text('Send reset link'),
            ),
          ],
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Back to sign in'),
          ),
        ],
      ),
    );
  }
}

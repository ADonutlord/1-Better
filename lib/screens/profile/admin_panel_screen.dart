import 'package:flutter/material.dart';

import '../../core/app_state.dart';
import '../../services/supabase_service.dart';

/// Moderation panel: change an account's role by email.
/// Only admins and the owner can use it; the server enforces the same rule
/// plus owner-only access to the `testing`/`owner` roles.
class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> {
  final _email = TextEditingController();
  String? _role = 'user';
  bool _saving = false;
  Map<String, dynamic>? _result;

  final _uid = TextEditingController();
  bool _suspendAction = true;
  String? _duration = '7 days';
  bool _suspending = false;
  Map<String, dynamic>? _suspendResult;

  final _levelEmail = TextEditingController();
  final _levelText = TextEditingController();
  bool _savingLevel = false;
  Map<String, dynamic>? _levelResult;

  final _streakEmail = TextEditingController();
  final _streakText = TextEditingController();
  bool _savingStreak = false;
  Map<String, dynamic>? _streakResult;

  static const _durations = <(String, String?)>[
    ('1 hour', '1 hour'),
    ('24 hours', '24 hours'),
    ('7 days', '7 days'),
    ('30 days', '30 days'),
    ('Permanent', null),
  ];

  @override
  void dispose() {
    _email.dispose();
    _uid.dispose();
    _levelEmail.dispose();
    _levelText.dispose();
    _streakEmail.dispose();
    _streakText.dispose();
    super.dispose();
  }

  bool get _isOwner {
    final profile = AppState.instance.loop?.profile;
    return profile?.isOwner ?? false;
  }

  List<String> get _roleOptions =>
      ['user', 'helper', 'admin', if (_isOwner) 'testing', if (_isOwner) 'wanniya', if (_isOwner) 'owner'];

  String _roleLabel(String role) => switch (role) {
        'user' => 'Member',
        'helper' => 'Helper',
        'admin' => 'Admin',
        'testing' => 'Tester',
        'wanniya' => 'Wanniya',
        'owner' => 'Owner',
        _ => role,
      };

  Future<void> _save() async {
    final email = _email.text.trim();
    if (email.isEmpty) {
      _snack('Enter the account email first.');
      return;
    }
    setState(() {
      _saving = true;
      _result = null;
    });
    try {
      final res = await SupabaseService.instance.client.rpc(
        'admin_set_role_by_email',
        params: {'p_email': email, 'p_role': _role},
      );
      if (!mounted) return;
      setState(() => _result = (res as Map<String, dynamic>?)?.cast<String, dynamic>());
      _snack('Role updated to ${_roleLabel(_role!)}. 🌱');
      await AppState.instance.loadDailyLoop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _result = null);
      _snack('$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _setLevel() async {
    final email = _levelEmail.text.trim();
    final level = int.tryParse(_levelText.text.trim());
    if (email.isEmpty || level == null) {
      _snack('Enter the account email and a level first.');
      return;
    }
    setState(() {
      _savingLevel = true;
      _levelResult = null;
    });
    try {
      final res = await SupabaseService.instance.client.rpc(
        'admin_set_level_by_email',
        params: {'p_email': email, 'p_level': level},
      );
      if (!mounted) return;
      final data = (res as Map<String, dynamic>?)?.cast<String, dynamic>();
      setState(() => _levelResult = data);
      _snack('Level set. 🌱');
      await AppState.instance.loadDailyLoop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _levelResult = null);
      _snack('$e');
    } finally {
      if (mounted) setState(() => _savingLevel = false);
    }
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _setStreak() async {
    final email = _streakEmail.text.trim();
    final streak = int.tryParse(_streakText.text.trim());
    if (email.isEmpty || streak == null) {
      _snack('Enter the account email and a streak first.');
      return;
    }
    setState(() {
      _savingStreak = true;
      _streakResult = null;
    });
    try {
      final res = await SupabaseService.instance.client.rpc(
        'admin_set_streak_by_email',
        params: {'p_email': email, 'p_streak': streak},
      );
      if (!mounted) return;
      final data = (res as Map<String, dynamic>?)?.cast<String, dynamic>();
      setState(() => _streakResult = data);
      _snack('Daily streak set. 🔥');
      await AppState.instance.loadDailyLoop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _streakResult = null);
      _snack('$e');
    } finally {
      if (mounted) setState(() => _savingStreak = false);
    }
  }

  Future<void> _suspend() async {
    final uid = _uid.text.trim();
    if (uid.isEmpty) {
      _snack('Enter the account user id first.');
      return;
    }
    setState(() {
      _suspending = true;
      _suspendResult = null;
    });
    try {
      final res = await SupabaseService.instance.client.rpc(
        'admin_suspend_account',
        params: {
          'p_user_id': uid,
          'p_suspend': _suspendAction,
          if (_suspendAction && _duration != null) 'p_duration': _duration,
        },
      );
      if (!mounted) return;
      final data = (res as Map<String, dynamic>?)?.cast<String, dynamic>();
      setState(() => _suspendResult = data);
      _snack(_suspendAction
          ? 'Account suspended. 🚫'
          : 'Account reactivated. ✅');
    } catch (e) {
      if (!mounted) return;
      setState(() => _suspendResult = null);
      _snack('$e');
    } finally {
      if (mounted) setState(() => _suspending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Admin panel')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'Change an account\'s role by entering their email and picking '
                  'a role. Only admins and the owner can do this.',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Account email',
                        style: theme.textTheme.labelLarge
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      autocorrect: false,
                      decoration: const InputDecoration(
                        hintText: 'name@example.com',
                        prefixIcon: Icon(Icons.mail_outline),
                        isDense: true,
                      ),
                      onSubmitted: (_) => _save(),
                    ),
                    const SizedBox(height: 18),
                    Text('New role',
                        style: theme.textTheme.labelLarge
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: _role,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.badge_outlined),
                        isDense: true,
                      ),
                      items: [
                        for (final r in _roleOptions)
                          DropdownMenuItem(value: r, child: Text(_roleLabel(r))),
                      ],
                      onChanged: (value) =>
                          setState(() => _role = value ?? 'user'),
                    ),
                    if (!_isOwner) ...[
                      const SizedBox(height: 10),
                      Text(
                        'Tester and Owner roles are reserved for the owner account.',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _saving ? null : _save,
                        icon: _saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2.2, color: Colors.white),
                              )
                            : const Icon(Icons.shield_outlined),
                        label: const Text('Update role'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Suspend or reactivate an account',
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(
                      'Enter the account\'s user id (uid). Suspensions can be '
                      'temporary (the account unlocks automatically) or '
                      'permanent. Only admins and the owner can do this.',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _uid,
                      autocorrect: false,
                      enableSuggestions: false,
                      decoration: const InputDecoration(
                        hintText: 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx',
                        prefixIcon: Icon(Icons.person_pin_outlined),
                        isDense: true,
                      ),
                      onSubmitted: (_) => _suspend(),
                    ),
                    const SizedBox(height: 14),
                    SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment(
                          value: true,
                          label: Text('Suspend'),
                          icon: Icon(Icons.block),
                        ),
                        ButtonSegment(
                          value: false,
                          label: Text('Reactivate'),
                          icon: Icon(Icons.check_circle_outline),
                        ),
                      ],
                      selected: {_suspendAction},
                      onSelectionChanged: (value) =>
                          setState(() => _suspendAction = value.first),
                    ),
                    if (_suspendAction) ...[
                      const SizedBox(height: 14),
                      Text('For how long?',
                          style: theme.textTheme.labelLarge
                              ?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String?>(
                        initialValue: _duration,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.timer_outlined),
                          isDense: true,
                        ),
                        items: [
                          for (final (label, value) in _durations)
                            DropdownMenuItem(value: value, child: Text(label)),
                        ],
                        onChanged: (value) =>
                            setState(() => _duration = value),
                      ),
                    ],
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _suspending ? null : _suspend,
                        style: FilledButton.styleFrom(
                          backgroundColor: _suspendAction
                              ? theme.colorScheme.error
                              : null,
                        ),
                        icon: _suspending
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2.2, color: Colors.white),
                              )
                            : Icon(_suspendAction
                                ? Icons.block
                                : Icons.restore),
                        label: Text(_suspendAction
                            ? 'Suspend account'
                            : 'Reactivate account'),
                      ),
                    ),
                    if (_suspendResult != null) ...[
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Icon(
                            _suspendResult!['suspended'] == true
                                ? Icons.block
                                : Icons.check_circle,
                            color: _suspendResult!['suspended'] == true
                                ? theme.colorScheme.error
                                : const Color(0xFF2E5C3A),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              '${_suspendResult!['display_name'] ?? 'Account'} '
                              '${_suspendResult!['suspended'] == true ? 'is now suspended' : 'is active again'}',
                              style: theme.textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                      if ((_suspendResult!['suspended'] == true) &&
                          _suspendResult!['suspended_until'] != null &&
                          (_suspendResult!['suspended_until'] as String)
                              .isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          (_suspendResult!['suspended_until'] == 'infinity')
                              ? 'Permanently suspended'
                              : 'Suspended until '
                                  '${_suspendResult!['suspended_until']}',
                          style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ),
            if (_isOwner) ...[
              const SizedBox(height: 14),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Set account level (owner only)',
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text(
                        'Set any account to any level (1–200) by entering '
                        'their email. Their XP is adjusted to match.',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _levelEmail,
                        keyboardType: TextInputType.emailAddress,
                        autocorrect: false,
                        decoration: const InputDecoration(
                          hintText: 'name@example.com',
                          prefixIcon: Icon(Icons.mail_outline),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _levelText,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          hintText: 'Level (1–200)',
                          prefixIcon: Icon(Icons.stars_outlined),
                          isDense: true,
                        ),
                        onSubmitted: (_) => _setLevel(),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _savingLevel ? null : _setLevel,
                          icon: _savingLevel
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2.2, color: Colors.white),
                                )
                              : const Icon(Icons.workspace_premium_outlined),
                          label: const Text('Set level'),
                        ),
                      ),
                      if (_levelResult != null) ...[
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            const Icon(Icons.workspace_premium,
                                color: Color(0xFF2E5C3A)),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                '${_levelResult!['display_name'] ?? _levelResult!['email']} '
                                'is now level ${_levelResult!['level']} '
                                '(${_levelResult!['total_xp']} XP)',
                                style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w700),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
            if (_isOwner) ...[
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Set daily streak (owner only)',
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text(
                        'Set any account\'s daily streak by entering their '
                        'email and the number of days. Their last action date '
                        'is set to today so the streak shows as live.',
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _streakEmail,
                        keyboardType: TextInputType.emailAddress,
                        autocorrect: false,
                        decoration: const InputDecoration(
                          hintText: 'name@example.com',
                          prefixIcon: Icon(Icons.mail_outline),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _streakText,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          hintText: 'Streak in days',
                          prefixIcon: Icon(Icons.local_fire_department_outlined),
                          isDense: true,
                        ),
                        onSubmitted: (_) => _setStreak(),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _savingStreak ? null : _setStreak,
                          icon: _savingStreak
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2.2, color: Colors.white),
                                )
                              : const Icon(Icons.local_fire_department),
                          label: const Text('Set streak'),
                        ),
                      ),
                      if (_streakResult != null) ...[
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            const Icon(Icons.local_fire_department,
                                color: Color(0xFF2E5C3A)),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                '${_streakResult!['display_name'] ?? _streakResult!['email']} '
                                'is now on a ${_streakResult!['current_streak']}-day streak '
                                '(best: ${_streakResult!['longest_streak']})',
                                style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w700),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
            if (_result != null) ...[
              const SizedBox(height: 14),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.check_circle,
                              color: Color(0xFF2E5C3A)),
                          const SizedBox(width: 10),
                          Text(
                            '${_result!['display_name'] ?? _result!['email']} '
                            'is now ${_roleLabel((_result!['role'] ?? _role).toString())}',
                            style: theme.textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_result!['email']}',
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

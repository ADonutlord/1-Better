import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../../core/app_state.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme_controller.dart';
import '../../models/models.dart';
import '../../services/auth_service.dart';
import '../../widgets/xp_bar.dart';
import '../auth/delete_account_screen.dart';
import '../focus/focus_timer_screen.dart';
import 'admin_panel_screen.dart';
import 'blocked_users_screen.dart';
import 'privacy_screen.dart';
import 'urgent_help_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AppState _app = AppState.instance;
  final _nameController = TextEditingController();
  bool _editingName = false;
  bool _savingName = false;
  bool _savingAvatar = false;
  bool _savingProfile = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _avatarOptions(String? avatarUrl) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(
              title: Text(
                'Profile picture',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose a photo'),
              onTap: () => Navigator.pop(context, 'change'),
            ),
            if (avatarUrl != null && avatarUrl.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('Remove photo'),
                onTap: () => Navigator.pop(context, 'remove'),
              ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    if (choice == 'change') {
      await _changeAvatar();
    } else if (choice == 'remove') {
      await _removeAvatar();
    }
  }

  Future<void> _changeAvatar() async {
    const typeGroup = XTypeGroup(
      label: 'Images',
      extensions: ['png', 'jpg', 'jpeg', 'webp', 'gif'],
    );
    final file = await openFile(acceptedTypeGroups: const [typeGroup]);
    if (file == null || !mounted) return;

    final bytes = await file.readAsBytes();
    if (bytes.lengthInBytes > 5 * 1024 * 1024) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Image must be smaller than 5 MB.')),
      );
      return;
    }

    setState(() => _savingAvatar = true);
    try {
      final extension = file.name.split('.').last.toLowerCase();
      await AuthService.instance.updateAvatar(bytes, extension);
      await _app.loadDailyLoop();
      if (!mounted) return;
      setState(() => _savingAvatar = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile picture updated. 🌱')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _savingAvatar = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _removeAvatar() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove profile picture?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _savingAvatar = true);
    try {
      await AuthService.instance.removeAvatar();
      await _app.loadDailyLoop();
      if (!mounted) return;
      setState(() => _savingAvatar = false);
    } catch (e) {
      if (!mounted) return;
      setState(() => _savingAvatar = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _saveName() async {
    final name = _nameController.text.trim();
    if (name.length < 2) return;
    setState(() => _savingName = true);
    try {
      await AuthService.instance.updateDisplayName(name);
      await _app.loadDailyLoop();
      if (!mounted) return;
      setState(() {
        _editingName = false;
        _savingName = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _savingName = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _editProfession(String current) async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                'What do you do?',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
            ),
            for (final key in Professions.keys)
              ListTile(
                selected: key == current,
                title: Text(Professions.labelFor(key)),
                onTap: () => Navigator.pop(context, key),
              ),
          ],
        ),
      ),
    );
    if (picked == null || picked == current || !mounted) return;
    setState(() => _savingProfile = true);
    try {
      await AuthService.instance.updateProfile(profession: picked);
      await _app.loadDailyLoop();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Profession updated. 🌱')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _savingProfile = false);
    }
  }

  Future<void> _editAge(int? current) async {
    final controller = TextEditingController(text: current?.toString() ?? '');
    final age = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Your age'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Age (min 13)',
            prefixIcon: Icon(Icons.cake_outlined),
            isDense: true,
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final value = int.tryParse(controller.text.trim());
              if (value == null || value < 13 || value > 120) return;
              Navigator.pop(context, value);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (age == null || age == current || !mounted) return;
    setState(() => _savingProfile = true);
    try {
      await AuthService.instance.updateProfile(
        birthYear: DateTime.now().year - age,
      );
      await _app.loadDailyLoop();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Age updated. 🌱')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _savingProfile = false);
    }
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text('Your progress is safe — it\'s all saved.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Log out'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await AuthService.instance.logout();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListenableBuilder(
      listenable: _app,
      builder: (context, _) {
        final loop = _app.loop;
        final profile =
            loop?.profile ??
            const UserProfile(
              id: '',
              displayName: '',
              role: 'user',
              level: 1,
              totalXp: 0,
              currentStreak: 0,
              longestStreak: 0,
            );
        final name = profile.displayName;

        return Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(title: const Text('Profile')),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(22),
                  child: Row(
                    children: [
                      _ProfileAvatar(
                        name: name,
                        avatarUrl: profile.avatarUrl,
                        saving: _savingAvatar,
                        onTap: () => _avatarOptions(profile.avatarUrl),
                      ),
                      const SizedBox(width: 18),
                      Expanded(
                        child: _editingName
                            ? TextField(
                                controller: _nameController,
                                decoration: const InputDecoration(
                                  labelText: 'Display name',
                                  isDense: true,
                                ),
                                onSubmitted: (_) => _saveName(),
                              )
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name,
                                    style: theme.textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _roleLabel(profile.role),
                                    style: theme.textTheme.labelMedium
                                        ?.copyWith(
                                          color: theme.colorScheme.primary,
                                          fontWeight: FontWeight.w700,
                                        ),
                                  ),
                                  const SizedBox(height: 2),
                                  InkWell(
                                    onTap: _savingProfile
                                        ? null
                                        : () => _editProfession(
                                            profile.profession,
                                          ),
                                    borderRadius: BorderRadius.circular(6),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 2,
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.work_outline,
                                            size: 14,
                                            color: theme
                                                .colorScheme
                                                .onSurfaceVariant,
                                          ),
                                          const SizedBox(width: 6),
                                          Flexible(
                                            child: Text(
                                              Professions.labelFor(
                                                profile.profession,
                                              ),
                                              style: theme.textTheme.labelMedium
                                                  ?.copyWith(
                                                    color: theme
                                                        .colorScheme
                                                        .onSurfaceVariant,
                                                  ),
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          Icon(
                                            Icons.edit_outlined,
                                            size: 13,
                                            color: theme.colorScheme.primary,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  InkWell(
                                    onTap: _savingProfile
                                        ? null
                                        : () => _editAge(profile.age),
                                    borderRadius: BorderRadius.circular(6),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 2,
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.cake_outlined,
                                            size: 14,
                                            color: theme
                                                .colorScheme
                                                .onSurfaceVariant,
                                          ),
                                          const SizedBox(width: 6),
                                          Flexible(
                                            child: Text(
                                              profile.age != null
                                                  ? '${profile.age} years old'
                                                  : 'Set your age',
                                              style: theme.textTheme.labelMedium
                                                  ?.copyWith(
                                                    color: theme
                                                        .colorScheme
                                                        .onSurfaceVariant,
                                                  ),
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          Icon(
                                            Icons.edit_outlined,
                                            size: 13,
                                            color: theme.colorScheme.primary,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                      ),
                      IconButton(
                        tooltip: _editingName ? 'Save name' : 'Edit name',
                        icon: _savingName
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Icon(
                                _editingName
                                    ? Icons.check
                                    : Icons.edit_outlined,
                              ),
                        onPressed: _savingName
                            ? null
                            : () {
                                if (_editingName) {
                                  _saveName();
                                } else {
                                  _nameController.text = name;
                                  setState(() => _editingName = true);
                                }
                              },
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 14),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(22),
                  child: XpBar(totalXp: profile.totalXp),
                ),
              ),
              const SizedBox(height: 14),

              Card(
                child: Column(
                  children: [
                    _menuTile(
                      context,
                      Icons.dark_mode_outlined,
                      'Appearance',
                      'Light, dark, or match your system',
                      () {
                        showModalBottomSheet<void>(
                          context: context,
                          builder: (_) => const _ThemeModeSheet(),
                        );
                      },
                    ),
                    _menuTile(
                      context,
                      Icons.timer_outlined,
                      'Focus timer',
                      '25-minute focused sessions',
                      () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const FocusTimerScreen(),
                          ),
                        );
                      },
                    ),
                    _menuTile(
                      context,
                      Icons.shield_outlined,
                      'Privacy',
                      'What we store and how we protect it',
                      () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const PrivacyScreen(),
                          ),
                        );
                      },
                    ),
                    _menuTile(
                      context,
                      Icons.block_outlined,
                      'Blocked users',
                      'Manage who can\'t match with you',
                      () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const BlockedUsersScreen(),
                          ),
                        );
                      },
                    ),
                    _menuTile(
                      context,
                      Icons.emergency_outlined,
                      'Urgent help',
                      'Crisis resources that are not us',
                      () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const UrgentHelpScreen(),
                          ),
                        );
                      },
                    ),
                    if (profile.isAdmin || profile.isOwner)
                      _menuTile(
                        context,
                        Icons.admin_panel_settings_outlined,
                        'Admin panel',
                        'Change account roles',
                        () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const AdminPanelScreen(),
                            ),
                          );
                        },
                      ),
                    _menuTile(
                      context,
                      Icons.delete_outline,
                      'Delete account',
                      'Permanently remove your data',
                      () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const DeleteAccountScreen(),
                          ),
                        );
                      },
                      destructive: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Center(
                child: TextButton.icon(
                  onPressed: _logout,
                  icon: const Icon(Icons.logout),
                  label: const Text('Log out'),
                ),
              ),
              const SizedBox(height: 28),
              Center(
                child: Text(
                  '© Copyright of ADonutlord. All rights reserved',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _menuTile(
    BuildContext context,
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap, {
    bool destructive = false,
  }) {
    final theme = Theme.of(context);
    final color = destructive ? theme.colorScheme.error : null;
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          color: color ?? theme.colorScheme.onSurface,
        ),
      ),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }

  static String _roleLabel(String role) => switch (role) {
    'owner' => 'OWNER · THE BOSS',
    'admin' => 'ADMIN',
    'testing' => 'TESTER',
    _ => 'MEMBER',
  };
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({
    required this.name,
    required this.avatarUrl,
    required this.saving,
    required this.onTap,
  });

  final String name;
  final String? avatarUrl;
  final bool saving;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Stack(
      children: [
        CircleAvatar(
          radius: 34,
          backgroundColor: theme.colorScheme.primary,
          foregroundImage: (avatarUrl != null && avatarUrl!.isNotEmpty)
              ? NetworkImage(avatarUrl!)
              : null,
          child: avatarUrl == null || avatarUrl!.isEmpty
              ? Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '🌱',
                  style: const TextStyle(fontSize: 28, color: Colors.white),
                )
              : null,
        ),
        Positioned(
          right: 0,
          bottom: 0,
          child: Material(
            color: theme.colorScheme.secondaryContainer,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: saving ? null : onTap,
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: saving
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: theme.colorScheme.primary,
                        ),
                      )
                    : Icon(
                        Icons.photo_camera_outlined,
                        size: 18,
                        color: theme.colorScheme.onSecondaryContainer,
                      ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ThemeModeSheet extends StatefulWidget {
  const _ThemeModeSheet();
  @override
  State<_ThemeModeSheet> createState() => _ThemeModeSheetState();
}

class _ThemeModeSheetState extends State<_ThemeModeSheet> {
  final ThemeController _theme = ThemeController.instance;

  Future<void> _onLiquidChanged(bool enabled) async {
    if (enabled) {
      await _theme.setLiquid(true);
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Turn off Liquid Glass?'),
        content: const Text(
          'The background tree will not be clearly seen with this option '
          'turned off. Do you want to continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep it on'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Turn off'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _theme.setLiquid(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Appearance',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Choose how the app looks.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            ListenableBuilder(
              listenable: _theme,
              builder: (context, _) {
                final mode = _theme.mode;
                return SegmentedButton<ThemeMode>(
                  segments: const [
                    ButtonSegment(
                      value: ThemeMode.system,
                      label: Text('System'),
                      icon: Icon(Icons.brightness_auto),
                    ),
                    ButtonSegment(
                      value: ThemeMode.light,
                      label: Text('Light'),
                      icon: Icon(Icons.light_mode_outlined),
                    ),
                    ButtonSegment(
                      value: ThemeMode.dark,
                      label: Text('Dark'),
                      icon: Icon(Icons.dark_mode_outlined),
                    ),
                  ],
                  selected: {mode},
                  onSelectionChanged: (selection) =>
                      _theme.setMode(selection.first),
                );
              },
            ),
            const SizedBox(height: 8),
            ListenableBuilder(
              listenable: _theme,
              builder: (context, _) => SwitchListTile(
                contentPadding: EdgeInsets.zero,
                secondary: const Icon(Icons.water_drop_outlined),
                title: const Text(
                  'Liquid Glass',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: const Text('Frosted translucent surfaces, like iOS.'),
                value: _theme.liquid,
                onChanged: _onLiquidChanged,
              ),
            ),
            ListenableBuilder(
              listenable: _theme,
              builder: (context, _) => SwitchListTile(
                contentPadding: EdgeInsets.zero,
                secondary: const Icon(Icons.blur_on),
                title: const Text(
                  'Gaussian Blur',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: const Text(
                  'Real backdrop blur for the glass surfaces.',
                ),
                value: _theme.blur,
                onChanged: _theme.liquid ? _theme.setBlur : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

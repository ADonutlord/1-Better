import 'package:flutter/material.dart';

import '../core/app_state.dart';
import '../core/backdrop_controller.dart';
import '../services/ambient_sound_service.dart';

/// Opens the theme picker (sunshine, night, rain...) and applies the chosen
/// scene through [switchBackdropScene], so every switch asks about ambient
/// sounds.
Future<void> openThemeSwitcher(BuildContext context) async {
  final picked = await showModalBottomSheet<BackdropScene>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => const _ThemeSwitcherSheet(),
  );
  if (picked == null || !context.mounted) return;
  await switchBackdropScene(context, picked);
}

/// Applies [scene] if the user's check-in allows it, then always asks whether
/// to play ambient sounds. Returns true when the scenery changed.
Future<bool> switchBackdropScene(
  BuildContext context,
  BackdropScene scene,
) async {
  final mood = AppState.instance.loop?.latestMood?.mood;
  if (!BackdropController.sceneAllowed(scene, mood)) {
    if (context.mounted) await _showRainLocked(context);
    return false;
  }

  await BackdropController.instance.setScene(scene);
  if (!context.mounted) return false;

  // Always asked on a switch, exactly once per switch: the answer only lasts
  // until the next theme change.
  final answer = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Play ambient sounds?'),
      content: Text(
        'Play the ${scene.label.toLowerCase()} soundscape softly in the '
        'background while you use the app?',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Stay silent'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('Play sounds'),
        ),
      ],
    ),
  );

  // Dismissing the dialog leaves the current setting alone; only an explicit
  // answer changes it. Either way the scenery has already switched.
  if (answer != null) {
    await AmbientSoundService.instance.setEnabled(answer);
  }
  await AmbientSoundService.instance.sync(scene);
  if (context.mounted) _reportSoundError(context);
  return true;
}

/// Shows why ambient sound could not start, if it could not. A broken audio
/// stack must say so instead of failing quietly.
void _reportSoundError(BuildContext context) {
  final error = AmbientSoundService.instance.lastError;
  if (error == null || !context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Ambient sound could not start — $error')),
  );
}

Future<void> _showRainLocked(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Rain is for low days'),
      content: const Text(
        'The rain theme unlocks after a check-in with a low mood — sad, '
        'depressed, gloomy, bored or tired. Check in first and it will open '
        'up.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Got it'),
        ),
      ],
    ),
  );
}

class _ThemeSwitcherSheet extends StatelessWidget {
  const _ThemeSwitcherSheet();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final controller = BackdropController.instance;
    final mood = AppState.instance.loop?.latestMood?.mood;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: ListenableBuilder(
          listenable: controller,
          builder: (context, _) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Change the theme',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Sunshine, night, rain and more behind your tree.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              for (final scene in BackdropScene.values)
                _SceneTile(
                  scene: scene,
                  selected: controller.scene == scene,
                  allowed: BackdropController.sceneAllowed(scene, mood),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SceneTile extends StatelessWidget {
  const _SceneTile({
    required this.scene,
    required this.selected,
    required this.allowed,
  });

  final BackdropScene scene;
  final bool selected;
  final bool allowed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: selected
            ? theme.colorScheme.primaryContainer
            : theme.colorScheme.surfaceContainerHighest,
        child: Icon(
          scene.icon,
          size: 22,
          color: selected
              ? theme.colorScheme.onPrimaryContainer
              : theme.colorScheme.onSurfaceVariant,
        ),
      ),
      title: Text(
        scene.label,
        style: TextStyle(
          fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
        ),
      ),
      subtitle: Text(
        allowed ? scene.description : '🔒 Only after a low-mood check-in',
      ),
      trailing: selected
          ? Icon(Icons.check_circle, color: theme.colorScheme.primary)
          : const Icon(Icons.chevron_right),
      onTap: () async {
        if (!allowed) {
          await _showRainLocked(context);
          return;
        }
        if (context.mounted) Navigator.of(context).pop(scene);
      },
    );
  }
}

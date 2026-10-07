import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show IconData, Icons;
import 'package:shared_preferences/shared_preferences.dart';

import 'constants/app_constants.dart';

/// The scenery painted behind the tree on the home screen.
enum BackdropScene {
  meadow('Sunshine', 'A calm sunny daytime field', Icons.wb_sunny_outlined),
  blossom('Blossom', 'Warm dawn with drifting petals', Icons.local_florist),
  rain('Rain', 'A soft grey downpour', Icons.water_drop_outlined),
  snow('Snow', 'Quiet snowfall', Icons.ac_unit),
  night('Night', 'Stars, a moon and fireflies', Icons.nightlight_outlined);

  const BackdropScene(this.label, this.description, this.icon);

  final String label;
  final String description;
  final IconData icon;
}

/// Level-driven scenery decorations, so the live wallpaper visibly changes as
/// the user levels up instead of only growing smoothly.
class BackdropMilestones {
  BackdropMilestones._();

  /// Decorations in the order they unlock.
  static const List<({String id, int level, String label})> unlocks = [
    (id: 'grass', level: 3, label: 'Grass tufts'),
    (id: 'birds', level: 8, label: 'Birds'),
    (id: 'fireflies', level: 15, label: 'Fireflies'),
    (id: 'lanterns', level: 25, label: 'Lanterns'),
    (id: 'shootingStar', level: 40, label: 'Shooting star'),
  ];

  /// Ids of every decoration the given level has unlocked, in unlock order.
  static List<String> unlocked(int level) => [
    for (final u in unlocks)
      if (level >= u.level) u.id,
  ];

  /// Whether a single decoration is available at [level].
  static bool has(int level, String id) => unlocked(level).contains(id);

  /// The next decoration to unlock, or null once everything is unlocked.
  static ({String id, int level, String label})? next(int level) {
    for (final u in unlocks) {
      if (u.level > level) return u;
    }
    return null;
  }
}

/// Owns the live-wallpaper preference: whether the tree scenery animates, and
/// which [BackdropScene] sits behind it. Both choices are device-local
/// (SharedPreferences), like the theme settings.
class BackdropController extends ChangeNotifier {
  BackdropController._();

  static final BackdropController instance = BackdropController._();

  static const String _enabledKey = 'live_wallpaper';
  static const String _sceneKey = 'backdrop_scene';

  /// Rain is a comfort setting: it unlocks only when the user checked in with
  /// a low mood (sad, depressed, gloomy, bored or tired).
  static bool rainAllowed(String? mood) =>
      Moods.groupOf(mood) == Moods.negativeLow;

  /// Whether [scene] may be chosen for the given check-in [mood]. Only rain
  /// is gated; every other scene is always available.
  static bool sceneAllowed(BackdropScene scene, String? mood) =>
      scene != BackdropScene.rain || rainAllowed(mood);

  bool _enabled = true;
  bool get enabled => _enabled;

  BackdropScene _scene = BackdropScene.meadow;
  BackdropScene get scene => _scene;

  /// Resolves a persisted scene name, falling back to the default.
  static BackdropScene sceneFromKey(String? key) {
    for (final scene in BackdropScene.values) {
      if (scene.name == key) return scene;
    }
    return BackdropScene.meadow;
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _enabled = prefs.getBool(_enabledKey) ?? true;
    _scene = sceneFromKey(prefs.getString(_sceneKey));
    notifyListeners();
  }

  Future<void> setEnabled(bool value) async {
    if (value == _enabled) return;
    _enabled = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, value);
  }

  /// Changes the scenery, reporting whether it actually changed.
  Future<bool> setScene(BackdropScene scene) async {
    if (scene == _scene) return false;
    _scene = scene;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sceneKey, scene.name);
    return true;
  }
}

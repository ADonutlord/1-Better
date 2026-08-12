import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Controls the app theme: follow the system, or force light / dark.
/// Also controls the opt-in Liquid Glass appearance: frosted translucent
/// chrome, plus an optional real gaussian blur (only meaningful with the
/// frosted chrome enabled). The choices are persisted on device.
class ThemeController extends ChangeNotifier {
  ThemeController._();

  static final ThemeController instance = ThemeController._();

  static const _prefKey = 'theme_mode';
  static const _liquidKey = 'liquid_glass';
  static const _blurKey = 'liquid_blur';
  static const _system = 'system';
  static const _light = 'light';
  static const _dark = 'dark';

  ThemeMode _mode = ThemeMode.system;
  ThemeMode get mode => _mode;

  bool _liquid = false;
  bool get liquid => _liquid;

  bool _blur = false;
  bool get blur => _blur;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_prefKey);
    _mode = switch (value) {
      _dark => ThemeMode.dark,
      _light => ThemeMode.light,
      _ => ThemeMode.system,
    };
    _liquid = prefs.getBool(_liquidKey) ?? false;
    _blur = prefs.getBool(_blurKey) ?? false;
    notifyListeners();
  }

  Future<void> setMode(ThemeMode mode) async {
    if (mode == _mode) return;
    _mode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, switch (mode) {
      ThemeMode.dark => _dark,
      ThemeMode.light => _light,
      ThemeMode.system => _system,
    });
  }

  Future<void> setLiquid(bool enabled) async {
    if (enabled == _liquid) return;
    _liquid = enabled;
    if (!enabled) _blur = false;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_liquidKey, enabled);
    if (!enabled) await prefs.setBool(_blurKey, false);
  }

  /// Turns the real gaussian blur on or off. Only allowed while Liquid Glass
  /// (frosted chrome) is enabled, since the blur has nothing to blur otherwise.
  Future<void> setBlur(bool enabled) async {
    if (!_liquid) return;
    if (enabled == _blur) return;
    _blur = enabled;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_blurKey, enabled);
  }
}

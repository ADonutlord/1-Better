import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Thin platform wrapper around Android's screen-pinning (the app-level
/// "phone lockdown" mechanism).
///
/// When active, the device is locked into this app: the home button, recents
/// and notification shade are blocked, so the student cannot wander into
/// other apps. Incoming calls still ring through and can be answered.
///
/// This is only supported on Android; on every other platform the calls are
/// no-ops returning false so the UI degrades gracefully.
class LockdownService {
  LockdownService._();

  static final LockdownService instance = LockdownService._();

  static const MethodChannel _channel =
      MethodChannel('one_percent_better/lock');

  bool get _isAndroid => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Locks the device into this app (screen pinning). Returns false when
  /// unsupported or the OS declines (e.g. pinning not enabled in settings).
  Future<bool> lock() async {
    if (!_isAndroid) return false;
    try {
      final ok = await _channel.invokeMethod<bool>('startLock');
      return ok == true;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  /// Releases the device from screen pinning.
  Future<bool> unlock() async {
    if (!_isAndroid) return false;
    try {
      final ok = await _channel.invokeMethod<bool>('stopLock');
      return ok == true;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  /// Turns the screen on / shows the timer even when the screen was locked.
  Future<void> wakeScreen() async {
    if (!_isAndroid) return;
    try {
      await _channel.invokeMethod<void>('dismissKeyguard');
    } on PlatformException {
      // Non-fatal — ignore.
    } on MissingPluginException {
      // ignore
    }
  }

  /// Unpins and opens the system dialer so the user can make a call while the
  /// study timer is active.
  Future<void> openDialer() async {
    if (!_isAndroid) return;
    try {
      await _channel.invokeMethod<void>('openDialer');
    } on PlatformException {
      // ignore
    } on MissingPluginException {
      // ignore
    }
  }
}

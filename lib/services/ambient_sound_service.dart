import 'dart:async';
import 'dart:io' show Platform;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/backdrop_controller.dart';

/// Loops a gentle soundscape behind the home screen when the user opts in
/// from the theme switch.
///
/// Preference only (on or off): which track plays is decided by the current
/// [BackdropScene], so the sound always matches whatever scenery is shown.
class AmbientSoundService extends ChangeNotifier {
  AmbientSoundService._();

  static final AmbientSoundService instance = AmbientSoundService._();

  static const String _enabledKey = 'ambient_sounds';

  /// Volume for a scene's track. Rain stays soft — it is the comfort sound —
  /// while every other scene plays noticeably louder.
  static double volumeFor(BackdropScene scene) => switch (scene) {
    BackdropScene.rain => 0.5,
    _ => 0.9,
  };

  /// How close to the end of a track the Linux loop wraps back to the start
  /// on its own. Linux only notices the end after the file has run out, and
  /// the restart that follows leaves an audible hole; seeking while still
  /// playing is nearly seamless. The lookahead just has to outlast the
  /// ~200 ms position ticks and the seek itself.
  static const Duration loopLookahead = Duration(milliseconds: 500);

  /// Whether [position] is close enough to [duration] to wrap early. A
  /// missing (or zero) duration falls back to the native end-of-track loop.
  static bool loopWrapDue(Duration position, Duration? duration) =>
      duration != null &&
      duration > Duration.zero &&
      position > Duration.zero &&
      duration - position <= loopLookahead;

  /// Track for each scene, bundled in `assets/`. The player resolves these
  /// against the `assets/` prefix itself, so the names stay bare.
  static String assetFor(BackdropScene scene) => switch (scene) {
    BackdropScene.rain => 'dragon-studio-gentle-midday-rain-499668.mp3',
    BackdropScene.night => 'freesound_community-night-ambience-59071.mp3',
    BackdropScene.blossom => 'u_vr5icvkppa-nature-ambience-323729.mp3',
    BackdropScene.snow =>
      'joelfazhari-cold-snowfall-ambience-5-minutes-sound-effect-164512.mp3',
    BackdropScene.meadow => 'freesound_community-backyard-amb-day-25771.mp3',
  };

  bool _enabled = false;
  bool get enabled => _enabled;

  AudioPlayer? _player;
  BackdropScene? _playing;

  String? _lastError;

  /// The most recent playback failure, for the caller to surface. `null`
  /// means the last request succeeded.
  String? get lastError => _lastError;

  /// Swapping the real player for a failing stub in tests.
  @visibleForTesting
  static AudioPlayer Function() playerFactory = AudioPlayer.new;

  // Linux loop smoothing: watch how far through the track we are and wrap
  // just before the end, instead of letting the file run out.
  StreamSubscription<Duration>? _positionWatch;
  StreamSubscription<Duration>? _durationWatch;
  Duration? _duration;
  bool _wrapping = false;

  /// Playback jobs run strictly one at a time. Interleaving two of them — a
  /// theme switch racing the launch resume, say — let a track's start and the
  /// next track's stop pass each other, which is how soundscapes overlapped.
  Future<void> _queue = Future<void>.value();

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _enabled = prefs.getBool(_enabledKey) ?? false;
    notifyListeners();
  }

  Future<void> setEnabled(bool value) async {
    if (value == _enabled) return;
    _enabled = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, value);
  }

  /// Starts or stops playback so it matches [enabled] for [scene]. Failures
  /// never break the UI — they land in [lastError] for the caller to show.
  Future<void> sync(BackdropScene scene) => _enqueue(() => _syncNow(scene));

  /// Queued counterpart of [_stopNow], for callers outside this service.
  Future<void> stop() => _enqueue(_stopNow);

  Future<void> _enqueue(Future<void> Function() job) {
    _queue = _queue.then((_) => job()).catchError((Object e, StackTrace s) {
      debugPrint('Ambient sound job failed: $e');
    });
    return _queue;
  }

  Future<void> _syncNow(BackdropScene scene) async {
    if (!_enabled) {
      await _stopNow();
      return;
    }
    await _playNow(scene);
  }

  Future<void> _playNow(BackdropScene scene) async {
    try {
      final player = _player ??= AmbientSoundService.playerFactory();
      await player.setReleaseMode(ReleaseMode.loop);
      await player.setVolume(volumeFor(scene));
      if (_playing != scene) {
        // Retire the old track completely before the new one starts, so two
        // soundscapes never play at once.
        _stopLoopWatch();
        if (_playing != null) {
          await player.stop();
        }
        await player.play(AssetSource(assetFor(scene)));
        _playing = scene;
        _startLoopWatch(player);
      } else if (player.state != PlayerState.playing) {
        await player.resume();
        _startLoopWatch(player);
      }
      _lastError = null;
      notifyListeners();
    } catch (e) {
      debugPrint('Ambient sound unavailable: $e');
      _lastError = e.toString();
      _playing = null;
      _stopLoopWatch();
      notifyListeners();
    }
  }

  Future<void> _stopNow() async {
    _stopLoopWatch();
    final player = _player;
    if (player == null) return;
    try {
      await player.stop();
    } catch (e) {
      // A failed teardown still leaves the service usable.
      debugPrint('Ambient sound stop failed: $e');
    }
    _playing = null;
  }

  /// Listens for the end of the current track and wraps a beat early.
  /// Android's native loop is already gapless, so only Linux pays the price
  /// of the watch — its end-of-track restart is the audible one.
  void _startLoopWatch(AudioPlayer player) {
    _stopLoopWatch();
    if (!Platform.isLinux) return;
    _durationWatch = player.onDurationChanged.listen((value) {
      if (value > Duration.zero) _duration = value;
    });
    _positionWatch = player.onPositionChanged.listen((position) {
      if (_wrapping || !loopWrapDue(position, _duration)) return;
      _wrapping = true;
      unawaited(
        player
            .seek(Duration.zero)
            .catchError((Object e) {
              // Wrapping late still loops via the native restart; it is only
              // less soft, so this is worth a log, not an error.
              debugPrint('Ambient loop wrap failed: $e');
            })
            .whenComplete(() => _wrapping = false),
      );
    });
    unawaited(_readDuration(player));
  }

  Future<void> _readDuration(AudioPlayer player) async {
    try {
      final value = await player.getDuration();
      if (value != null && value > Duration.zero) _duration = value;
    } catch (e) {
      debugPrint('Ambient duration unavailable: $e');
    }
  }

  void _stopLoopWatch() {
    _positionWatch?.cancel();
    _durationWatch?.cancel();
    _positionWatch = null;
    _durationWatch = null;
    _duration = null;
    _wrapping = false;
  }
}

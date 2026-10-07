import 'package:flutter_test/flutter_test.dart';
import 'package:one_percent_better/core/backdrop_controller.dart';
import 'package:one_percent_better/services/ambient_sound_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('BackdropMilestones', () {
    test('new accounts have no decorations yet', () {
      expect(BackdropMilestones.unlocked(1), isEmpty);
    });

    test('decorations unlock in order as the level rises', () {
      expect(BackdropMilestones.unlocked(3), ['grass']);
      expect(BackdropMilestones.unlocked(8), ['grass', 'birds']);
      expect(BackdropMilestones.unlocked(15), ['grass', 'birds', 'fireflies']);
      expect(
        BackdropMilestones.unlocked(40),
        containsAll(<String>['lanterns', 'shootingStar']),
      );
    });

    test('has() reports a single decoration at a level', () {
      expect(BackdropMilestones.has(2, 'grass'), isFalse);
      expect(BackdropMilestones.has(3, 'grass'), isTrue);
      expect(BackdropMilestones.has(14, 'fireflies'), isFalse);
      expect(BackdropMilestones.has(15, 'fireflies'), isTrue);
    });

    test('next() points at the next unlock', () {
      expect(BackdropMilestones.next(1)!.id, 'grass');
      expect(BackdropMilestones.next(3)!.id, 'birds');
      expect(BackdropMilestones.next(39)!.id, 'shootingStar');
      expect(BackdropMilestones.next(40), isNull);
      expect(BackdropMilestones.next(200), isNull);
    });

    test('level 1 never unlocks everything', () {
      expect(
        BackdropMilestones.unlocked(1).length,
        lessThan(BackdropMilestones.unlocks.length),
      );
    });
  });

  group('BackdropController', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('sceneFromKey resolves persisted names and falls back', () {
      expect(BackdropController.sceneFromKey('night'), BackdropScene.night);
      expect(BackdropController.sceneFromKey('snow'), BackdropScene.snow);
      expect(
        BackdropController.sceneFromKey('not-a-scene'),
        BackdropScene.meadow,
      );
      expect(BackdropController.sceneFromKey(null), BackdropScene.meadow);
    });

    test('live wallpaper defaults to enabled with the meadow scene', () async {
      await BackdropController.instance.load();
      expect(BackdropController.instance.enabled, isTrue);
      expect(BackdropController.instance.scene, BackdropScene.meadow);
    });

    test('toggling off persists the choice', () async {
      await BackdropController.instance.load();
      await BackdropController.instance.setEnabled(false);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('live_wallpaper'), isFalse);

      // Survives a restart.
      await BackdropController.instance.load();
      expect(BackdropController.instance.enabled, isFalse);
    });

    test('the scene can be changed on any platform', () async {
      SharedPreferences.setMockInitialValues({'backdrop_scene': 'meadow'});
      await BackdropController.instance.load();

      final changed = await BackdropController.instance.setScene(
        BackdropScene.night,
      );
      expect(changed, isTrue, reason: 'no platform gate on scenery');
      expect(BackdropController.instance.scene, BackdropScene.night);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('backdrop_scene'), 'night');
    });

    test('a persisted scene is restored on load', () async {
      SharedPreferences.setMockInitialValues({'backdrop_scene': 'rain'});
      await BackdropController.instance.load();
      expect(BackdropController.instance.scene, BackdropScene.rain);
    });
  });

  group('rain unlock rule', () {
    test('low moods unlock rain', () {
      for (final mood in ['sad', 'depressed', 'gloomy', 'bored', 'tired']) {
        expect(BackdropController.rainAllowed(mood), isTrue, reason: mood);
      }
    });

    test('other moods keep rain locked', () {
      for (final mood in [
        'happy',
        'excited',
        'calm',
        'angry',
        'anxious',
        'curious',
        null,
      ]) {
        expect(BackdropController.rainAllowed(mood), isFalse, reason: '$mood');
      }
    });

    test('only rain is mood-gated', () {
      for (final scene in BackdropScene.values) {
        expect(
          BackdropController.sceneAllowed(scene, 'happy'),
          scene != BackdropScene.rain,
          reason: scene.name,
        );
        expect(
          BackdropController.sceneAllowed(scene, 'sad'),
          isTrue,
          reason: scene.name,
        );
      }
    });
  });

  group('AmbientSoundService', () {
    test('every scene maps to its own bundled soundscape', () {
      expect(
        AmbientSoundService.assetFor(BackdropScene.rain),
        contains('rain'),
      );
      expect(
        AmbientSoundService.assetFor(BackdropScene.night),
        contains('night-ambience'),
      );
      expect(
        AmbientSoundService.assetFor(BackdropScene.blossom),
        contains('nature-ambience'),
      );
      expect(
        AmbientSoundService.assetFor(BackdropScene.snow),
        contains('cold-snowfall'),
      );
      expect(
        AmbientSoundService.assetFor(BackdropScene.meadow),
        contains('backyard-amb-day'),
      );
    });

    test(
      'a playback failure surfaces as lastError instead of crashing',
      () async {
        SharedPreferences.setMockInitialValues({});
        await AmbientSoundService.instance.load();
        await AmbientSoundService.instance.setEnabled(true);

        // Simulate an audio stack that fails; the error must be reported
        // through lastError, not thrown or silently dropped.
        final previousFactory = AmbientSoundService.playerFactory;
        AmbientSoundService.playerFactory = () =>
            throw StateError('no audio device');
        addTearDown(() => AmbientSoundService.playerFactory = previousFactory);

        await AmbientSoundService.instance.sync(BackdropScene.night);
        expect(
          AmbientSoundService.instance.lastError,
          contains('no audio device'),
        );

        await AmbientSoundService.instance.setEnabled(false);
      },
    );

    test('ambient sounds default to off', () async {
      SharedPreferences.setMockInitialValues({});
      await AmbientSoundService.instance.load();
      expect(AmbientSoundService.instance.enabled, isFalse);
    });

    test('the answer from the popup persists across restarts', () async {
      SharedPreferences.setMockInitialValues({});
      await AmbientSoundService.instance.load();
      await AmbientSoundService.instance.setEnabled(true);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('ambient_sounds'), isTrue);

      // Survives a restart.
      await AmbientSoundService.instance.load();
      expect(AmbientSoundService.instance.enabled, isTrue);

      await AmbientSoundService.instance.setEnabled(false);
      await AmbientSoundService.instance.load();
      expect(AmbientSoundService.instance.enabled, isFalse);
    });

    test('rain stays soft while every other scene plays louder', () {
      final rain = AmbientSoundService.volumeFor(BackdropScene.rain);
      expect(rain, 0.5);
      for (final scene in BackdropScene.values) {
        if (scene == BackdropScene.rain) continue;
        expect(
          AmbientSoundService.volumeFor(scene),
          greaterThan(rain),
          reason: '${scene.name} should be louder than rain',
        );
      }
    });

    test('the loop wraps early only when the end is genuinely close', () {
      const track = Duration(minutes: 8);
      const justBefore = Duration(milliseconds: 300);
      const tooEarly = Duration(milliseconds: 600);

      expect(
        AmbientSoundService.loopWrapDue(track - justBefore, track),
        isTrue,
        reason: 'wraps in the final moments',
      );
      expect(AmbientSoundService.loopWrapDue(track - tooEarly, track), isFalse);
      expect(
        AmbientSoundService.loopWrapDue(track, track),
        isTrue,
        reason: 'a tick landing on the end still wraps',
      );
      expect(
        AmbientSoundService.loopWrapDue(const Duration(seconds: 5), null),
        isFalse,
        reason: 'unknown duration falls back to the native loop',
      );
      expect(
        AmbientSoundService.loopWrapDue(
          const Duration(seconds: 5),
          Duration.zero,
        ),
        isFalse,
      );
      expect(
        AmbientSoundService.loopWrapDue(Duration.zero, track),
        isFalse,
        reason: 'never wraps before playback starts',
      );
    });

    test(
      'playback jobs queue instead of interleaving, and survive a failure',
      () async {
        SharedPreferences.setMockInitialValues({});
        await AmbientSoundService.instance.load();
        await AmbientSoundService.instance.setEnabled(true);

        final previousFactory = AmbientSoundService.playerFactory;
        var calls = 0;
        AmbientSoundService.playerFactory = () {
          calls += 1;
          throw StateError('boom $calls');
        };
        addTearDown(() => AmbientSoundService.playerFactory = previousFactory);

        // Two overlapping requests: the second must wait for the first, and a
        // failing first request must not wedge the queue.
        await Future.wait([
          AmbientSoundService.instance.sync(BackdropScene.night),
          AmbientSoundService.instance.sync(BackdropScene.snow),
        ]);

        expect(calls, 2, reason: 'both jobs ran, one after the other');
        expect(AmbientSoundService.instance.lastError, contains('boom'));

        await AmbientSoundService.instance.setEnabled(false);
      },
    );
  });
}

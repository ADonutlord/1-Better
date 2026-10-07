import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/backdrop_controller.dart';
import 'tree.dart';

/// Colours used by one scenery preset.
typedef SceneColors = ({
  Color skyTop,
  Color skyBottom,
  Color ground,
  Color orb,
});

/// Sky/ground palettes per [BackdropScene], plus the tone used to keep the nav
/// chrome legible over any of them.
class ScenePalette {
  ScenePalette._();

  static SceneColors paletteFor(BackdropScene scene) => switch (scene) {
    BackdropScene.meadow => (
      skyTop: const Color(0xFF6FB7E8),
      skyBottom: const Color(0xFFE6F5E1),
      ground: const Color(0xFF7CB342),
      orb: const Color(0xFFFFF3C4),
    ),
    BackdropScene.blossom => (
      skyTop: const Color(0xFFF7B7CE),
      skyBottom: const Color(0xFFFDEBEF),
      ground: const Color(0xFF9CCC65),
      orb: const Color(0xFFFFE8B0),
    ),
    BackdropScene.rain => (
      skyTop: const Color(0xFF7C8B9A),
      skyBottom: const Color(0xFFC2CCD4),
      ground: const Color(0xFF5D7F68),
      orb: const Color(0xFFD8E2E8),
    ),
    BackdropScene.snow => (
      skyTop: const Color(0xFF93A7CC),
      skyBottom: const Color(0xFFEDF2F9),
      ground: const Color(0xFFDDE5EF),
      orb: const Color(0xFFFFF6DC),
    ),
    BackdropScene.night => (
      skyTop: const Color(0xFF0A0F24),
      skyBottom: const Color(0xFF1C2542),
      ground: const Color(0xFF1D3325),
      orb: const Color(0xFFF3F0D0),
    ),
  };

  /// Dominant tone behind the nav chrome, so its text stays readable on every
  /// scene at any growth.
  static Color chromeTone(
    BackdropScene scene, {
    required bool isDark,
    required double growth,
    required Color surface,
  }) {
    final colors = paletteFor(scene);
    final ground = isDark
        ? Color.lerp(colors.ground, Colors.black, 0.3)!
        : colors.ground;
    final foliage = isDark ? const Color(0xFF4CAF50) : const Color(0xFF66BB6A);
    final mixed = Color.lerp(ground, foliage, growth.clamp(0.0, 1.0))!;
    return Color.lerp(surface, mixed, 0.8)!;
  }
}

/// The live wallpaper behind the app: a themed sky, the growth tree, drifting
/// weather and level-driven decorations that appear as the user levels up.
///
/// Set [enabled] to false to freeze the motion (a still tree, no particles).
/// [levelUps] increments on every level up and triggers a celebration burst.
class LiveBackdrop extends StatefulWidget {
  const LiveBackdrop({
    super.key,
    required this.growth,
    required this.level,
    required this.levelUps,
    required this.enabled,
    required this.scene,
  });

  final double growth;
  final int level;

  /// Bumped on every level up; drives the celebration burst.
  final int levelUps;
  final bool enabled;
  final BackdropScene scene;

  @override
  State<LiveBackdrop> createState() => _LiveBackdropState();
}

class _LiveBackdropState extends State<LiveBackdrop>
    with TickerProviderStateMixin {
  late final AnimationController _clock;
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _clock = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
      value: widget.enabled ? 0 : _stillPose,
    );
    if (widget.enabled) _clock.repeat();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
      value: 0,
    );
  }

  /// A calm, mid-drift pose used while the wallpaper is switched off.
  static const _stillPose = 0.0;

  @override
  void didUpdateWidget(covariant LiveBackdrop old) {
    super.didUpdateWidget(old);
    if (old.enabled != widget.enabled) {
      if (widget.enabled) {
        _clock.repeat();
      } else {
        _clock
          ..stop()
          ..value = _stillPose;
        _pulse
          ..stop()
          ..value = 0;
      }
    }
    if (old.levelUps != widget.levelUps && widget.enabled) {
      _pulse.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _clock.dispose();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AnimatedBuilder(
      animation: Listenable.merge([_clock, _pulse]),
      builder: (context, _) {
        // Frozen at a still frame while the live wallpaper is off.
        final t = widget.enabled ? _clock.value : _stillPose;
        return Stack(
          fit: StackFit.expand,
          children: [
            CustomPaint(
              painter: _SkyPainter(
                scene: widget.scene,
                t: t,
                level: widget.level,
                isDark: isDark,
              ),
            ),
            Transform.translate(
              offset: const Offset(24, 0),
              child: TreeGrowthIndicator(
                growth: widget.growth,
                background: true,
                backgroundAnchor: 0.1,
                animate: widget.enabled,
              ),
            ),
            if (widget.enabled)
              CustomPaint(
                painter: _ParticlePainter(
                  scene: widget.scene,
                  t: t,
                  level: widget.level,
                ),
              ),
            if (widget.enabled && _pulse.value > 0)
              CustomPaint(
                painter: _CelebrationPainter(
                  progress: _pulse.value,
                  scene: widget.scene,
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Golden-ratio scatter so particles sit in stable, well-spread positions
/// without re-seeding a [math.Random] on every frame.
const _scatter = 0.61803398875;

/// Sky, ground, celestial body, clouds and the level-locked scenery
/// decorations.
class _SkyPainter extends CustomPainter {
  _SkyPainter({
    required this.scene,
    required this.t,
    required this.level,
    required this.isDark,
  });

  final BackdropScene scene;
  final double t;
  final int level;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final colors = ScenePalette.paletteFor(scene);
    final night = scene == BackdropScene.night;
    // Matches the tree's own planting line so the mound sits on the ground.
    final groundY = h * 0.92;

    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [colors.skyTop, colors.skyBottom],
        ).createShader(Rect.fromLTWH(0, 0, w, groundY)),
    );

    if (night) {
      _stars(canvas, w, groundY);
      _shootingStar(canvas, w, groundY);
    } else {
      _orb(canvas, w, groundY, colors.orb, colors.skyTop);
      _clouds(canvas, w, groundY, night: false);
    }

    _birds(canvas, w, groundY);
    _ground(canvas, w, h, groundY, colors.ground);

    // Keep bright scenes from glaring in the dark theme.
    if (isDark) {
      canvas.drawRect(
        rect,
        Paint()..color = Colors.black.withValues(alpha: 0.26),
      );
    }
  }

  void _stars(Canvas canvas, double w, double groundY) {
    for (var i = 0; i < 60; i++) {
      final x = ((i * _scatter) % 1.0) * w;
      final y = ((i * 0.7548776662) % 1.0) * groundY * 0.85;
      final twinkle =
          0.35 +
          0.65 *
              ((math.sin(t * 2 * math.pi * (1 + (i % 3) * 0.5) + i) + 1) / 2);
      canvas.drawCircle(
        Offset(x, y),
        1.1 + (i % 3) * 0.6,
        Paint()..color = Colors.white.withValues(alpha: twinkle * 0.9),
      );
    }
  }

  /// A streak that sweeps across the sky once in a while (level 40+).
  void _shootingStar(Canvas canvas, double w, double groundY) {
    if (!BackdropMilestones.has(level, 'shootingStar')) return;
    final cycle = t * 0.6 % 1.0;
    if (cycle > 0.22) return;
    final fade = 1 - (cycle / 0.22);
    final x = w * (0.15 + 0.6 * (cycle / 0.22));
    final y = groundY * (0.12 + 0.28 * (cycle / 0.22));
    canvas.drawLine(
      Offset(x, y),
      Offset(x + w * 0.09, y + groundY * 0.05),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.85 * fade)
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round,
    );
  }

  void _orb(Canvas canvas, double w, double groundY, Color orb, Color skyTop) {
    final center = Offset(w * 0.74, groundY * 0.2);
    final r = w * 0.09;
    for (final (scale, alpha) in const [(2.6, 0.10), (1.8, 0.16), (1.0, 1.0)]) {
      canvas.drawCircle(
        center,
        r * scale,
        Paint()
          ..color = orb.withValues(
            alpha: alpha * (scene == BackdropScene.rain ? 0.5 : 1.0),
          ),
      );
    }
    // Craters read as a moon rather than a flat disc on the brighter scenes.
    if (scene == BackdropScene.snow || scene == BackdropScene.rain) {
      final shade = Paint()..color = Color.lerp(orb, skyTop, 0.35)!;
      canvas.drawCircle(center + Offset(r * 0.3, -r * 0.25), r * 0.22, shade);
      canvas.drawCircle(center + Offset(-r * 0.25, r * 0.3), r * 0.16, shade);
    }
  }

  void _clouds(Canvas canvas, double w, double groundY, {required bool night}) {
    final color = night
        ? const Color(0x33FFFFFF)
        : Colors.white.withValues(alpha: 0.7);
    for (var i = 0; i < 3; i++) {
      final drift = (t * (0.02 + i * 0.012) + i * 0.41) % 1.3;
      final x = drift * w - w * 0.15;
      final y = groundY * (0.12 + i * 0.11);
      final s = w * (0.26 - i * 0.04);
      final paint = Paint()..color = color;
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(x - s * 0.5, y),
          width: s * 1.2,
          height: s * 0.5,
        ),
        paint,
      );
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(x, y),
          width: s * 0.85,
          height: s * 0.66,
        ),
        paint,
      );
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(x + s * 0.6, y + s * 0.05),
          width: s * 1.0,
          height: s * 0.46,
        ),
        paint,
      );
    }
  }

  /// Birds join the sky from level 8.
  void _birds(Canvas canvas, double w, double groundY) {
    if (!BackdropMilestones.has(level, 'birds')) return;
    final count = level >= 25 ? 3 : 2;
    for (var i = 0; i < count; i++) {
      final path = (t * 0.12 + i * 0.37) % 1.2;
      final x = path * w - w * 0.1;
      final y = groundY * (0.2 + i * 0.08) + math.sin(t * 2 * math.pi + i) * 6;
      final s = w * 0.035;
      final flap = (math.sin(t * 2 * math.pi * 6 + i) + 1) / 2;
      final paint = Paint()
        ..color = const Color(0xFF37474F).withValues(alpha: 0.65)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..strokeCap = StrokeCap.round;
      canvas.drawPath(
        Path()
          ..moveTo(x - s, y)
          ..quadraticBezierTo(x - s * 0.5, y - s * (0.4 + flap * 0.6), x, y)
          ..quadraticBezierTo(
            x + s * 0.5,
            y - s * (0.4 + flap * 0.6),
            x + s,
            y,
          ),
        paint,
      );
    }
  }

  void _ground(
    Canvas canvas,
    double w,
    double h,
    double groundY,
    Color ground,
  ) {
    canvas.drawRect(
      Rect.fromLTWH(0, groundY, w, h - groundY),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [ground, Color.lerp(ground, const Color(0xFF26331F), 0.45)!],
        ).createShader(Rect.fromLTWH(0, groundY, w, h - groundY)),
    );
    // Grass tufts appear from level 3.
    if (!BackdropMilestones.has(level, 'grass')) return;
    final paint = Paint()
      ..color = Color.lerp(ground, Colors.white, 0.35)!
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 14; i++) {
      final x = ((i * _scatter) % 1.0) * w;
      final s = 7 + (i % 4) * 2.5;
      final sway = math.sin(t * 2 * math.pi + i) * 1.5;
      canvas.drawPath(
        Path()
          ..moveTo(x - s * 0.4, groundY + 2)
          ..quadraticBezierTo(
            x - s * 0.3 + sway,
            groundY - s * 0.6,
            x,
            groundY - s,
          ),
        paint,
      );
      canvas.drawPath(
        Path()
          ..moveTo(x + s * 0.4, groundY + 2)
          ..quadraticBezierTo(
            x + s * 0.3 + sway,
            groundY - s * 0.5,
            x + s * 0.2,
            groundY - s * 0.7,
          ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SkyPainter old) =>
      old.scene != scene || old.level != level || old.isDark != isDark;
}

/// Drifting weather: pollen, petals, rain, snow or fireflies.
class _ParticlePainter extends CustomPainter {
  _ParticlePainter({required this.scene, required this.t, required this.level});

  final BackdropScene scene;
  final double t;
  final int level;

  /// More of everything as the user levels up, capped so it stays cheap.
  int get _count {
    final base = switch (scene) {
      BackdropScene.rain => 46,
      BackdropScene.snow => 34,
      BackdropScene.blossom => 20,
      BackdropScene.meadow => 14,
      BackdropScene.night => 12,
    };
    return base + level.clamp(0, 30);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    for (var i = 0; i < _count; i++) {
      final x0 = ((i * _scatter) % 1.0) * w;
      final speed = 0.7 + (i % 7) * 0.11;
      final phase = (t * speed * 0.45 + i * 0.137) % 1.0;
      final sway = math.sin(t * 2 * math.pi + i) * w * 0.03;
      switch (scene) {
        case BackdropScene.rain:
          final x = x0 + sway * 0.4;
          final y = phase * h;
          canvas.drawLine(
            Offset(x, y),
            Offset(x - 4, y + 16 + (i % 5) * 3),
            Paint()
              ..color = const Color(0xCCFFFFFF)
              ..strokeWidth = 1.6
              ..strokeCap = StrokeCap.round,
          );
        case BackdropScene.snow:
          canvas.drawCircle(
            Offset(x0 + sway, phase * h),
            1.4 + (i % 4) * 0.7,
            Paint()..color = Colors.white.withValues(alpha: 0.85),
          );
        case BackdropScene.blossom:
          final x = x0 + sway * 1.6;
          final y = phase * h;
          canvas.save();
          canvas.translate(x, y);
          canvas.rotate((t * 6 + i) * 0.9);
          canvas.drawOval(
            Rect.fromCenter(
              center: Offset.zero,
              width: 6 + (i % 3),
              height: 3.6 + (i % 3) * 0.8,
            ),
            Paint()..color = const Color(0xFFF48FB1).withValues(alpha: 0.9),
          );
          canvas.restore();
        case BackdropScene.meadow:
          final glow =
              (math.sin(t * 2 * math.pi * (0.6 + i % 3 * 0.4) + i) + 1) / 2;
          canvas.drawCircle(
            Offset(x0 + sway, h - phase * h),
            1.6 + (i % 3) * 0.6,
            Paint()
              ..color = const Color(
                0xFFFFF8E1,
              ).withValues(alpha: 0.35 + glow * 0.4),
          );
        case BackdropScene.night:
          final glow =
              (math.sin(t * 2 * math.pi * (0.5 + i % 4 * 0.3) + i) + 1) / 2;
          final color = Color.lerp(
            const Color(0xFFFFF176),
            const Color(0xFFFFB300),
            glow,
          )!;
          canvas.drawCircle(
            Offset(x0 + sway * 1.4, h - phase * h * 0.8),
            2.2 + glow * 1.4,
            Paint()..color = color.withValues(alpha: 0.35 + glow * 0.5),
          );
      }
    }

    // Fireflies only light up once the tree has earned them (level 15+), and
    // they glow warmly whatever the scene.
    if (BackdropMilestones.has(level, 'fireflies') &&
        scene != BackdropScene.night) {
      for (var i = 0; i < 10; i++) {
        final glow =
            (math.sin(t * 2 * math.pi * (0.4 + i % 3 * 0.25) + i * 1.7) + 1) /
            2;
        final x = ((i * 0.38196601125) % 1.0) * w;
        final y = h * (0.55 + ((i * _scatter) % 1.0) * 0.3);
        canvas.drawCircle(
          Offset(x, y),
          2.4 + glow * 1.6,
          Paint()
            ..color = const Color(0xFFFFF176).withValues(alpha: glow * 0.75),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter old) =>
      old.scene != scene || old.level != level;
}

/// A ring of sparkles when the user levels up.
class _CelebrationPainter extends CustomPainter {
  _CelebrationPainter({required this.progress, required this.scene});

  final double progress;
  final BackdropScene scene;

  static const _gold = Color(0xFFFFD54F);

  @override
  void paint(Canvas canvas, Size size) {
    final p = progress.clamp(0.0, 1.0);
    final fade = 1 - p;
    final cx = size.width * 0.52;
    final cy = size.height * 0.55;
    final base = size.shortestSide;

    canvas.drawCircle(
      Offset(cx, cy),
      base * 0.5,
      Paint()..color = _gold.withValues(alpha: 0.10 * fade),
    );
    canvas.drawCircle(
      Offset(cx, cy),
      base * (0.12 + 0.6 * p),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1 + 3 * fade
        ..color = _gold.withValues(alpha: 0.65 * fade),
    );
    for (var i = 0; i < 18; i++) {
      final angle = i * 2.399963;
      final d = base * (0.15 + 0.62 * p) * (0.4 + ((i * _scatter) % 1.0) * 0.8);
      final pos = Offset(
        cx + math.cos(angle) * d,
        cy + math.sin(angle) * d * 0.8,
      );
      canvas.drawCircle(
        pos,
        1 + 3.5 * fade,
        Paint()..color = Colors.white.withValues(alpha: 0.85 * fade),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CelebrationPainter old) =>
      old.progress != progress || old.scene != scene;
}

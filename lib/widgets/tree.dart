import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A tree that sprouts as a seedling and grows, sways and blossoms as
/// [growth] goes 0 -> 1 (fully grown, fully blossomed at level 200).
///
/// Set [background] to paint a large tree for use behind other content.
/// [backgroundAnchor] raises it from the bottom edge (0.0 = planted at the
/// bottom, 1.0 = canopy near the top; ~0.5 centers it).
class TreeGrowthIndicator extends StatefulWidget {
  const TreeGrowthIndicator({
    super.key,
    required this.growth,
    this.size = 120,
    this.background = false,
    this.backgroundAnchor = 0.0,
  });

  /// 0.0 (seedling) to 1.0 (fully grown).
  final double growth;
  final double size;
  final bool background;

  /// How far the background tree is raised from the bottom edge.
  final double backgroundAnchor;

  @override
  State<TreeGrowthIndicator> createState() => _TreeGrowthIndicatorState();
}

class _TreeGrowthIndicatorState extends State<TreeGrowthIndicator>
    with TickerProviderStateMixin {
  late final AnimationController _growth;
  late final AnimationController _ambient;

  @override
  void initState() {
    super.initState();
    _growth = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
      value: 0,
    );
    _ambient = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3600),
    )..repeat();
    _growth.animateTo(
      widget.growth.clamp(0.0, 1.0),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void didUpdateWidget(covariant TreeGrowthIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.growth != widget.growth) {
      _growth.animateTo(
        widget.growth.clamp(0.0, 1.0),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  void dispose() {
    _growth.dispose();
    _ambient.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AnimatedBuilder(
      animation: Listenable.merge([_growth, _ambient]),
      builder: (context, _) => CustomPaint(
        painter: _TreePainter(
          growth: _growth.value,
          sway: _ambient.value,
          colorScheme: theme.colorScheme,
          isDark: theme.brightness == Brightness.dark,
          background: widget.background,
          backgroundAnchor: widget.backgroundAnchor,
        ),
      ),
    );
  }
}

class _TreePainter extends CustomPainter {
  _TreePainter({
    required this.growth,
    required this.sway,
    required this.colorScheme,
    required this.isDark,
    required this.background,
    required this.backgroundAnchor,
  });

  final double growth;
  final double sway;
  final ColorScheme colorScheme;
  final bool isDark;
  final bool background;
  final double backgroundAnchor;

  static const _greens = [
    Color(0xFF2E7D32),
    Color(0xFF43A047),
    Color(0xFF66BB6A),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final g = growth.clamp(0.0, 1.0);
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    final anchor = backgroundAnchor.clamp(0.0, 1.0);
    final groundY = background ? h * (0.98 - 0.56 * anchor) : h * 0.94;
    final unit = background ? math.min(h * 0.72, w * 0.52) : w;

    // Ground mound.
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, groundY + unit * 0.05),
        width: unit * 0.9,
        height: unit * 0.16,
      ),
      Paint()..color = colorScheme.surfaceContainerHighest,
    );

    final greens = isDark
        ? const [Color(0xFF388E3C), Color(0xFF4CAF50), Color(0xFF81C784)]
        : _greens;
    final trunkColor = isDark
        ? const Color(0xFFA1887F)
        : const Color(0xFF795548);
    final trunkW = unit * (0.028 + 0.048 * g);
    final trunkH = unit * (0.03 + 0.40 * g);
    final trunkTop = groundY - trunkH;

    final r = unit * (0.04 + 0.30 * g);
    if (r <= 0.5) return;

    // Canopy drifts gently with the wind once the tree is big enough.
    final swayDx =
        math.sin(sway * 2 * math.pi) * r * 0.05 * (0.3 + g).clamp(0.0, 1.0);
    final center = Offset(cx + swayDx, trunkTop - r * 0.55);

    // Trunk, leaning into the sway.
    canvas.drawLine(
      Offset(cx, groundY),
      Offset(cx + swayDx * 0.3, trunkTop),
      Paint()
        ..color = trunkColor
        ..strokeWidth = trunkW
        ..strokeCap = StrokeCap.round,
    );

    // Branches appear as the tree matures.
    if (g > 0.35) {
      final branch = Paint()
        ..color = trunkColor
        ..strokeWidth = trunkW * 0.5
        ..strokeCap = StrokeCap.round;
      final branchY = trunkTop + trunkH * 0.18;
      canvas.drawLine(
        Offset(cx, branchY),
        Offset(cx - unit * 0.16 * g, branchY - unit * 0.10 * g),
        branch,
      );
      canvas.drawLine(
        Offset(cx, branchY + trunkH * 0.08),
        Offset(cx + unit * 0.16 * g, branchY - unit * 0.08 * g),
        branch,
      );
    }

    // Foliage cluster.
    final blobs = <(Offset, double, Color)>[
      (Offset.zero, r, greens[1]),
      (Offset(-0.72 * r, 0.35 * r), 0.82 * r, greens[0]),
      (Offset(0.72 * r, 0.35 * r), 0.82 * r, greens[2]),
      (Offset(0, -0.62 * r), 0.78 * r, greens[2]),
      (Offset(-0.4 * r, 0.15 * r), 0.6 * r, greens[0]),
      (Offset(0.42 * r, 0.15 * r), 0.6 * r, greens[1]),
    ];
    for (final (offset, radius, color) in blobs) {
      canvas.drawCircle(center + offset, radius, Paint()..color = color);
    }

    // Blossoms bloom at higher levels: cherry-blossom emoji scattered
    // randomly (seeded so they stay put between frames) across the canopy.
    final bloom = ((g - 0.55) / 0.45).clamp(0.0, 1.0);
    if (bloom > 0) {
      final rng = math.Random(42);
      final count = (bloom * 35).round();
      final flowerSize = unit * (0.045 + 0.02 * bloom);
      final flowerPainter = TextPainter(
        text: TextSpan(
          text: '🌸',
          style: TextStyle(fontSize: flowerSize, height: 1.0),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      canvas.saveLayer(
        Offset.zero & size,
        Paint()..color = Colors.white.withValues(alpha: 0.4 + 0.6 * bloom),
      );
      for (var i = 0; i < count; i++) {
        final angle = rng.nextDouble() * 2 * math.pi;
        final dist = r * (0.25 + 0.85 * math.sqrt(rng.nextDouble()));
        final pos =
            center +
            Offset(math.cos(angle) * dist, math.sin(angle) * dist * 0.85);
        flowerPainter.paint(
          canvas,
          pos - Offset(flowerPainter.width / 2, flowerPainter.height / 2),
        );
      }
      canvas.restore();

      // Falling petals drift past a blossoming tree.
      if (bloom > 0.2) {
        final petalCount = (bloom * 5).round();
        final petalPainter = TextPainter(
          text: TextSpan(
            text: '🌸',
            style: TextStyle(fontSize: unit * 0.06, height: 1.0),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        for (var i = 0; i < petalCount; i++) {
          final cycle = (sway + i * 0.37) % 1.0;
          final px =
              center.dx +
              math.sin((sway + i * 1.7) * 2 * math.pi) * r * 0.85 +
              i * unit * 0.08 -
              unit * 0.24;
          final py = center.dy + r * 0.7 + cycle * r * 1.5;
          canvas.save();
          canvas.translate(px, py);
          canvas.rotate((sway * 6 + i) * 0.9);
          petalPainter.paint(
            canvas,
            Offset(-petalPainter.width / 2, -petalPainter.height / 2),
          );
          canvas.restore();
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _TreePainter old) =>
      old.growth != growth ||
      old.sway != sway ||
      old.colorScheme != colorScheme ||
      old.isDark != isDark ||
      old.background != background ||
      old.backgroundAnchor != backgroundAnchor;
}

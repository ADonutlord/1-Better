import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

/// Full-screen launch animation: a progress bar fills 0 → 100% over
/// [duration] while a mini figure goes from sad and stressed to living a
/// happy life, representing your life improving with the app.
class LifeImprovementLoader extends StatefulWidget {
  const LifeImprovementLoader({
    super.key,
    this.duration = const Duration(seconds: 5),
    this.onFinished,
  });

  final Duration duration;

  /// Called once the bar has fully reached 100%.
  final VoidCallback? onFinished;

  @override
  State<LifeImprovementLoader> createState() => _LifeImprovementLoaderState();
}

class _LifeImprovementLoaderState extends State<LifeImprovementLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this)
    ..duration = widget.duration;

  @override
  void initState() {
    super.initState();
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onFinished?.call();
      }
    });
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String get _message {
    final v = _controller.value;
    if (v < 0.2) return 'Your journey starts today...';
    if (v < 0.45) return 'Getting 1% better...';
    if (v < 0.7) return 'Building better habits...';
    if (v < 0.9) return 'Growing every day...';
    return 'Living a happier life!';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final percent = (_controller.value * 100).round();
          return SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ScaleTransition(
                      scale: CurvedAnimation(
                        parent: _controller,
                        curve: const Interval(0, 0.5, curve: Curves.easeOutBack),
                      ),
                      child: Container(
                        width: 116,
                        height: 116,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: scheme.surface,
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.06),
                              blurRadius: 24,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Image.asset(
                          'assets/logo.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: 150,
                      height: 165,
                      child: CustomPaint(
                        painter: _MoodFigurePainter(
                          progress: _controller.value,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: LinearProgressIndicator(
                        value: _controller.value,
                        minHeight: 12,
                        backgroundColor: scheme.surfaceContainerHighest,
                        valueColor: AlwaysStoppedAnimation(
                          _gradientColors(percent),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            child: Text(
                              _message,
                              key: ValueKey(_message),
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ),
                        Text(
                          '$percent%',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: scheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Color _gradientColors(int percent) {
    final scheme = Theme.of(context).colorScheme;
    final t = (percent / 100).clamp(0.0, 1.0);
    return Color.lerp(scheme.primary, scheme.tertiary, t)!;
  }
}

/// Shows [LifeImprovementLoader] until its bar fully reaches 100%, then
/// crossfades into the real app content.
class SplashGate extends StatefulWidget {
  const SplashGate({super.key, required this.child, this.duration = const Duration(seconds: 5)});

  final Widget child;
  final Duration duration;

  @override
  State<SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<SplashGate> {
  bool _done = false;
  Timer? _fallback;

  void _finish() {
    if (mounted) setState(() => _done = true);
  }

  @override
  void initState() {
    super.initState();
    _fallback = Timer(widget.duration + const Duration(seconds: 1), _finish);
  }

  @override
  void dispose() {
    _fallback?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 500),
      child: _done
          ? widget.child
          : LifeImprovementLoader(onFinished: _finish),
    );
  }
}

/// Paints the mini figure; [progress] 0 = stressed, 1 = happy.
class _MoodFigurePainter extends CustomPainter {
  _MoodFigurePainter({required this.progress});

  final double progress;

  static const _skin = Color(0xFFFFD9A2);
  static const _hair = Color(0xFF6B4A2E);
  static const _features = Color(0xFF3B302A);
  static const _pants = Color(0xFF55606E);
  static const _shoe = Color(0xFF3E7C4F);
  static const _blush = Color(0xFFFF9A9A);
  static const _sweat = Color(0xFF8FD3F4);
  static const _sparkle = Color(0xFFFFD54F);
  static const _shirtSad = Color(0xFF9AA3AE);
  static const _shirtHappy = Color(0xFF4A9E6A);

  @override
  void paint(Canvas canvas, Size size) {
    final t = progress.clamp(0.0, 1.0);
    final cx = size.width / 2;
    final groundY = size.height * 0.92;

    final headR = size.width * 0.18;
    final shirt = Color.lerp(_shirtSad, _shirtHappy, t)!;
    final limbW = size.width * 0.055;

    final torsoH = lerpDouble(58.0, 80.0, t)!;
    final hipY = groundY - 26;
    final shoulderY = hipY - torsoH;
    final torsoW = lerpDouble(46.0, 52.0, t)!;

    _paintLegs(canvas, cx, hipY, groundY, limbW);

    _paintTorso(canvas, cx, shoulderY, hipY, torsoW, shirt);

    _paintArms(canvas, size, cx, shoulderY, torsoW, limbW, shirt, t);

    final headCy = shoulderY - headR * 0.9 + (1 - t) * 4;
    _paintHead(canvas, cx, headCy, headR, t);
  }

  void _paintLegs(Canvas canvas, double cx, double hipY, double groundY, double w) {
    final paint = Paint()
      ..color = _pants
      ..strokeWidth = w
      ..strokeCap = StrokeCap.round;
    for (final side in [-1.0, 1.0]) {
      final footX = cx + side * 9;
      canvas.drawLine(Offset(footX, hipY), Offset(footX, groundY), paint);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(footX + side * 2, groundY),
          width: 14,
          height: 7,
        ),
        Paint()..color = _shoe,
      );
    }
  }

  void _paintTorso(Canvas canvas, double cx, double top, double bottom, double w, Color color) {
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTRB(cx - w / 2, top, cx + w / 2, bottom),
      Radius.circular(w / 2),
    );
    canvas.drawRRect(rrect, Paint()..color = color);
  }

  void _paintArms(Canvas canvas, Size size, double cx, double shoulderY, double torsoW, double w, Color color, double t) {
    final armLen = size.width * 0.24;
    for (final side in [-1.0, 1.0]) {
      final shoulder = Offset(cx + side * (torsoW / 2 - 2), shoulderY + 2);
      final sadHand = Offset(
        shoulder.dx + side * armLen * 0.15,
        shoulder.dy + armLen * 0.92,
      );
      final happyHand = Offset(
        shoulder.dx + side * armLen * 0.78,
        shoulder.dy - armLen * 0.5,
      );
      final hand = Offset.lerp(sadHand, happyHand, t)!;

      final armPaint = Paint()
        ..color = color
        ..strokeWidth = w
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(shoulder, hand, armPaint);
      canvas.drawCircle(hand, w * 0.62, Paint()..color = _skin);
    }
  }

  void _paintHead(Canvas canvas, double cx, double cy, double r, double t) {
    canvas.save();
    canvas.translate(cx, cy);
    canvas.rotate(lerpDouble(-0.10, 0.0, t)!);

    canvas.drawCircle(Offset.zero, r, Paint()..color = _skin);

    final hairPath = Path()
      ..moveTo(-r, 0)
      ..arcTo(Rect.fromCircle(center: Offset(0, -r * 0.12), radius: r), math.pi, math.pi, false)
      ..close();
    canvas.drawPath(hairPath, Paint()..color = _hair);

    _paintBrows(canvas, r, t);
    _paintEyes(canvas, r, t);
    _paintMouth(canvas, r, t);
    _paintCheeks(canvas, r, t);

    if (t < 0.55) {
      _paintSweat(canvas, r, 1 - t);
    }
    if (t > 0.35) {
      _paintSparkles(canvas, r, t);
    }

    canvas.restore();
  }

  void _paintBrows(Canvas canvas, double r, double t) {
    final paint = Paint()
      ..color = _features
      ..strokeWidth = r * 0.07
      ..strokeCap = StrokeCap.round;
    final browY = -r * 0.38;
    final browLen = r * 0.30;
    final innerLift = lerpDouble(0.14, -0.02, t)!;
    for (final side in [-1.0, 1.0]) {
      final innerX = side * r * 0.62;
      final outerX = side * r * 0.62 + side * browLen;
      final inner = Offset(innerX, browY - r * innerLift);
      final outer = Offset(outerX, browY + r * 0.02);
      canvas.drawLine(inner, outer, paint);
    }
  }

  void _paintEyes(Canvas canvas, double r, double t) {
    final eyeOff = r * 0.42;
    final eyeY = -r * 0.02;
    final sadAlpha = 1 - t;
    final happyAlpha = t;

    for (final side in [-1.0, 1.0]) {
      final x = side * eyeOff;

      if (sadAlpha > 0) {
        final sadPaint = Paint()
          ..color = _features.withValues(alpha: sadAlpha);
        canvas.drawCircle(Offset(x, eyeY + r * 0.02), r * 0.10, sadPaint);
      }

      if (happyAlpha > 0) {
        final happyPaint = Paint()
          ..color = _features.withValues(alpha: happyAlpha)
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.08
          ..strokeCap = StrokeCap.round;
        final eyeRect = Rect.fromCircle(center: Offset(x, eyeY - r * 0.02), radius: r * 0.14);
        canvas.drawArc(eyeRect, math.pi, math.pi, false, happyPaint);
      }
    }
  }

  void _paintMouth(Canvas canvas, double r, double t) {
    final paint = Paint()
      ..color = _features
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.08
      ..strokeCap = StrokeCap.round;
    final halfW = lerpDouble(0.26, 0.34, t)! * r;
    final my = r * 0.30;
    final controlY = lerpDouble(-0.12, 0.32, t)! * r;
    final path = Path()
      ..moveTo(-halfW, my)
      ..quadraticBezierTo(0, my + controlY, halfW, my);
    canvas.drawPath(path, paint);
  }

  void _paintCheeks(Canvas canvas, double r, double t) {
    final alpha = 0.15 + 0.45 * t;
    final paint = Paint()..color = _blush.withValues(alpha: alpha);
    for (final side in [-1.0, 1.0]) {
      canvas.drawCircle(Offset(side * r * 0.58, r * 0.18), r * 0.13, paint);
    }
  }

  void _paintSweat(Canvas canvas, double r, double alpha) {
    final paint = Paint()..color = _sweat.withValues(alpha: alpha);
    final drop = Offset(r * 0.82, -r * 0.45);
    canvas.drawCircle(drop, r * 0.09, paint);
    final triangle = Path()
      ..moveTo(drop.dx, drop.dy - r * 0.16)
      ..lineTo(drop.dx - r * 0.07, drop.dy - r * 0.01)
      ..lineTo(drop.dx + r * 0.07, drop.dy - r * 0.01)
      ..close();
    canvas.drawPath(triangle, paint);
  }

  void _paintSparkles(Canvas canvas, double r, double t) {
    final paint = Paint()
      ..color = _sparkle.withValues(alpha: t)
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.05
      ..strokeCap = StrokeCap.round;
    _drawSparkle(canvas, Offset(-r * 0.72, -r * 0.72), r * 0.14, paint);
    _drawSparkle(canvas, Offset(r * 0.66, -r * 0.85), r * 0.10, paint);
  }

  void _drawSparkle(Canvas canvas, Offset center, double size, Paint paint) {
    canvas.drawLine(
      Offset(center.dx - size, center.dy),
      Offset(center.dx + size, center.dy),
      paint,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy - size),
      Offset(center.dx, center.dy + size),
      paint,
    );
    canvas.drawLine(
      Offset(center.dx - size * 0.4, center.dy - size * 0.4),
      Offset(center.dx + size * 0.4, center.dy + size * 0.4),
      paint,
    );
    canvas.drawLine(
      Offset(center.dx - size * 0.4, center.dy + size * 0.4),
      Offset(center.dx + size * 0.4, center.dy - size * 0.4),
      paint,
    );
  }

  @override
  bool shouldRepaint(_MoodFigurePainter oldDelegate) =>
      oldDelegate.progress != progress;
}

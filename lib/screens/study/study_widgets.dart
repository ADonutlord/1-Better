import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../services/study_service.dart';
import '../../services/usage_stats_service.dart';

/// Shared widgets for the Study tab and Study statistics screen.

/// Syncs measured device screen time to the server, handling the Android
/// "Usage access" permission flow. Returns true when the data was re-read
/// afterwards (i.e. the caller should reload), false when the user needs to
/// grant the permission first.
Future<bool> syncScreenTimeFlow(
  BuildContext context,
  StudyService study,
) async {
  final granted = await UsageStatsService.instance.hasUsageAccess();
  if (!context.mounted) return false;
  if (!granted) {
    final enable = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        icon: const Icon(Icons.monitor_heart_outlined, size: 32),
        title: const Text('Allow screen-time access?'),
        content: const Text(
          'To measure your screen time automatically (and see which apps you '
          'use most), turn on "Usage access" for 1% Better in Settings. Your '
          'data stays on your device and in your own account.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
    if (enable == true && context.mounted) {
      await UsageStatsService.instance.openUsageSettings();
    }
    return false;
  }

  bool ok;
  try {
    ok = await UsageStatsService.instance.syncToServer();
  } catch (e) {
    ok = false;
  }
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok ? 'Screen time synced ✓' : 'Could not sync screen time.'),
    ));
  }
  return ok;
}

class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
  });

  final String icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Text(icon, style: const TextStyle(fontSize: 28)),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: theme.textTheme.labelMedium?.copyWith(
                        letterSpacing: 1.1,
                        fontWeight: FontWeight.w800,
                        color: theme.colorScheme.onSurfaceVariant)),
                const SizedBox(height: 2),
                Text(value,
                    style: theme.textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w800)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A small legend chip for a chart series.
class ChartLegend extends StatelessWidget {
  const ChartLegend({super.key, required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(label,
            style: theme.textTheme.bodySmall
                ?.copyWith(fontWeight: FontWeight.w600)),
      ],
    );
  }
}

/// Grouped bar chart showing two series per day (e.g. study vs screen time)
/// for the current week (Monday first). Values are in hours.
class WeekDualBarChart extends StatelessWidget {
  const WeekDualBarChart({
    super.key,
    required this.study,
    required this.screen,
    this.studyColor,
    this.screenColor,
  });

  final List<MapEntry<DateTime, double>> study;
  final List<MapEntry<DateTime, double>> screen;
  final Color? studyColor;
  final Color? screenColor;

  static const _days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return CustomPaint(
      painter: _DualBarChartPainter(
        study: study.map((e) => e.value).toList(),
        screen: screen.map((e) => e.value).toList(),
        labels: _days,
        studyColor: studyColor ?? theme.colorScheme.primary,
        screenColor: screenColor ?? const Color(0xFFE8590C),
        labelColor: theme.colorScheme.onSurfaceVariant,
        gridColor: theme.colorScheme.surfaceContainerHighest,
      ),
      size: Size.infinite,
    );
  }
}

class _DualBarChartPainter extends CustomPainter {
  _DualBarChartPainter({
    required this.study,
    required this.screen,
    required this.labels,
    required this.studyColor,
    required this.screenColor,
    required this.labelColor,
    required this.gridColor,
  });

  final List<double> study;
  final List<double> screen;
  final List<String> labels;
  final Color studyColor;
  final Color screenColor;
  final Color labelColor;
  final Color gridColor;

  static const _minCap = 8.0; // y-axis cap in hours

  @override
  void paint(Canvas canvas, Size size) {
    final todayIndex = DateTime.now().weekday - 1;

    final maxValue = <double>[...study, ...screen].fold<double>(
        0, (m, v) => v > m ? v : m);
    final cap = math.max(_minCap, (maxValue * 1.15).ceilToDouble());

    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (var i = 0; i <= 4; i++) {
      final y = size.height - (size.height * i / 4);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    if (study.isEmpty || screen.isEmpty) return;

    final n = study.length;
    final slot = size.width / n;
    final groupWidth = slot * 0.6;
    final barWidth = groupWidth / 2 - 2;
    final baseline = size.height - 18;

    // Y-axis hour labels on the grid lines.
    final gridLabelStyle = TextStyle(color: labelColor.withValues(alpha: 0.6), fontSize: 9);
    for (var i = 0; i <= 4; i++) {
      final label = '${(cap * (4 - i) / 4).toStringAsFixed(0)}h';
      final tp = TextPainter(
        text: TextSpan(text: label, style: gridLabelStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(2, size.height - (size.height * i / 4) - tp.height - 2));
    }

    for (var i = 0; i < n; i++) {
      final centerX = slot * i + slot / 2;
      final groupLeft = centerX - groupWidth / 2;

      final studyH = (study[i] / cap) * (baseline - 6);
      final screenH = (screen[i] / cap) * (baseline - 6);

      _bar(canvas, Rect.fromLTWH(groupLeft, baseline - studyH, barWidth, studyH),
          studyColor);
      _bar(canvas,
          Rect.fromLTWH(groupLeft + barWidth + 4, baseline - screenH, barWidth,
              screenH),
          screenColor);

      // Day label
      final tp = TextPainter(
        text: TextSpan(
          text: labels[i],
          style: TextStyle(color: labelColor, fontSize: 12),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(centerX - tp.width / 2, baseline + 4));

      // Outline today's column.
      if (i == todayIndex) {
        final rect = Rect.fromLTRB(
            groupLeft - 2, baseline - math.max(studyH, screenH) - 4,
            groupLeft + groupWidth + 2, baseline + 2);
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(6)),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5
            ..color = labelColor.withValues(alpha: 0.5),
        );
      }
    }
  }

  void _bar(Canvas canvas, Rect rect, Color color) {
    if (rect.height <= 0.5) {
      // hollow marker for a zero day
      final marker = Rect.fromCenter(
        center: Offset(rect.center.dx, rect.bottom - 4),
        width: rect.width * 0.7,
        height: 4,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(marker, const Radius.circular(2)),
        Paint()..color = color.withValues(alpha: 0.4),
      );
      return;
    }
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        rect,
        topLeft: const Radius.circular(5),
        topRight: const Radius.circular(5),
      ),
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(covariant _DualBarChartPainter oldDelegate) =>
      oldDelegate.study != study ||
      oldDelegate.screen != screen ||
      oldDelegate.studyColor != studyColor ||
      oldDelegate.screenColor != screenColor;
}

/// Formats a fractional-hour value as "Xh Ym" (or just minutes under an hour).
String formatHours(double h) {
  final totalMinutes = (h * 60).round();
  final hrs = totalMinutes ~/ 60;
  final mins = totalMinutes % 60;
  if (hrs == 0) return '${mins}m';
  if (mins == 0) return '${hrs}h';
  return '${hrs}h ${mins}m';
}

/// Screen time relative to study time as a compact ratio, e.g. "3.2 : 1"
/// (about three hours screen per hour studied). Returns "—" when there's no
/// study time to compare against.
String screenStudyRatio(double screenHours, double studyHours) {
  if (studyHours <= 0) return '—';
  final ratio = screenHours / studyHours;
  final text = ratio >= 10
      ? ratio.toStringAsFixed(0)
      : ratio.toStringAsFixed(1);
  return '$text : 1';
}

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../services/study_service.dart';

/// Shared widgets for the Study tab and Study statistics screen.

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

/// A screen where the student logs their daily screen-time minutes for each
/// day of the current week. [days] maps a local date to hours of screen time.
///
/// Apps can't read device screen-usage automatically, so the student enters it
/// from Digital Wellbeing / Screen Time; we store it via `set_screen_time`.
class ScreenTimeSheet extends StatefulWidget {
  const ScreenTimeSheet({super.key, required this.days});

  final List<MapEntry<DateTime, double>> days;

  @override
  State<ScreenTimeSheet> createState() => _ScreenTimeSheetState();
}

class _ScreenTimeSheetState extends State<ScreenTimeSheet> {
  final StudyService _study = StudyService.instance;
  final Map<int, TextEditingController> _controllers = {};
  bool _saving = false;

  static const _names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  void initState() {
    super.initState();
    for (final day in widget.days) {
      _controllers[day.key.millisecondsSinceEpoch] =
          TextEditingController(text: (day.value * 60).round().toString());
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    var failed = false;
    for (final day in widget.days) {
      final c = _controllers[day.key.millisecondsSinceEpoch];
      final raw = c?.text.trim() ?? '';
      final minutes = int.tryParse(raw) ?? -1;
      if (minutes < 0 || minutes > 24 * 60) continue;
      try {
        await _study.setScreenTime(day.key, minutes);
      } catch (_) {
        failed = true;
      }
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(
          failed ? 'Some entries could not be saved.' : 'Screen time saved ✓'),
    ));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Log screen time'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: const Text('Save'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('📱 Screen time this week',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  Text(
                    'Apps can\'t read your screen time automatically. Enter each '
                    'day\'s total from your phone\'s Digital Wellbeing / Screen '
                    'Time screen so we can graph it and compare it to your study '
                    'time.',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < widget.days.length; i++)
            if (widget.days[i].key
                .isBefore(DateTime.now().add(const Duration(days: 1)))) ...[
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  child: Text(_names[i],
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w700)),
                ),
                title: Text(
                  '${widget.days[i].key.day} ${_month(widget.days[i].key.month)}',
                ),
                trailing: SizedBox(
                  width: 120,
                  child: TextField(
                    controller:
                        _controllers[widget.days[i].key.millisecondsSinceEpoch],
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      suffixText: 'min',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              const Divider(height: 1),
            ],
        ],
      ),
    );
  }

  static String _month(int m) =>
      const ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep',
          'Oct', 'Nov', 'Dec'][m - 1];
}

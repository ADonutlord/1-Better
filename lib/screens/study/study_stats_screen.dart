import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../services/study_service.dart';
import 'study_timer_screen.dart';
import 'study_widgets.dart';

/// Full-screen study statistics: weekly study vs screen time bar graph,
/// today's numbers, today's per-app screen-time breakdown, and daily averages.
/// Screen time is measured automatically (Android UsageStatsManager).
class StudyStatsScreen extends StatefulWidget {
  const StudyStatsScreen({super.key});

  @override
  State<StudyStatsScreen> createState() => _StudyStatsScreenState();
}

class _StudyStatsScreenState extends State<StudyStatsScreen> {
  static const _screenAreaColor = Color(0xFFE8590C);

  final StudyService _study = StudyService.instance;
  List<MapEntry<DateTime, double>>? _studyWeek;
  List<MapEntry<DateTime, double>>? _screenWeek;
  List<AppUsage>? _todayApps;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final (study, screen) = await _study.weekHours();
      final todayApps = await _study.fetchAppUsage(day: DateTime.now());
      if (!mounted) return;
      setState(() {
        _studyWeek = study;
        _screenWeek = screen;
        _todayApps = todayApps;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _syncScreenTime() async {
    final changed = await syncScreenTimeFlow(context, _study);
    if (changed && mounted) _load();
  }

  Future<void> _openTimer() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const StudyTimerScreen()),
    );
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final study = _studyWeek;
    final screen = _screenWeek;

    final todayIndex = DateTime.now().weekday - 1;
    final todayStudy =
        (study != null && study.length > todayIndex) ? study[todayIndex].value : 0.0;
    final todayScreen =
        (screen != null && screen.length > todayIndex) ? screen[todayIndex].value : 0.0;
    final avgStudy = StudyService.averageOf(study ?? const []);
    final avgScreen = StudyService.averageOf(screen ?? const []);
    final hasStudy = (avgStudy ?? 0) > 0;
    final hasScreen = (avgScreen ?? 0) > 0;
    final weekScreenHours =
        (screen ?? const []).fold<double>(0, (s, e) => s + e.value);
    final weekStudyHours =
        (study ?? const []).fold<double>(0, (s, e) => s + e.value);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Study statistics'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text('Could not load stats: $_error',
                        textAlign: TextAlign.center),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    FilledButton.icon(
                      onPressed: _openTimer,
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Start a study session'),
                    ),
                    const SizedBox(height: 18),
                    Text('THIS WEEK (MON–SUN)',
                        style: theme.textTheme.labelLarge?.copyWith(
                            letterSpacing: 1.1, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 12),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
                        child: Column(
                          children: [
                            SizedBox(
                              height: 200,
                              child: WeekDualBarChart(
                                study: study!,
                                screen: screen!,
                                screenColor: _screenAreaColor,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                ChartLegend(
                                    color: theme.colorScheme.primary,
                                    label: 'Study'),
                                const SizedBox(width: 18),
                                ChartLegend(
                                    color: _screenAreaColor,
                                    label: 'Screen time'),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerRight,
                      child: OutlinedButton.icon(
                        onPressed: _syncScreenTime,
                        icon: const Icon(Icons.sync, size: 16),
                        label: const Text('Sync screen time'),
                        style: OutlinedButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: StatCard(
                            icon: '🎯',
                            label: 'STUDY TODAY',
                            value: formatHours(todayStudy),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: StatCard(
                            icon: '📱',
                            label: 'SCREEN TODAY',
                            value: formatHours(todayScreen),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: StatCard(
                            icon: '📈',
                            label: 'AVG STUDY/DAY',
                            value: hasStudy ? formatHours(avgStudy!) : '—',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: StatCard(
                            icon: '📉',
                            label: 'AVG SCREEN/DAY',
                            value: hasScreen ? formatHours(avgScreen!) : '—',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    StatCard(
                      icon: '⚖️',
                      label: 'SCREEN : STUDY RATIO',
                      value: screenStudyRatio(weekScreenHours, weekStudyHours),
                    ),
                    const SizedBox(height: 14),
                    _TodayAppBreakdown(apps: _todayApps),
                    const SizedBox(height: 12),
                    Center(
                      child: Text(
                        hasStudy
                            ? 'Keep it up — your focus is compounding. 🌱'
                            : 'Start a study session to fill your chart. 📚',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ),
                  ],
                ),
    );
  }
}

/// Today's per-app screen-time list, straight from the device measurement.
class _TodayAppBreakdown extends StatelessWidget {
  const _TodayAppBreakdown({required this.apps});

  final List<AppUsage>? apps;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final list = apps ?? const <AppUsage>[];

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("TODAY'S SCREEN TIME BY APP",
                style: theme.textTheme.labelLarge?.copyWith(
                    letterSpacing: 1.1, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(
              'Measured automatically from your device — including home',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            if (list.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'Nothing logged yet. Tap "Sync screen time" to pull today\'s '
                  'usage from your phone.',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              )
            else
              for (final app in list)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                    child: Text(
                      app.label.isEmpty
                          ? '?'
                          : app.label.characters.first.toUpperCase(),
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                  ),
                  title: Text(app.label,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  trailing: Text(formatHours(app.minutes / 60),
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800)),
                ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../services/study_service.dart';
import 'study_timer_screen.dart';
import 'study_widgets.dart';

/// The Study tab in the main navigation. Shows weekly "hours studied" vs
/// "screen time" statistics and a shortcut to start a (lockdown) session.
class StudyScreen extends StatefulWidget {
  const StudyScreen({super.key});

  @override
  State<StudyScreen> createState() => _StudyScreenState();
}

class _StudyScreenState extends State<StudyScreen> {
  static const _screenAreaColor = Color(0xFFE8590C);

  final StudyService _study = StudyService.instance;

  List<MapEntry<DateTime, double>>? _studyWeek;
  List<MapEntry<DateTime, double>>? _screenWeek;
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
      if (!mounted) return;
      setState(() {
        _studyWeek = study;
        _screenWeek = screen;
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

  Future<void> _openTimer() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const StudyTimerScreen()),
    );
    if (mounted) _load();
  }

  Future<void> _syncScreenTime() async {
    final changed = await syncScreenTimeFlow(context, _study);
    if (changed && mounted) _load();
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
    final studyIsolated = (avgStudy ?? 0) > 0;
    final screenIsolated = (avgScreen ?? 0) > 0;
    final weekScreenHours =
        (screen ?? const []).fold<double>(0, (s, e) => s + e.value);
    final weekStudyHours =
        (study ?? const []).fold<double>(0, (s, e) => s + e.value);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Study'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          FilledButton.icon(
            onPressed: _openTimer,
            icon: const Icon(Icons.school_outlined),
            label: const Text('Start a study session'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              textStyle:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 8),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Could not load stats: $_error',
                    textAlign: TextAlign.center),
              ),
            )
          else ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Text('THIS WEEK (MON–SUN)',
                    style: theme.textTheme.labelLarge?.copyWith(
                        letterSpacing: 1.1, fontWeight: FontWeight.w800)),
                const Spacer(),
                OutlinedButton.icon(
                  onPressed: _syncScreenTime,
                  icon: const Icon(Icons.sync, size: 16),
                  label: const Text('Sync screen time'),
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],
            ),
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
                            color: _screenAreaColor, label: 'Screen time'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
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
                    value: studyIsolated
                        ? formatHours(avgStudy ?? 0)
                        : '—',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: StatCard(
                    icon: '📉',
                    label: 'AVG SCREEN/DAY',
                    value: screenIsolated
                        ? formatHours(avgScreen ?? 0)
                        : '—',
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
            const SizedBox(height: 16),
            Center(
              child: Text(
                studyIsolated
                    ? 'Keep it up — your focus is compounding. 🌱'
                    : 'Start a study session to fill your chart. 📚',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

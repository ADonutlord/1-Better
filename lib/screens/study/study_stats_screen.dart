import 'package:flutter/material.dart';

import '../../services/study_service.dart';
import 'study_timer_screen.dart';
import 'study_widgets.dart';

/// Full-screen study statistics: weekly study vs screen time bar graph,
/// today's numbers, and daily averages. Also opens the (lockdown) study timer.
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

  Future<void> _editScreenTime(List<MapEntry<DateTime, double>> days) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ScreenTimeSheet(days: days)),
    );
    if (mounted) _load();
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
                                const SizedBox(width: 6),
                                TextButton(
                                  onPressed: () => _editScreenTime(screen),
                                  child: const Text('Edit'),
                                ),
                              ],
                            ),
                          ],
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
                    Text(
                      'Apps can\'t read your screen time automatically. Use '
                      '"Edit" to log each day\'s total from your phone\'s '
                      'Digital Wellbeing / Screen Time screen.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 16),
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

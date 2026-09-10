import 'package:one_percent_better/models/models.dart';
import 'package:one_percent_better/services/supabase_service.dart';
import 'package:one_percent_better/services/usage_stats_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

/// Records study sessions (and the XP they earn), and provides the weekly screen
/// time statistics used by the Study tab. Screen time is measured automatically
/// through [UsageStatsService] (Android UsageStatsManager) and persisted by the
/// `log_day_usage` RPC; reads go through direct selects.
///
/// Reads use direct selects (RLS confines them to the caller's own rows);
/// all writes go through SECURITY DEFINER RPCs.
class StudyService {
  StudyService._();

  static final StudyService instance = StudyService._();

  SupabaseClient get _client => SupabaseService.instance.client;

  /// True when running on Android.
  bool get isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Measures screen time on the device and stores it server-side for the
  /// current week. Safe to call on any platform (no-op on non-Android).
  Future<void> syncScreenTimeFromDevice({int days = 7}) async {
    await UsageStatsService.instance.syncToServer(days: days);
  }

  /// Per-app screen time breakdown for [day], biggest first.
  Future<List<AppUsage>> fetchAppUsage({required DateTime day}) async {
    final rows = await _client
        .from('app_screen_time')
        .select('package_name, app_label, minutes')
        .eq('day', _dateString(day))
        .order('minutes', ascending: false);
    return [
      for (final r in rows)
        AppUsage(
          package: (r['package_name'] as String?) ?? '',
          label: (r['app_label'] as String?) ?? '',
          minutes: (r['minutes'] as num?)?.toInt() ?? 0,
        ),
    ];
  }

  /// Persists a finished study block server-side. The server also awards
  /// 5 XP per minute studied (returned in the response as `xp_awarded`).
  Future<int> recordSession({
    required DateTime startedAt,
    required DateTime endedAt,
  }) async {
    final res = await _client.rpc('record_study_session', params: {
      'p_started_at': startedAt.toUtc().toIso8601String(),
      'p_ended_at': endedAt.toUtc().toIso8601String(),
    });
    final map = (res as Map?)?.cast<String, dynamic>() ?? const {};
    return (map['xp_awarded'] as int?) ?? 0;
  }

  /// Fetches the caller's study sessions since [since] (inclusive), ordered
  /// oldest-first for easy aggregation.
  Future<List<StudySession>> fetchSessions({DateTime? since}) async {
    var query = _client
        .from('study_sessions')
        .select();
    if (since != null) {
      query = query.gte('started_at', since.toUtc().toIso8601String());
    }
    final rows = await query.order('started_at', ascending: true);
    return rows.map(StudySession.fromJson).toList();
  }

  /// Fetches the caller's logged screen-time entries for the current week.
  Future<List<DailyScreenTime>> fetchScreenTimeWeek() async {
    final monday = _startOfWeek(DateTime.now());
    final rows = await _client
        .from('daily_screen_time')
        .select()
        .gte('day', _dateString(monday))
        .order('day', ascending: true);
    return rows.map(DailyScreenTime.fromJson).toList();
  }

  /// Sums studied seconds per day and screen-time minutes per day for the
  /// current week (Monday first). Values are in hours.
  Future<({List<MapEntry<DateTime, double>> study, List<MapEntry<DateTime, double>> screen})>
      weekData() async {
    final monday = _startOfWeek(DateTime.now());
    final sessions = await fetchSessions(since: monday);
    final screen = await fetchScreenTimeWeek();

    final studyHours = <int, double>{};
    final screenHours = <int, double>{};
    for (var i = 0; i < 7; i++) {
      final key = monday.add(Duration(days: i)).millisecondsSinceEpoch;
      studyHours[key] = 0;
      screenHours[key] = 0;
    }
    for (final s in sessions) {
      final day = DateTime(s.endedAt.year, s.endedAt.month, s.endedAt.day);
      if (day.isBefore(monday) || day.isAfter(monday.add(const Duration(days: 6)))) {
        continue;
      }
      final key = day.millisecondsSinceEpoch;
      studyHours[key] = (studyHours[key] ?? 0) + s.durationHours;
    }
    for (final t in screen) {
      if (t.day.isBefore(monday) || t.day.isAfter(monday.add(const Duration(days: 6)))) {
        continue;
      }
      final key = t.day.millisecondsSinceEpoch;
      screenHours[key] = (screenHours[key] ?? 0) + t.hours;
    }

    List<MapEntry<DateTime, double>> toDays(Map<int, double> map) {
      final ordered = map.entries.toList()
        ..sort((a, b) => a.key.compareTo(b.key));
      return ordered
          .map((e) => MapEntry(DateTime.fromMillisecondsSinceEpoch(e.key), e.value))
          .toList();
    }

    return (study: toDays(studyHours), screen: toDays(screenHours));
  }

  /// Convenience: current week broken into study + screen hours lists.
  Future<(List<MapEntry<DateTime, double>>, List<MapEntry<DateTime, double>>)>
      weekHours() async {
    final data = await weekData();
    return (data.study, data.screen);
  }

  /// Average daily time (hours) per elapsed day of the current week
  /// (Monday..today). Returns null when [days] is empty.
  static double? averageOf(List<MapEntry<DateTime, double>> days) {
    if (days.isEmpty) return null;
    final total = days.fold<double>(0, (sum, d) => sum + d.value);
    final elapsedDays = _elapsedDays(DateTime.now());
    return total / elapsedDays;
  }

  /// Number of elapsed days (1-based) since the start of the current week.
  static int _elapsedDays(DateTime now) {
    final monday = _startOfWeek(now);
    return now.difference(monday).inDays + 1;
  }

  /// The Monday (00:00 local) that starts [date]'s week.
  static DateTime _startOfWeek(DateTime date) {
    final local = DateTime(date.year, date.month, date.day);
    return local.subtract(Duration(days: local.weekday - 1));
  }

  /// Formats a local date as YYYY-MM-DD for the `day` column.
  static String _dateString(DateTime d) => '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

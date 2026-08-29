import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:one_percent_better/models/schedule.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Manages user-created schedules that fire local notifications at configured
/// times. Each schedule is delivered either as a banner [ScheduleType.reminder]
/// or a full-screen, loud [ScheduleType.alarm].
///
/// Works on Android, Linux and Windows. Schedules are persisted on-device via
/// [SharedPreferences] and re-registered with the OS on app startup so they
/// survive reboots and time-zone changes.
class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  static const String _schedulesKey = 'schedules_v1';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const String _reminderChannelId = 'scheduled_reminders';
  static const String _reminderChannelName = 'Reminders';
  static const String _reminderChannelDescription =
      'Scheduled reminders you create.';

  static const String _alarmChannelId = 'scheduled_alarms';
  static const String _alarmChannelName = 'Alarms';
  static const String _alarmChannelDescription =
      'Loud full-screen alarms you create.';

  bool _initialized = false;
  List<Schedule> _schedules = [];
  List<Schedule> get schedules => List.unmodifiable(_schedules);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_schedulesKey);
    if (raw == null || raw.isEmpty) {
      _schedules = [];
      return;
    }
    try {
      final list = jsonDecode(raw) as List;
      _schedules = list
          .whereType<Map<String, dynamic>>()
          .map(Schedule.fromJson)
          .toList();
    } catch (_) {
      _schedules = [];
    }
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _schedulesKey,
      jsonEncode(_schedules.map((s) => s.toJson()).toList()),
    );
  }

  bool _isSupported() {
    if (kIsWeb) return false;
    return Platform.isAndroid || Platform.isLinux || Platform.isWindows;
  }

  Future<void> _init() async {
    if (_initialized) return;
    tzdata.initializeTimeZones();
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('UTC'));
    }

    const androidSettings = AndroidInitializationSettings('ic_stat_sprout');
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const linuxSettings = LinuxInitializationSettings(
      defaultActionName: 'Open',
    );
    const windowsSettings = WindowsInitializationSettings(
      appName: '1% Better',
      appUserModelId: 'com.onepercentbetter.one_percent_better',
      guid: 'com.onepercentbetter.one_percent_better',
    );

    const settings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
      macOS: darwinSettings,
      linux: linuxSettings,
      windows: windowsSettings,
    );

    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (response) async {
        // Opening the notification / alarm just brings the app forward.
      },
    );
    _initialized = true;
  }

  int _notificationId(String scheduleId, {int? day}) {
    final base = scheduleId.hashCode & 0x0000FFFF;
    return day == null ? base : (base << 8) | (day & 0xFF);
  }

  /// Every OS notification id owned by a schedule (multiple for weekly).
  List<int> _ownerIds(String scheduleId, List<int> days) {
    if (days.isEmpty) return [_notificationId(scheduleId)];
    return days.map((d) => _notificationId(scheduleId, day: d)).toList();
  }

  NotificationDetails _detailsFor(ScheduleType type) {
    if (type == ScheduleType.alarm) {
      return const NotificationDetails(
        android: AndroidNotificationDetails(
          _alarmChannelId,
          _alarmChannelName,
          channelDescription: _alarmChannelDescription,
          importance: Importance.max,
          priority: Priority.max,
          category: AndroidNotificationCategory.alarm,
          playSound: true,
          ongoing: true,
          autoCancel: false,
          fullScreenIntent: true,
          ticker: 'Alarm',
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentSound: true,
        ),
        macOS: DarwinNotificationDetails(
          presentAlert: true,
          presentSound: true,
        ),
      );
    }
    return const NotificationDetails(
      android: AndroidNotificationDetails(
        _reminderChannelId,
        _reminderChannelName,
        channelDescription: _reminderChannelDescription,
        importance: Importance.high,
        priority: Priority.high,
        playSound: true,
        ticker: 'Reminder',
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentSound: true,
      ),
      macOS: DarwinNotificationDetails(
        presentAlert: true,
        presentSound: true,
      ),
    );
  }

  /// The next future occurrence of [hour]:[minute] on [weekday] (1 = Mon).
  tz.TZDateTime _nextOfWeekday(int weekday, int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    for (var i = 0; i < 8; i++) {
      final candidate = tz.TZDateTime(
          tz.local, now.year, now.month, now.day, hour, minute);
      final shifted = candidate.add(Duration(days: i));
      if (shifted.weekday == weekday && shifted.isAfter(now)) {
        return shifted;
      }
    }
    return tz.TZDateTime(
            tz.local, now.year, now.month, now.day, hour, minute)
        .add(const Duration(days: 7));
  }

  /// The next future occurrence of [hour]:[minute] for a daily schedule.
  tz.TZDateTime _nextDaily(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
        tz.local, now.year, now.month, now.day, hour, minute);
    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  /// Registers a schedule with the OS (used for create, update and restore).
  ///
  /// Daily -> one repeating task. Weekly -> one repeating task per selected
  /// weekday. One-off -> a single task with no repeat component.
  Future<void> _register(Schedule s) async {
    if (!s.enabled) return;
    final details = _detailsFor(s.type);
    final alarm = s.type == ScheduleType.alarm;
    final mode = alarm
        ? AndroidScheduleMode.alarmClock
        : AndroidScheduleMode.inexactAllowWhileIdle;
    final body =
        alarm ? 'Alarm set for ${s.timeLabel}.' : 'Time to ${s.title}.';

    if (s.repeat == ScheduleRepeat.once) {
      final date = DateTime.tryParse(s.onceDate ?? '');
      if (date == null) return;
      var scheduled = tz.TZDateTime(
          tz.local, date.year, date.month, date.day, s.hour, s.minute);
      if (!scheduled.isAfter(tz.TZDateTime.now(tz.local))) return;
      await _plugin.zonedSchedule(
        _notificationId(s.id),
        s.title,
        body,
        scheduled,
        details,
        androidScheduleMode: mode,
      );
      return;
    }

    if (s.repeat == ScheduleRepeat.weekly) {
      if (s.days.isEmpty) return;
      for (final day in s.days.toSet()) {
        await _plugin.zonedSchedule(
          _notificationId(s.id, day: day),
          '${s.title} (${_dayName(day)})',
          body,
          _nextOfWeekday(day, s.hour, s.minute),
          details,
          androidScheduleMode: mode,
          matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        );
      }
      return;
    }

    // Daily.
    await _plugin.zonedSchedule(
      _notificationId(s.id),
      s.title,
      body,
      _nextDaily(s.hour, s.minute),
      details,
      androidScheduleMode: mode,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  String _dayName(int weekday) => const [
        'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun',
      ][weekday - 1];

  Future<void> _ensureInitialized() async {
    if (!_isSupported()) return;
    await _init();
    await _requestPermissions();
  }

  Future<void> addSchedule(Schedule s) async {
    await _ensureInitialized();
    _schedules = [..._schedules, s];
    await _persist();
    await _register(s);
  }

  Future<void> updateSchedule(Schedule s) async {
    await _ensureInitialized();
    final idx = _schedules.indexWhere((x) => x.id == s.id);
    if (idx < 0) return;
    // Cancel anything previously scheduled for this schedule (all weekdays).
    for (final id in _ownerIds(_schedules[idx].id, _schedules[idx].days)) {
      await _plugin.cancel(id);
    }
    _schedules[idx] = s;
    await _persist();
    await _register(s);
  }

  Future<void> deleteSchedule(String id) async {
    final existing = _schedules.firstWhere(
      (x) => x.id == id,
      orElse: () => Schedule(
        id: id, title: '', hour: 8, minute: 0),
    );
    _schedules = _schedules.where((x) => x.id != id).toList();
    await _persist();
    if (_isSupported()) {
      for (final nid in _ownerIds(id, existing.days)) {
        await _plugin.cancel(nid);
      }
    }
  }

  /// Re-registers every enabled schedule with the OS. Called on app startup.
  Future<void> restoreAll() async {
    if (_schedules.isEmpty) return;
    await _ensureInitialized();
    for (final s in _schedules) {
      await _register(s);
    }
  }

  Future<void> _requestPermissions() async {
    if (!Platform.isAndroid) return;
    final android = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestNotificationsPermission();
    await android?.requestExactAlarmsPermission();
    await android?.requestFullScreenIntentPermission();
  }
}

/// A user-configured schedule that fires a local notification.
///
/// Every schedule has a time of day, a repeat pattern, and a delivery type:
/// - [ScheduleType.reminder] -> a normal banner notification.
/// - [ScheduleType.alarm] -> a loud, full-screen alarm that shows over the
///   lock screen and rings until dismissed.
///
/// Schedules are stored purely on-device via [shared_preferences]; nothing is
/// sent to the server.
class Schedule {
  const Schedule({
    required this.id,
    required this.title,
    required this.hour,
    required this.minute,
    this.repeat = ScheduleRepeat.daily,
    this.days = const [],
    this.onceDate,
    this.type = ScheduleType.reminder,
    this.enabled = true,
  });

  final String id;
  final String title;
  final int hour;
  final int minute;

  /// Daily, weekly (on selected [days]) or a single one-off fire.
  final ScheduleRepeat repeat;

  /// ISO weekday numbers (1 = Monday .. 7 = Sunday), used when
  /// [repeat] is [ScheduleRepeat.weekly].
  final List<int> days;

  /// For [ScheduleRepeat.once], the date (ISO string) on which to fire.
  final String? onceDate;

  /// Whether it is delivered as a banner notification or a full-screen alarm.
  final ScheduleType type;

  final bool enabled;

  String get timeLabel {
    final hour12 = hour % 12 == 0 ? 12 : hour % 12;
    final period = hour < 12 ? 'AM' : 'PM';
    final mm = minute.toString().padLeft(2, '0');
    return '$hour12:$mm $period';
  }

  String get repeatLabel {
    if (repeat == ScheduleRepeat.daily) return 'Every day';
    if (repeat == ScheduleRepeat.once) {
      final date = DateTime.tryParse(onceDate ?? '');
      if (date != null) {
        const months = [
          'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
          'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
        ];
        return '${date.day} ${months[date.month - 1]}';
      }
      return 'One time';
    }
    const dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    if (days.isEmpty) return 'Weekly';
    final names = days.map((d) => dayNames[d - 1]).join(', ');
    return names;
  }

  factory Schedule.fromJson(Map<String, dynamic> json) {
    return Schedule(
      id: (json['id'] as String?) ?? '',
      title: (json['title'] as String?) ?? 'Reminder',
      hour: (json['hour'] as int?) ?? 8,
      minute: (json['minute'] as int?) ?? 0,
      repeat: switch (json['repeat'] as String?) {
        'daily' => ScheduleRepeat.daily,
        'once' => ScheduleRepeat.once,
        _ => ScheduleRepeat.weekly,
      },
      days: ((json['days'] as List?) ?? const [])
          .map((e) => e is int ? e : int.tryParse('$e') ?? 1)
          .toList(),
      onceDate: json['once_date'] as String?,
      type: (json['type'] as String?) == 'alarm'
          ? ScheduleType.alarm
          : ScheduleType.reminder,
      enabled: (json['enabled'] as bool?) ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'hour': hour,
        'minute': minute,
        'repeat': repeat.name,
        'days': days,
        'once_date': onceDate,
        'type': type.name,
        'enabled': enabled,
      };
}

enum ScheduleRepeat { daily, weekly, once }

enum ScheduleType { reminder, alarm }

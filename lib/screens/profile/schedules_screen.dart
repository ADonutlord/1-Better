import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../models/schedule.dart';
import '../../services/notification_service.dart';

/// Lists user-created schedules and lets the user add, edit or delete them.
/// Each schedule can be delivered as a banner [ScheduleType.reminder] or a
/// full-screen, loud [ScheduleType.alarm].
class SchedulesScreen extends StatefulWidget {
  const SchedulesScreen({super.key});

  @override
  State<SchedulesScreen> createState() => _SchedulesScreenState();
}

class _SchedulesScreenState extends State<SchedulesScreen> {
  final NotificationService _service = NotificationService.instance;

  bool get _supported {
    if (kIsWeb) return false;
    return Platform.isAndroid || Platform.isLinux || Platform.isWindows;
  }

  Future<void> _add() async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _ScheduleEditor(),
    );
    if (created == true && mounted) setState(() {});
  }

  Future<void> _edit(Schedule schedule) async {
    final updated = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _ScheduleEditor(initial: schedule),
    );
    if (updated == true && mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final schedules = _service.schedules;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('Schedules & Alarms')),
      floatingActionButton: _supported
          ? FloatingActionButton.extended(
              onPressed: _add,
              icon: const Icon(Icons.add_alarm_outlined),
              label: const Text('New schedule'),
            )
          : null,
      body: SafeArea(
        child: schedules.isEmpty
            ? _Empty(onAdd: _supported ? _add : null)
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                children: [
                  for (final schedule in schedules) ...[
                    _ScheduleTile(
                      schedule: schedule,
                      onTap: () => _edit(schedule),
                      supported: _supported,
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (!_supported)
                    const _UnsupportedBanner(),
                ],
              ),
      ),
    );
  }
}

class _ScheduleTile extends StatelessWidget {
  const _ScheduleTile({
    required this.schedule,
    required this.onTap,
    required this.supported,
  });

  final Schedule schedule;
  final VoidCallback onTap;
  final bool supported;

  Future<void> _confirmDelete(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete schedule?'),
        content: Text(
            '"${schedule.title}" (${schedule.timeLabel}) will be removed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await NotificationService.instance.deleteSchedule(schedule.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isAlarm = schedule.type == ScheduleType.alarm;
    final enabled = schedule.enabled && supported;
    final color = isAlarm ? theme.colorScheme.error : theme.colorScheme.primary;

    return Card(
      child: Opacity(
        opacity: enabled ? 1 : 0.55,
        child: ListTile(
          onTap: onTap,
          leading: CircleAvatar(
            backgroundColor: color.withValues(alpha: 0.15),
            child: Icon(
              isAlarm ? Icons.alarm : Icons.notifications_outlined,
              color: color,
            ),
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  schedule.timeLabel,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (isAlarm)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'ALARM',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(schedule.title),
                const SizedBox(height: 2),
                Text(
                  schedule.repeatLabel,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'Delete',
                icon: const Icon(Icons.delete_outline),
                onPressed: () => _confirmDelete(context),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScheduleEditor extends StatefulWidget {
  const _ScheduleEditor({this.initial});

  final Schedule? initial;

  @override
  State<_ScheduleEditor> createState() => _ScheduleEditorState();
}

class _ScheduleEditorState extends State<_ScheduleEditor> {
  final NotificationService _service = NotificationService.instance;
  late final TextEditingController _titleController;
  late TimeOfDay _time;
  late ScheduleRepeat _repeat;
  late Set<int> _days;
  DateTime? _onceDate;
  late ScheduleType _type;
  bool _saving = false;

  static const _dayNames = [
    'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun',
  ];

  @override
  void initState() {
    super.initState();
    final s = widget.initial;
    _titleController = TextEditingController(text: s?.title ?? '');
    _time = TimeOfDay(hour: s?.hour ?? 8, minute: s?.minute ?? 0);
    _repeat = s?.repeat ?? ScheduleRepeat.daily;
    _days = (s?.days ?? [1, 2, 3, 4, 5]).toSet();
    _onceDate = DateTime.tryParse(s?.onceDate ?? '');
    _type = s?.type ?? ScheduleType.reminder;
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time,
    );
    if (picked != null) setState(() => _time = picked);
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Give your schedule a label.')),
      );
      return;
    }
    final now = DateTime.now();
    final isEdit = widget.initial != null;
    final id = isEdit ? widget.initial!.id : now.microsecondsSinceEpoch.toString();
    final onceDate = _repeat == ScheduleRepeat.once && _onceDate != null
        ? DateTime(_onceDate!.year, _onceDate!.month, _onceDate!.day)
            .toIso8601String()
        : null;

    final schedule = Schedule(
      id: id,
      title: title,
      hour: _time.hour,
      minute: _time.minute,
      repeat: _repeat,
      days: _days.toList()..sort(),
      onceDate: onceDate,
      type: _type,
      enabled: true,
    );

    setState(() => _saving = true);
    try {
      if (isEdit) {
        await _service.updateSchedule(schedule);
      } else {
        await _service.addSchedule(schedule);
      }
      if (!mounted) return;
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isEdit
                ? 'Schedule updated. 🌱'
                : '${schedule.type == ScheduleType.alarm ? 'Alarm' : 'Reminder'} set for ${schedule.timeLabel}.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save schedule: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.initial == null ? 'New schedule' : 'Edit schedule',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Label',
                hintText: 'e.g. Morning 1% better',
                prefixIcon: Icon(Icons.label_outline),
                isDense: true,
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                onTap: _pickTime,
                leading: Icon(Icons.schedule, color: theme.colorScheme.primary),
                title: Text(
                  _time.format(context),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                subtitle: const Text('Tap to change time'),
                trailing: const Icon(Icons.edit_outlined),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Repeat',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            SegmentedButton<ScheduleRepeat>(
              segments: const [
                ButtonSegment(value: ScheduleRepeat.daily, label: Text('Daily')),
                ButtonSegment(value: ScheduleRepeat.weekly, label: Text('Weekly')),
                ButtonSegment(value: ScheduleRepeat.once, label: Text('Once')),
              ],
              selected: {_repeat},
              onSelectionChanged: (sel) => setState(() => _repeat = sel.first),
            ),
            if (_repeat == ScheduleRepeat.weekly) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  for (var i = 1; i <= 7; i++)
                    FilterChip(
                      label: Text(_dayNames[i - 1]),
                      selected: _days.contains(i),
                      onSelected: (sel) => setState(() {
                        if (sel) {
                          _days.add(i);
                        } else {
                          _days.remove(i);
                        }
                      }),
                    ),
                ],
              ),
            ],
            if (_repeat == ScheduleRepeat.once)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Card(
                  child: ListTile(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _onceDate ?? DateTime.now(),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 3650)),
                      );
                      if (picked != null) setState(() => _onceDate = picked);
                    },
                    leading: Icon(
                      Icons.event_outlined,
                      color: theme.colorScheme.primary,
                    ),
                    title: Text(
                      _onceDate == null
                          ? 'Pick a date'
                          : '${_onceDate!.day}/${_onceDate!.month}/${_onceDate!.year}',
                    ),
                    trailing: const Icon(Icons.edit_outlined),
                  ),
                ),
              ),
            const SizedBox(height: 16),
            Text(
              'How to notify',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            SegmentedButton<ScheduleType>(
              segments: const [
                ButtonSegment(
                  value: ScheduleType.reminder,
                  label: Text('Reminder'),
                  icon: Icon(Icons.notifications_outlined),
                ),
                ButtonSegment(
                  value: ScheduleType.alarm,
                  label: Text('Alarm'),
                  icon: Icon(Icons.alarm),
                ),
              ],
              selected: {_type},
              onSelectionChanged: (sel) => setState(() => _type = sel.first),
            ),
            const SizedBox(height: 12),
            Text(
              _type == ScheduleType.alarm
                  ? 'A loud full-screen alarm that appears over the lock screen '
                      'and rings until you dismiss it.'
                  : 'A quiet banner notification at the scheduled time.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check),
                label: const Text('Save schedule'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({this.onAdd});

  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.alarm_outlined,
              size: 64,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'No schedules yet',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create reminders or loud alarms to keep yourself on track with '
              'your 1% better.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            if (onAdd != null)
              FilledButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add_alarm_outlined),
                label: const Text('New schedule'),
              ),
          ],
        ),
      ),
    );
  }
}

class _UnsupportedBanner extends StatelessWidget {
  const _UnsupportedBanner();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          'Schedules are not supported on this device yet.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.error,
          ),
        ),
      ),
    );
  }
}

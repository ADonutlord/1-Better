import 'dart:async';

import 'package:flutter/material.dart';

import '../../services/study_lockdown_service.dart';
import '../../services/study_service.dart';

/// Study-session timer with optional phone lockdown.
///
/// When lockdown is enabled the device is pinned into this app (home/recents/
/// notification shade are blocked) so the student focuses. Incoming calls
/// still ring and can be answered; a "Make a call" button unpins temporarily
/// to open the dialer. Every finished session is recorded server-side and
/// feeds the weekly "hours studied" statistics.
class StudyTimerScreen extends StatefulWidget {
  const StudyTimerScreen({super.key});

  @override
  State<StudyTimerScreen> createState() => _StudyTimerScreenState();
}

class _StudyTimerScreenState extends State<StudyTimerScreen>
    with WidgetsBindingObserver {
  static const _durations = <(int, String)>[
    (15, '15 min'),
    (25, '25 min'),
    (45, '45 min'),
    (60, '60 min'),
    (90, '90 min'),
  ];

  final LockdownService _lockdown = LockdownService.instance;
  final StudyService _study = StudyService.instance;

  int _durationMinutes = 25;
  int _remaining = 25 * 60;
  DateTime? _startedWallClock;

  Timer? _timer;
  bool _running = false;
  bool _locked = false;
  bool _recording = false;
  bool _showCallHint = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _releaseLock();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      _releaseLock();
    }
  }

  Future<void> _releaseLock() async {
    if (_locked) {
      await _lockdown.unlock();
      _locked = false;
    }
  }

  Future<void> _toggleLock() async {
    if (_locked) {
      await _lockdown.unlock();
      setState(() => _locked = false);
      return;
    }
    final confirmed = await _confirmLock();
    if (!mounted || confirmed != true) return;
    final ok = await _lockdown.lock();
    if (!mounted) return;
    if (ok) {
      setState(() => _locked = true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'To lock your phone, enable "Screen pinning" in your device '
            'Settings → Security, then try again.',
          ),
        ),
      );
    }
  }

  /// Prompts the student before enabling lockdown, explaining what it does
  /// and how to escape it.
  Future<bool?> _confirmLock() {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        icon: const Icon(Icons.lock_outline, size: 32),
        title: const Text('Enable phone lockdown?'),
        content: const SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'This pins your device to this app while you study, so you '
                'won\'t be distracted by other apps, notifications, or the '
                'home screen.',
                style: TextStyle(height: 1.4),
              ),
              SizedBox(height: 12),
              Text('What it does',
                  style: TextStyle(fontWeight: FontWeight.w800)),
              SizedBox(height: 6),
              Text('• Blocks other apps while the timer runs\n'
                  '• Blocks the notification shade & home button\n'
                  '• Keeps your personal details hidden on the lock screen'),
              SizedBox(height: 12),
              Text('What still works',
                  style: TextStyle(fontWeight: FontWeight.w800)),
              SizedBox(height: 6),
              Text('• Incoming calls still ring and can be answered\n'
                  '• You can make a call from the timer screen'),
              SizedBox(height: 12),
              Text('How to end it early',
                  style: TextStyle(fontWeight: FontWeight.w800)),
              SizedBox(height: 6),
              Text('Hold Back + Overview together, then un-check "Pin".'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Not now'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Lock my phone'),
          ),
        ],
      ),
    );
  }

  Future<void> _makeCall() async {
    setState(() => _showCallHint = true);
    await _lockdown.openDialer();
    if (_locked) setState(() => _locked = false);
  }

  Future<void> _start() async {
    _beginCountdown();
  }

  void _beginCountdown() {
    _startedWallClock = DateTime.now();
    setState(() {
      _running = true;
      _showCallHint = false;
    });
    _lockdown.wakeScreen();
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_remaining <= 1) {
        _finish();
        return;
      }
      setState(() => _remaining -= 1);
    });
  }

  void _pause() {
    _timer?.cancel();
    setState(() => _running = false);
  }

  void _reset() {
    _timer?.cancel();
    setState(() {
      _remaining = _durationMinutes * 60;
      _running = false;
      _recording = false;
      _startedWallClock = null;
    });
  }

  void _chooseDuration(int minutes) {
    _timer?.cancel();
    setState(() {
      _durationMinutes = minutes;
      _remaining = minutes * 60;
      _running = false;
      _startedWallClock = null;
    });
  }

  Future<void> _finish() async {
    _timer?.cancel();
    final started = _startedWallClock;
    final ended = DateTime.now();
    setState(() {
      _running = false;
      _remaining = 0;
      _recording = true;
    });
    _releaseLock();

    var earnedXp = 0;
    if (started != null && _remaining == 0) {
      try {
        earnedXp = await _study.recordSession(startedAt: started, endedAt: ended);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not save session: $e')),
          );
        }
      }
    }

    if (!mounted) return;
    setState(() => _recording = false);
    await _showFinishDialog(xp: earnedXp);
    _reset();
  }

  Future<void> _showFinishDialog({required int xp}) async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('📚', style: TextStyle(fontSize: 44)),
            const SizedBox(height: 12),
            const Text('Study session complete!',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
            const SizedBox(height: 8),
            Text(
              xp > 0
                  ? 'Great focus. +$xp XP added, and it\'s on your weekly stats.'
                  : 'Great focus. It\'s been added to your weekly stats.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Nice'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final minutes = (_remaining ~/ 60).toString().padLeft(2, '0');
    final seconds = (_remaining % 60).toString().padLeft(2, '0');
    final progress = _running
        ? 1 - (_remaining / (_durationMinutes * 60))
        : 0.0;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('Study timer')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text('How long?',
                  style: theme.textTheme.labelLarge
                      ?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final (m, label) in _durations)
                    ChoiceChip(
                      label: Text(label),
                      selected: _durationMinutes == m && !_running,
                      onSelected: _running ? null : (_) => _chooseDuration(m),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    children: [
                      Text('STUDY',
                          style: theme.textTheme.labelLarge?.copyWith(
                              letterSpacing: 3, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 18),
                      Text('$minutes:$seconds',
                          style: theme.textTheme.displayMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              fontFeatures: const [FontFeature.tabularFigures()])),
                      const SizedBox(height: 18),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 10,
                          color: theme.colorScheme.primary,
                          backgroundColor:
                              theme.colorScheme.surfaceContainerHighest,
                        ),
                      ),
                      const SizedBox(height: 24),
                      if (_recording)
                        const Text('Saving session…')
                      else
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (_running)
                              FilledButton.icon(
                                onPressed: _pause,
                                icon: const Icon(Icons.pause),
                                label: const Text('Pause'),
                              )
                            else
                              FilledButton.icon(
                                onPressed: _remaining == 0 ? _reset : _start,
                                icon: Icon(
                                    _remaining == 0 ? Icons.refresh : Icons.play_arrow),
                                label: Text(_remaining == 0 ? 'Start again' : 'Start'),
                              ),
                            const SizedBox(width: 12),
                            OutlinedButton.icon(
                              onPressed: (_running || _recording)
                                  ? null
                                  : _reset,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Reset'),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                title: const Text('Lock down my phone',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(
                  _locked
                      ? 'Lockdown active — you can only answer calls.'
                      : 'Blocks other apps & notifications while you study. '
                          'Incoming calls still ring.',
                  style: theme.textTheme.bodySmall,
                ),
                value: _locked,
                onChanged: (_running || _recording)
                    ? null
                    : (_) => _toggleLock(),
              ),
              if (_locked && _running) ...[
                const SizedBox(height: 4),
                OutlinedButton.icon(
                  onPressed: _makeCall,
                  icon: const Icon(Icons.call_outlined),
                  label: const Text('Make a call'),
                ),
              ],
              if (_showCallHint)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    'The dialer opened. When you\'re done, tap the study timer '
                    'again and re-enable lockdown.\n\nTip: to end phone lockdown '
                    'early, hold Back + the Overview button, then un-check pin.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

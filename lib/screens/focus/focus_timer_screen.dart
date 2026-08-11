import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/app_state.dart';
import '../../services/xp_service.dart';

/// Simple 25-minute focus timer. Completion awards +15 XP once per day.
class FocusTimerScreen extends StatefulWidget {
  const FocusTimerScreen({super.key});

  @override
  State<FocusTimerScreen> createState() => _FocusTimerScreenState();
}

class _FocusTimerScreenState extends State<FocusTimerScreen> {
  static const _defaultSeconds = 25 * 60;

  int _remaining = _defaultSeconds;
  Timer? _timer;
  bool _running = false;
  bool _claimed = false;
  bool _awarding = false;

  @override
  void initState() {
    super.initState();
    _checkClaimed();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _checkClaimed() async {
    try {
      final claimed = await XpService.instance.hasFocusXpTodaay();
      if (mounted) setState(() => _claimed = claimed);
    } catch (_) {}
  }

  void _start() {
    setState(() => _running = true);
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
      _remaining = _defaultSeconds;
      _running = false;
    });
  }

  Future<void> _finish() async {
    _timer?.cancel();
    setState(() {
      _running = false;
      _remaining = _defaultSeconds;
    });
    if (!mounted) return;

    final award = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🎉', style: TextStyle(fontSize: 44)),
            const SizedBox(height: 12),
            const Text('Focus session complete!',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
            const SizedBox(height: 8),
            const Text('That\'s +15 XP for staying focused.'),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Claim XP'),
          ),
        ],
      ),
    );

    if (award == true && !_claimed) {
      setState(() => _awarding = true);
      try {
        await XpService.instance.awardFocusXp();
        await AppState.instance.loadDailyLoop();
        if (!mounted) return;
        setState(() {
          _claimed = true;
          _awarding = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('+15 XP earned 🌱')),
        );
      } catch (e) {
        if (!mounted) return;
        setState(() => _awarding = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final minutes = (_remaining ~/ 60).toString().padLeft(2, '0');
    final seconds = (_remaining % 60).toString().padLeft(2, '0');
    final progress = 1 - (_remaining / _defaultSeconds);

    return Scaffold(
      appBar: AppBar(title: const Text('Focus timer')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('FOCUS',
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
                        backgroundColor: theme.colorScheme.surfaceContainerHighest,
                      ),
                    ),
                    const SizedBox(height: 24),
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
                            onPressed: _start,
                            icon: const Icon(Icons.play_arrow),
                            label: const Text('Resume'),
                          ),
                        const SizedBox(width: 12),
                        OutlinedButton.icon(
                          onPressed: _reset,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Reset'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    if (_awarding)
                      const Text('Awarding XP…')
                    else if (_claimed)
                      Text('+15 XP already claimed today ✓',
                          style: theme.textTheme.bodySmall?.copyWith(
                              color: const Color(0xFF2E5C3A),
                              fontWeight: FontWeight.w700))
                    else
                      Text('Complete a session to earn +15 XP (once a day).',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

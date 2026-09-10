import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:one_percent_better/models/models.dart';
import 'package:one_percent_better/services/supabase_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Thin platform wrapper around Android's UsageStatsManager, which powers the
/// automatic screen-time measurement (per-app, per-day, including the home
/// screen/launcher counted as "Home screen").
///
/// PACKAGE_USAGE_STATS is a special permission: Android won't prompt for it, so
/// the user must toggle "Usage access" in system Settings. [hasUsageAccess]
/// detects it via AppOps and [openUsageSettings] deep-links there.
///
/// Measured days are persisted server-side through the `log_day_usage` RPC; the
/// StudiService reads them back for the charts. On non-Android platforms these
/// are all no-ops so the UI degrades gracefully.
class UsageStatsService {
  UsageStatsService._();

  static final UsageStatsService instance = UsageStatsService._();

  static const MethodChannel _channel =
      MethodChannel('one_percent_better/usage');

  SupabaseClient get _client => SupabaseService.instance.client;

  bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Whether the user has granted "Usage access" in system Settings.
  Future<bool> hasUsageAccess() async {
    if (!_isAndroid) return false;
    try {
      return await _channel.invokeMethod<bool>('hasUsageAccess') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  /// Opens the system "Usage access" settings screen.
  Future<void> openUsageSettings() async {
    if (!_isAndroid) return;
    try {
      await _channel.invokeMethod<void>('openUsageSettings');
    } on PlatformException {
      // Non-fatal — ignore.
    } on MissingPluginException {
      // ignore
    }
  }

  static const _askedKey = 'usage_access_asked_v1';

  /// Asks the user to grant "Usage access" on the first run of the app (not
  /// before, since Android can't show a system permission dialog for it). Safe
  /// to call anytime: it's a no-op off-Android, when access is already granted,
  /// or when the prompt was already shown once for this install.
  Future<void> requestUsageAccessIfFresh(BuildContext context) async {
    if (!_isAndroid) return;
    if (await hasUsageAccess()) return;

    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_askedKey) ?? false) return;
    await prefs.setBool(_askedKey, true);

    if (!context.mounted) return;
    final go = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => const _UsageAccessDialog(),
        ) ??
        false;
    if (go) await openUsageSettings();
  }

  /// Queries the device for [days] days of usage (oldest first), ending today.
  /// Returns an empty list when usage access isn't granted.
  Future<List<ScreenTimeDay>> fetchDeviceUsage({required int days}) async {
    if (!_isAndroid) return const [];
    final raw = await _channel
            .invokeMethod<List<dynamic>>('queryDays', {'days': days}) ??
        const <dynamic>[];
    return [
      for (final e in raw)
        if (e is Map)
          ScreenTimeDay.fromJson(Map<String, dynamic>.from(e)),
    ];
  }

  /// Measures screen time for the last [days] days and stores it server-side
  /// (day totals + per-app breakdown). Returns false when not on Android or
  /// usage access isn't granted; false also when any day failed to persist.
  Future<bool> syncToServer({int days = 7}) async {
    if (!_isAndroid || !await hasUsageAccess()) return false;
    List<ScreenTimeDay> entries;
    try {
      entries = await fetchDeviceUsage(days: days);
    } on PlatformException {
      return false;
    }
    if (entries.isEmpty) return true;

    var ok = true;
    for (final day in entries) {
      try {
        await _client.rpc('log_day_usage', params: {
          'p_day': _dateString(day.day),
          'p_total_minutes': day.totalMinutes,
          'p_apps': [
            for (final a in day.apps)
              {
                'package': a.package,
                'label': a.label,
                'minutes': a.minutes,
              },
          ],
        });
      } catch (_) {
        ok = false;
      }
    }
    return ok;
  }

  static String _dateString(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

/// First-run dialog explaining why the app needs "Usage access" and how to
/// grant it. Returns `true` when the user chooses to open Settings.
class _UsageAccessDialog extends StatelessWidget {
  const _UsageAccessDialog();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.bar_chart, color: scheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Track your screen time',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '1% Better uses a system tool to measure how much time you '
              'spend on your apps, so your Study screen can show an automatic '
              'screen-time breakdown — including your phone\'s home screen.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'To enable it: tap "Open Settings", then turn on "Usage access" '
              'for 1% Better.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Later'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Open Settings'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
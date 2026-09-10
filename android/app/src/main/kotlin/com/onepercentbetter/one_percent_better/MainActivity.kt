package com.onepercentbetter.one_percent_better

import android.app.AppOpsManager
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.os.Process
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.Calendar

class MainActivity : FlutterActivity() {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "dismissKeyguard" -> dismissKeyguard(result)
                    "startLock" -> startLock(result)
                    "stopLock" -> stopLock(result)
                    "openDialer" -> openDialer(result)
                    else -> result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, USAGE_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "hasUsageAccess" -> result.success(hasUsageAccess())
                    "openUsageSettings" -> openUsageSettings(result)
                    "queryDays" -> {
                        val days = (call.argument<Int>("days") ?: 7).coerceIn(1, 90)
                        queryDays(days, result)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    // ---------------------------------------------------------------------------
    // Usage-stats bridge: automatic per-app screen time via UsageStatsManager.
    // ---------------------------------------------------------------------------

    // PACKAGE_USAGE_STATS is a special permission: the user must grant "Usage
    // access" in Settings. We detect it through AppOps and deep-link the user
    // there when it's missing.
    private fun hasUsageAccess(): Boolean {
        return try {
            val appOps = getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
            val mode = appOps.checkOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS,
                Process.myUid(),
                packageName
            )
            mode == AppOpsManager.MODE_ALLOWED
        } catch (e: Exception) {
            false
        }
    }

    private fun openUsageSettings(result: MethodChannel.Result) {
        try {
            val intent = Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS)
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(intent)
            result.success(true)
        } catch (e: Exception) {
            result.error("USAGE_SETTINGS_FAILED", e.message, null)
        }
    }

    // For each of the last [days] local calendar days, aggregates how long each
    // app (and the launcher, shown as "Home screen") was in the foreground.
    // Returns [{day: "YYYY-MM-DD", totalMinutes: n, apps: [{package,label,minutes}]}],
    // oldest day first.
    private fun queryDays(days: Int, result: MethodChannel.Result) {
        try {
            if (!hasUsageAccess()) {
                result.success(emptyList<Map<String, Any?>>())
                return
            }
            val manager = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
            val launchers = launcherPackages()
            val out = ArrayList<Map<String, Any?>>()

            for (offset in days - 1 downTo 0) {
                val start = Calendar.getInstance().apply {
                    add(Calendar.DAY_OF_YEAR, -offset)
                    set(Calendar.HOUR_OF_DAY, 0)
                    set(Calendar.MINUTE, 0)
                    set(Calendar.SECOND, 0)
                    set(Calendar.MILLISECOND, 0)
                }
                val end = Calendar.getInstance().apply {
                    add(Calendar.DAY_OF_YEAR, -offset + 1)
                    set(Calendar.HOUR_OF_DAY, 0)
                    set(Calendar.MINUTE, 0)
                    set(Calendar.SECOND, 0)
                    set(Calendar.MILLISECOND, 0)
                }

                val stats = manager.queryUsageStats(
                    UsageStatsManager.INTERVAL_DAILY,
                    start.timeInMillis,
                    end.timeInMillis
                )
                val byPackage = HashMap<String, Long>()
                for (s in stats) {
                    if (s.totalTimeInMillis > 0L) {
                        byPackage[s.packageName] =
                            (byPackage[s.packageName] ?: 0L) + s.totalTimeInMillis
                    }
                }
                if (byPackage.isEmpty()) continue

                val apps = ArrayList<Map<String, Any?>>()
                var total = 0L
                for ((pkg, millis) in byPackage) {
                    val minutes = millis / 60_000L
                    if (minutes <= 0L) continue
                    total += minutes
                    val label = if (pkg in launchers) "Home screen" else appLabel(pkg)
                    apps.add(mapOf(
                        "package" to pkg,
                        "label" to label,
                        "minutes" to minutes
                    ))
                }
                if (apps.isEmpty()) continue

                apps.sortWith(compareByDescending<Map<String, Any?>> {
                    (it["minutes"] as Long)
                })
                out.add(mapOf(
                    "day" to dateString(start),
                    "totalMinutes" to total,
                    "apps" to apps
                ))
            }
            result.success(out)
        } catch (e: Exception) {
            result.error("USAGE_QUERY_FAILED", e.message, null)
        }
    }

    private fun launcherPackages(): Set<String> {
        try {
            val intent = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME)
            return packageManager.queryIntentActivities(intent, 0)
                .map { it.activityInfo.packageName }
                .toSet()
        } catch (e: Exception) {
            return emptySet()
        }
    }

    private fun appLabel(pkg: String): String {
        return try {
            val info = packageManager.getApplicationInfo(pkg, 0)
            packageManager.getApplicationLabel(info).toString()
        } catch (e: Exception) {
            pkg
        }
    }

    private fun dateString(cal: Calendar): String {
        val y = cal.get(Calendar.YEAR)
        val m = cal.get(Calendar.MONTH) + 1
        val d = cal.get(Calendar.DAY_OF_MONTH)
        return "%04d-%02d-%02d".format(y, m, d)
    }

    // ---------------------------------------------------------------------------
    // Screen-pinning bridge (unchanged).
    // ---------------------------------------------------------------------------

    // The user must have allowed the app in Settings -> Security -> Screen pinning.
    // System alerts that "Screen pinning isn't allowed" and falls back gracefully.
    private fun startLock(result: MethodChannel.Result) {
        try {
            startLockTask()
            result.success(true)
        } catch (e: Exception) {
            result.error("LOCK_FAILED", e.message, null)
        }
    }

    private fun stopLock(result: MethodChannel.Result) {
        try {
            stopLockTask()
            result.success(true)
        } catch (e: Exception) {
            result.error("UNLOCK_FAILED", e.message, null)
        }
    }

    // Wakes the screen (floating flag) so a notification isn't required to
    // re-show the timer; the screen must still be unlocked by the user.
    private fun dismissKeyguard(result: MethodChannel.Result) {
        try {
            window.addFlags(android.view.WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED)
            window.addFlags(android.view.WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON)
            result.success(true)
        } catch (e: Exception) {
            result.error("KEYGUARD_FAILED", e.message, null)
        }
    }

    // Unpin and open the system dialer so the user can make a call while the
    // study timer is active. On returning to the app, the user can re-lock.
    private fun openDialer(result: MethodChannel.Result) {
        try {
            stopLockTask()
            val intent = Intent(Intent.ACTION_DIAL)
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(intent)
            result.success(true)
        } catch (e: Exception) {
            result.error("DIALER_FAILED", e.message, null)
        }
    }

    companion object {
        private const val CHANNEL = "one_percent_better/lock"
        private const val USAGE_CHANNEL = "one_percent_better/usage"
    }
}

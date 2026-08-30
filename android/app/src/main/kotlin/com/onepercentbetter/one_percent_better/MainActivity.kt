package com.onepercentbetter.one_percent_better

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

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
    }

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
    }
}

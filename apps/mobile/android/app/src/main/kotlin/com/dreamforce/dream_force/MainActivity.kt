package com.dreamforce.dream_force

import android.content.Intent
import android.app.AppOpsManager
import android.app.usage.UsageStatsManager
import android.os.Process
import android.provider.Settings
import android.os.Build
import java.util.Calendar
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "dream_force/device_settings").setMethodCallHandler { call, result ->
            when (call.method) {
                "openUsageAccessSettings" -> { startActivity(Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS)); result.success(null) }
                "openNotificationSettings" -> { startActivity(Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).putExtra(Settings.EXTRA_APP_PACKAGE, packageName)); result.success(null) }
                "hasUsageAccess" -> result.success(hasUsageAccess())
                "getTodayScreenTime" -> result.success(todayScreenTime())
                else -> result.notImplemented()
            }
        }
    }

    private fun hasUsageAccess(): Boolean {
        val appOps = getSystemService(APP_OPS_SERVICE) as AppOpsManager
        val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            appOps.unsafeCheckOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS, Process.myUid(), packageName)
        } else {
            @Suppress("DEPRECATION")
            appOps.checkOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS, Process.myUid(), packageName)
        }
        return mode == AppOpsManager.MODE_ALLOWED
    }

    private fun todayScreenTime(): Map<String, Any> {
        val permitted = hasUsageAccess()
        if (!permitted) return mapOf("hasPermission" to false, "totalMillis" to 0L, "apps" to emptyList<Map<String, Any>>())

        val start = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, 0)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }.timeInMillis
        val end = System.currentTimeMillis()
        val manager = getSystemService(USAGE_STATS_SERVICE) as UsageStatsManager
        val usage = manager.queryUsageStats(UsageStatsManager.INTERVAL_DAILY, start, end)
            .orEmpty()
            .filter { it.totalTimeInForeground > 0 && it.packageName != packageName }
            .groupBy { it.packageName }
            .map { (name, rows) -> name to rows.sumOf { it.totalTimeInForeground } }
            .sortedByDescending { it.second }
        return mapOf(
            "hasPermission" to true,
            "totalMillis" to usage.sumOf { it.second },
            "apps" to usage.take(10).map { (name, duration) ->
                mapOf("packageName" to name, "durationMillis" to duration)
            },
        )
    }
}

package com.dreamforce.dream_force

import android.content.Intent
import android.content.pm.PackageManager
import androidx.core.content.ContextCompat
import android.app.AppOpsManager
import android.app.usage.UsageStatsManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.AdaptiveIconDrawable
import android.graphics.drawable.Drawable
import android.os.Process
import android.provider.Settings
import android.os.Build
import android.os.Handler
import android.os.Looper
import java.util.Calendar
import java.util.Date
import java.util.Locale
import java.util.TimeZone
import java.text.SimpleDateFormat
import java.io.ByteArrayOutputStream
import java.util.concurrent.Executors
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val appInfoExecutor = Executors.newFixedThreadPool(2)
    private val mainHandler = Handler(Looper.getMainLooper())
    private var notificationPermissionResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        SessionBridge.messenger = flutterEngine.dartExecutor.binaryMessenger
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SessionBridge.CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "hasNotificationPermission" -> result.success(SessionNotifications.canPost(this))
                "requestNotificationPermission" -> requestNotificationPermission(result)
                "update" -> {
                    updateSession(call.arguments)
                    result.success(null)
                }
                "hide" -> {
                    stopService(Intent(this, SessionForegroundService::class.java))
                    result.success(null)
                }
        "alert" -> {
                    val args = call.arguments as? Map<*, *>
                    SessionNotifications.alert(
                        this,
                        args?.get("title") as? String ?: "Session finished",
                        args?.get("body") as? String ?: "Your session is complete.",
                    )
                    result.success(null)
                }
                "schedulePlanReminders" -> {
                    PlanReminders.schedule(this, planReminders(call.arguments))
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "dream_force/device_settings").setMethodCallHandler { call, result ->
            when (call.method) {
                "openUsageAccessSettings" -> { startActivity(Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS)); result.success(null) }
                "openNotificationSettings" -> { startActivity(Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).putExtra(Settings.EXTRA_APP_PACKAGE, packageName)); result.success(null) }
                "hasUsageAccess" -> result.success(hasUsageAccess())
                "getDeviceTimezone" -> result.success(TimeZone.getDefault().id)
                "getScreenTime" -> result.success(screenTime(call.argument<String>("period") ?: "day"))
                "getAppInfo" -> {
                    val requestedPackage = call.argument<String>("packageName")
                    if (requestedPackage.isNullOrBlank()) {
                        result.error("INVALID_PACKAGE", "A package name is required.", null)
                    } else {
                        appInfoExecutor.execute {
                            val info = appInfo(requestedPackage)
                            mainHandler.post { result.success(info) }
                        }
                    }
                }
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

    private fun screenTime(period: String): Map<String, Any> {
        val permitted = hasUsageAccess()
        if (!permitted) return mapOf("hasPermission" to false, "totalMillis" to 0L, "apps" to emptyList<Map<String, Any>>())

        val calendar = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, 0)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }
        when (period) {
            "week" -> {
                calendar.firstDayOfWeek = Calendar.MONDAY
                val offset = (calendar.get(Calendar.DAY_OF_WEEK) - Calendar.MONDAY + 7) % 7
                calendar.add(Calendar.DAY_OF_YEAR, -offset)
            }
            "month" -> calendar.set(Calendar.DAY_OF_MONTH, 1)
            "year" -> calendar.set(Calendar.DAY_OF_YEAR, 1)
        }
        val start = calendar.timeInMillis
        val end = System.currentTimeMillis()
        val manager = getSystemService(USAGE_STATS_SERVICE) as UsageStatsManager
        val usageRows = manager.queryUsageStats(UsageStatsManager.INTERVAL_DAILY, start, end)
            .orEmpty()
            .filter { it.totalTimeInForeground > 0 }
        val appLabels = usageRows.map { it.packageName }.distinct().associateWith(::displayAppLabel)
        val dailyUsage = usageRows
            .groupBy { SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date(it.firstTimeStamp)) }
            .toSortedMap()
            .map { (localDate, dailyRows) ->
                val dailyApps = dailyRows.groupBy { it.packageName }
                    .map { (name, rows) ->
                        mapOf(
                            "packageName" to name,
                            "appLabel" to (appLabels[name] ?: name),
                            "usageSeconds" to (rows.sumOf { it.totalTimeInForeground } / 1000L).toInt(),
                        )
                    }
                mapOf("localDate" to localDate, "apps" to dailyApps)
            }
        val usage = usageRows
            .groupBy { it.packageName }
            .map { (name, rows) -> name to rows.sumOf { it.totalTimeInForeground } }
            .sortedByDescending { it.second }
        val topApps = usage.take(9).map { (name, duration) ->
            mapOf("packageName" to name, "appLabel" to (appLabels[name] ?: name), "durationMillis" to duration)
        }
        val otherDuration = usage.drop(9).sumOf { it.second }
        val apps = topApps + if (otherDuration > 0) {
            listOf(mapOf("packageName" to "other.apps", "appLabel" to "Other apps", "durationMillis" to otherDuration))
        } else {
            emptyList()
        }
        return mapOf(
            "hasPermission" to true,
            "timezoneId" to TimeZone.getDefault().id,
            "queriedAtMillis" to end,
            "totalMillis" to usage.sumOf { it.second },
            "apps" to apps,
            "dailyUsage" to dailyUsage,
        )
    }

    private fun displayAppLabel(packageName: String): String = try {
        @Suppress("DEPRECATION")
        val applicationInfo = packageManager.getApplicationInfo(packageName, 0)
        packageManager.getApplicationLabel(applicationInfo).toString().take(160)
    } catch (_: Exception) {
        packageName
    }

    private fun appInfo(packageName: String): Map<String, Any?> {
        val applicationInfo = try {
            @Suppress("DEPRECATION")
            packageManager.getApplicationInfo(packageName, 0)
        } catch (_: PackageManager.NameNotFoundException) {
            return mapOf("label" to packageName, "iconPng" to null)
        } catch (_: Exception) {
            return mapOf("label" to packageName, "iconPng" to null)
        }
        val label = try {
            packageManager.getApplicationLabel(applicationInfo).toString().take(160)
        } catch (_: Exception) {
            packageName
        }
        val iconPng = try {
            val drawable = packageManager.getApplicationIcon(applicationInfo)
            drawableToPng(drawable)
        } catch (_: Exception) {
            null
        }
        return mapOf("label" to label, "iconPng" to iconPng)
    }

    private fun drawableToPng(drawable: Drawable): ByteArray? {
        val size = 96
        val bitmap = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        val oldBounds = drawable.bounds
        try {
            // Drawing the complete drawable also renders AdaptiveIconDrawable safely.
            // Fixed bounds handle zero, negative, or unusually large intrinsic sizes.
            drawable.setBounds(0, 0, size, size)
            drawable.draw(canvas)
            val output = ByteArrayOutputStream()
            if (!bitmap.compress(Bitmap.CompressFormat.PNG, 100, output)) return null
            return output.toByteArray()
        } finally {
            drawable.bounds = oldBounds
            bitmap.recycle()
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != 4101) return
        val granted = grantResults.isNotEmpty() &&
            grantResults[0] == PackageManager.PERMISSION_GRANTED
        notificationPermissionResult?.success(granted)
        notificationPermissionResult = null
    }

    private fun requestNotificationPermission(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < 33 || SessionNotifications.canPost(this)) {
            result.success(true)
            return
        }
        notificationPermissionResult?.success(false)
        notificationPermissionResult = result
        requestPermissions(arrayOf(android.Manifest.permission.POST_NOTIFICATIONS), 4101)
    }

    private fun updateSession(arguments: Any?) {
        if (!SessionNotifications.canPost(this)) return
        val args = arguments as? Map<*, *>
        val intent = Intent(this, SessionForegroundService::class.java).apply {
            action = SessionForegroundService.ACTION_UPDATE
            putExtra(
                SessionForegroundService.EXTRA_TITLE,
                args?.get("title") as? String ?: "Focus session",
            )
            putExtra(
                SessionForegroundService.EXTRA_SUBTITLE,
                args?.get("subtitle") as? String ?: "Focus",
            )
            putExtra(SessionForegroundService.EXTRA_POSITION_MS, longArg(args?.get("positionMs")))
            putExtra(SessionForegroundService.EXTRA_DURATION_MS, longArg(args?.get("durationMs")))
            putExtra(SessionForegroundService.EXTRA_PLAYING, args?.get("playing") as? Boolean ?: true)
        }
        try {
            ContextCompat.startForegroundService(this, intent)
        } catch (_: Exception) {
            // Permission or background limits must leave the in-app timer running.
        }
    }

    private fun longArg(value: Any?): Long = when (value) {
        is Int -> value.toLong()
        is Long -> value
        is Double -> value.toLong()
        else -> 0L
    }

    private fun planReminders(arguments: Any?): List<PlanReminders.Reminder> {
        val raw = (arguments as? Map<*, *>)?.get("reminders") as? List<*> ?: return emptyList()
        return raw.mapNotNull { item ->
            val map = item as? Map<*, *> ?: return@mapNotNull null
            val id = map["id"] as? String ?: return@mapNotNull null
            if (id.isBlank()) return@mapNotNull null
            PlanReminders.Reminder(
                id = id,
                title = (map["title"] as? String ?: "Planned activity").take(80),
                atMillis = longArg(map["atMillis"]),
            )
        }
    }

    override fun onDestroy() {
        if (isFinishing) {
            SessionBridge.messenger = null
            stopService(Intent(this, SessionForegroundService::class.java))
        }
        appInfoExecutor.shutdownNow()
        super.onDestroy()
    }
}

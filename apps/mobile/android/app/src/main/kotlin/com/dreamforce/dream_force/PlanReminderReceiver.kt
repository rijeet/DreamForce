package com.dreamforce.dream_force

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import org.json.JSONArray
import org.json.JSONObject

object PlanReminders {
    private const val PREFS = "dream_force_plan_reminders"
    private const val KEY_IDS = "ids"
    private const val KEY_ITEMS = "items"
    const val ACTION_REMIND = "com.dreamforce.PLAN_REMINDER"

    data class Reminder(val id: String, val title: String, val atMillis: Long)

    fun schedule(context: Context, reminders: List<Reminder>) {
        val app = context.applicationContext
        val prefs = app.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val alarm = app.getSystemService(AlarmManager::class.java)
        val previous = prefs.getStringSet(KEY_IDS, emptySet()) ?: emptySet()
        for (id in previous) alarm.cancel(pending(app, id))

        val now = System.currentTimeMillis()
        val kept = mutableSetOf<String>()
        val stored = JSONArray()
        for (reminder in reminders) {
            if (reminder.atMillis <= now) continue
            val intent = pending(app, reminder.id, reminder)
            try {
                if (canExact(alarm)) {
                    alarm.setExactAndAllowWhileIdle(
                        AlarmManager.RTC_WAKEUP,
                        reminder.atMillis,
                        intent,
                    )
                } else {
                    alarm.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, reminder.atMillis, intent)
                }
            } catch (_: SecurityException) {
                alarm.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, reminder.atMillis, intent)
            }
            kept += reminder.id
            stored.put(
                JSONObject()
                    .put("id", reminder.id)
                    .put("title", reminder.title)
                    .put("atMillis", reminder.atMillis),
            )
        }
        prefs.edit().putStringSet(KEY_IDS, kept).putString(KEY_ITEMS, stored.toString()).apply()
    }

    fun restore(context: Context) {
        val raw = context.applicationContext
            .getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .getString(KEY_ITEMS, null) ?: return
        val array = JSONArray(raw)
        val reminders = buildList {
            for (index in 0 until array.length()) {
                val item = array.getJSONObject(index)
                add(
                    Reminder(
                        id = item.getString("id"),
                        title = item.optString("title", "Planned activity"),
                        atMillis = item.getLong("atMillis"),
                    ),
                )
            }
        }
        schedule(context, reminders)
    }

    private fun canExact(alarm: AlarmManager): Boolean {
        if (Build.VERSION.SDK_INT < 31) return true
        return alarm.canScheduleExactAlarms()
    }

    private fun pending(
        context: Context,
        id: String,
        reminder: Reminder? = null,
    ): PendingIntent {
        val intent = Intent(context, PlanReminderReceiver::class.java).apply {
            action = ACTION_REMIND
            data = Uri.parse("dreamforce://plan-reminder/$id")
            if (reminder != null) {
                putExtra("id", reminder.id)
                putExtra("title", reminder.title)
            }
        }
        return PendingIntent.getBroadcast(
            context,
            id.hashCode() and 0x7fffffff,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }
}

class PlanReminderReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED) {
            PlanReminders.restore(context)
            return
        }
        if (intent.action != PlanReminders.ACTION_REMIND) return
        val id = intent.getStringExtra("id") ?: return
        val title = intent.getStringExtra("title") ?: "Planned activity"
        SessionNotifications.planReminder(context, id, title)
    }
}

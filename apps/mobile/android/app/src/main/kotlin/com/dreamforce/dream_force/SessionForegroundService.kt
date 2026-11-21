package com.dreamforce.dream_force

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.media.RingtoneManager
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.support.v4.media.MediaMetadataCompat
import android.support.v4.media.session.MediaSessionCompat
import android.support.v4.media.session.PlaybackStateCompat
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import androidx.media.app.NotificationCompat.MediaStyle
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import kotlin.math.min

object SessionBridge {
    const val CHANNEL = "dream_force/session_media"

    var messenger: BinaryMessenger? = null

    fun emit(action: String) {
        val messenger = messenger ?: return
        Handler(Looper.getMainLooper()).post {
            MethodChannel(messenger, CHANNEL).invokeMethod("onTransport", action)
        }
    }
}

object SessionNotifications {
    const val PLAYBACK_CHANNEL = "session_playback"
    const val FINISHED_CHANNEL = "session_finished"
    const val PLAN_CHANNEL = "plan_reminders"
    const val PLAYBACK_ID = 41
    const val FINISHED_ID = 42

    fun canPost(context: Context): Boolean {
        if (Build.VERSION.SDK_INT < 33) return true
        return ContextCompat.checkSelfPermission(
            context,
            android.Manifest.permission.POST_NOTIFICATIONS,
        ) == android.content.pm.PackageManager.PERMISSION_GRANTED
    }

    fun ensureChannels(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = context.getSystemService(NotificationManager::class.java)
        val playback = NotificationChannel(
            PLAYBACK_CHANNEL,
            "Running session",
            NotificationManager.IMPORTANCE_LOW,
        ).apply {
            description = "Shows the current focus session with its remaining time."
            setSound(null, null)
            setShowBadge(false)
        }
        val finished = NotificationChannel(
            FINISHED_CHANNEL,
            "Session finished",
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = "Alerts when a focus or rest block finishes."
            setSound(null, null)
            enableVibration(true)
        }
        val planned = NotificationChannel(
            PLAN_CHANNEL,
            "Today’s plan",
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = "Alerts when a planned activity’s start time arrives."
            setSound(null, null)
            enableVibration(true)
        }
        manager.createNotificationChannel(playback)
        manager.createNotificationChannel(finished)
        manager.createNotificationChannel(planned)
    }

    fun playSound(context: Context) {
        val uri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION) ?: return
        val ringtone = RingtoneManager.getRingtone(context.applicationContext, uri) ?: return
        if (!ringtone.isPlaying) ringtone.play()
    }

    fun alert(context: Context, title: String, body: String) {
        ensureChannels(context)
        playSound(context)
        if (!canPost(context)) return
        val notification = NotificationCompat.Builder(context, FINISHED_CHANNEL)
            .setSmallIcon(R.drawable.ic_session_notification)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .setCategory(NotificationCompat.CATEGORY_STATUS)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
            .setVisibility(NotificationCompat.VISIBILITY_PRIVATE)
            .setPublicVersion(publicVersion(context, FINISHED_CHANNEL, "Session update", body))
            .setContentIntent(openApp(context, 3))
            .build()
        manager(context).notify(FINISHED_ID, notification)
    }

    fun planReminder(context: Context, occurrenceId: String, title: String) {
        ensureChannels(context)
        playSound(context)
        if (!canPost(context)) return
        val notification = NotificationCompat.Builder(context, PLAN_CHANNEL)
            .setSmallIcon(R.drawable.ic_session_notification)
            .setContentTitle(title)
            .setContentText("It's time for your planned session.")
            .setCategory(NotificationCompat.CATEGORY_REMINDER)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
            .setVisibility(NotificationCompat.VISIBILITY_PRIVATE)
            .setPublicVersion(
                publicVersion(
                    context,
                    PLAN_CHANNEL,
                    "Planned session",
                    "It's time for your planned session.",
                ),
            )
            .setContentIntent(openApp(context, 4))
            .build()
        manager(context).notify(planNotificationId(occurrenceId), notification)
    }

    fun planNotificationId(occurrenceId: String): Int =
        10_000 + (occurrenceId.hashCode() and 0x0FFF)

    fun manager(context: Context): NotificationManager =
        context.getSystemService(NotificationManager::class.java)

    fun openApp(context: Context, requestCode: Int): PendingIntent {
        val intent = Intent(context, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
        return PendingIntent.getActivity(
            context,
            requestCode,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun publicVersion(
        context: Context,
        channel: String,
        title: String,
        text: String,
    ): Notification = NotificationCompat.Builder(context, channel)
        .setSmallIcon(R.drawable.ic_session_notification)
        .setContentTitle(title)
        .setContentText(text)
        .build()
}

class SessionForegroundService : Service() {
    private var session: MediaSessionCompat? = null
    private var artwork: Bitmap? = null
    private var inForeground = false

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        SessionNotifications.ensureChannels(this)
        artwork = artwork()
        val mediaSession = MediaSessionCompat(this, "DreamForceSession")
        mediaSession.setCallback(object : MediaSessionCompat.Callback() {
            override fun onPlay() = SessionBridge.emit("resume")
            override fun onPause() = SessionBridge.emit("pause")
        })
        mediaSession.isActive = true
        session = mediaSession
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> {
                stopSession()
                return START_NOT_STICKY
            }
            ACTION_TRANSPORT -> {
                val action = intent.getStringExtra(EXTRA_TRANSPORT)
                if (action == "pause" || action == "resume") SessionBridge.emit(action)
            }
            else -> present(intent)
        }
        return START_STICKY
    }

    override fun onDestroy() {
        session?.isActive = false
        session?.release()
        session = null
        artwork?.recycle()
        artwork = null
        super.onDestroy()
    }

    private fun present(intent: Intent?) {
        val title = intent?.getStringExtra(EXTRA_TITLE)?.take(80) ?: "Focus session"
        val subtitle = intent?.getStringExtra(EXTRA_SUBTITLE)?.take(80) ?: "Focus"
        val durationMs = intent?.getLongExtra(EXTRA_DURATION_MS, 0L)?.coerceAtLeast(0L) ?: 0L
        val positionMs = intent?.getLongExtra(EXTRA_POSITION_MS, 0L)?.coerceIn(0L, durationMs) ?: 0L
        val playing = intent?.getBooleanExtra(EXTRA_PLAYING, true) ?: true
        val notification = notification(title, subtitle, durationMs, positionMs, playing)
        if (!inForeground) {
            if (Build.VERSION.SDK_INT >= 34) {
                startForeground(
                    SessionNotifications.PLAYBACK_ID,
                    notification,
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE,
                )
            } else {
                startForeground(SessionNotifications.PLAYBACK_ID, notification)
            }
            inForeground = true
        } else {
            SessionNotifications.manager(this).notify(SessionNotifications.PLAYBACK_ID, notification)
        }
    }

    private fun notification(
        title: String,
        subtitle: String,
        durationMs: Long,
        positionMs: Long,
        playing: Boolean,
    ): Notification {
        val state = if (playing) PlaybackStateCompat.STATE_PLAYING else PlaybackStateCompat.STATE_PAUSED
        val playback = PlaybackStateCompat.Builder()
            .setActions(
                PlaybackStateCompat.ACTION_PLAY or
                    PlaybackStateCompat.ACTION_PAUSE or
                    PlaybackStateCompat.ACTION_PLAY_PAUSE,
            )
            .setState(state, positionMs, if (playing) 1f else 0f)
            .build()
        session?.setPlaybackState(playback)
        val metadata = MediaMetadataCompat.Builder()
            .putString(MediaMetadataCompat.METADATA_KEY_TITLE, title)
            .putString(MediaMetadataCompat.METADATA_KEY_ARTIST, subtitle)
            .putString(MediaMetadataCompat.METADATA_KEY_ALBUM, "Dream Force")
            .putLong(MediaMetadataCompat.METADATA_KEY_DURATION, durationMs)
        artwork?.let { metadata.putBitmap(MediaMetadataCompat.METADATA_KEY_ALBUM_ART, it) }
        session?.setMetadata(metadata.build())
        val transport = if (playing) "pause" else "resume"
        val action = NotificationCompat.Action(
            if (playing) android.R.drawable.ic_media_pause else android.R.drawable.ic_media_play,
            if (playing) "Pause" else "Resume",
            transportIntent(transport),
        )
        val token = session?.sessionToken
        val style = MediaStyle().setShowActionsInCompactView(0)
        if (token != null) style.setMediaSession(token)
        return NotificationCompat.Builder(this, SessionNotifications.PLAYBACK_CHANNEL)
            .setSmallIcon(R.drawable.ic_session_notification)
            .setContentTitle(title)
            .setContentText(subtitle)
            .setLargeIcon(artwork)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setSilent(true)
            .setCategory(NotificationCompat.CATEGORY_TRANSPORT)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setContentIntent(SessionNotifications.openApp(this, 1))
            .addAction(action)
            .setStyle(style)
            .build()
    }

    private fun transportIntent(action: String): PendingIntent {
        val intent = Intent(this, SessionForegroundService::class.java).apply {
            this.action = ACTION_TRANSPORT
            putExtra(EXTRA_TRANSPORT, action)
        }
        val requestCode = if (action == "pause") 11 else 12
        return PendingIntent.getService(
            this,
            requestCode,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun stopSession() {
        if (inForeground) {
            stopForeground(STOP_FOREGROUND_REMOVE)
            inForeground = false
        }
        stopSelf()
    }

    private fun artwork(): Bitmap? {
        val decoded = BitmapFactory.decodeResource(resources, R.drawable.logo) ?: return null
        val side = min(decoded.width, decoded.height)
        if (side <= 0) return decoded
        val cropped = Bitmap.createBitmap(
            decoded,
            (decoded.width - side) / 2,
            (decoded.height - side) / 2,
            side,
            side,
        )
        val scaled = Bitmap.createScaledBitmap(cropped, 256, 256, true)
        if (cropped != decoded && cropped != scaled) cropped.recycle()
        if (decoded != scaled) decoded.recycle()
        return scaled
    }

    companion object {
        const val ACTION_UPDATE = "com.dreamforce.session.UPDATE"
        const val ACTION_STOP = "com.dreamforce.session.STOP"
        const val ACTION_TRANSPORT = "com.dreamforce.session.TRANSPORT"
        const val EXTRA_TITLE = "title"
        const val EXTRA_SUBTITLE = "subtitle"
        const val EXTRA_POSITION_MS = "positionMs"
        const val EXTRA_DURATION_MS = "durationMs"
        const val EXTRA_PLAYING = "playing"
        const val EXTRA_TRANSPORT = "transport"
    }
}

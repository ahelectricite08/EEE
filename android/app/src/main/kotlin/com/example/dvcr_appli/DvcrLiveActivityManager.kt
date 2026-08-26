package com.example.dvcr_appli

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.media.AudioManager
import android.media.ToneGenerator
import android.os.Build
import android.view.View
import android.widget.RemoteViews
import com.example.live_activities.LiveActivityManager
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.net.HttpURLConnection
import java.net.URL

class DvcrLiveActivityManager(context: Context) : LiveActivityManager(context) {
    private val appContext = context.applicationContext
    private val pendingIntent = PendingIntent.getActivity(
        appContext,
        8801,
        Intent(appContext, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_REORDER_TO_FRONT or Intent.FLAG_ACTIVITY_SINGLE_TOP
        },
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
    )

    private val remoteViews = RemoteViews(
        appContext.packageName,
        R.layout.live_activity,
    )

    private var cachedTeam1Bitmap: Bitmap? = null
    private var cachedTeam2Bitmap: Bitmap? = null
    private var lastTeam1Url: String? = null
    private var lastTeam2Url: String? = null
    private var lastPlayedSoundKey: String? = null

    fun ensureNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val channelId = LIVE_CHANNEL_ID
        val nm = appContext.getSystemService(NotificationManager::class.java) ?: return
        val existing = nm.getNotificationChannel(channelId)
        if (existing != null &&
            existing.importance < NotificationManager.IMPORTANCE_HIGH
        ) {
            nm.deleteNotificationChannel(channelId)
        }
        if (nm.getNotificationChannel(channelId) != null) return
        val channel = NotificationChannel(
            channelId,
            "DVCR · Score live",
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description =
                "Score, minute et dernier fait de jeu sur l’écran de verrouillage"
            lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            setShowBadge(false)
            enableVibration(false)
            setSound(null, null)
        }
        nm.createNotificationChannel(channel)
    }

    private suspend fun loadImageBitmap(imageUrl: String?): Bitmap? {
        val dp = appContext.resources.displayMetrics.density.toInt()
        return withContext(Dispatchers.IO) {
            if (imageUrl.isNullOrBlank()) return@withContext null
            try {
                val connection = URL(imageUrl).openConnection() as HttpURLConnection
                connection.doInput = true
                connection.connectTimeout = 6000
                connection.readTimeout = 6000
                connection.setRequestProperty(
                    "User-Agent",
                    "DVCR-Android-LiveActivity/1.0",
                )
                connection.connect()
                connection.inputStream.use { inputStream ->
                    val original = BitmapFactory.decodeStream(inputStream)
                        ?: return@withContext null
                    val targetSize = (52 * dp).coerceAtLeast(64)
                    val aspect = original.width.toFloat() / original.height.toFloat()
                    val (w, h) = if (aspect > 1f) {
                        targetSize to (targetSize / aspect).toInt()
                    } else {
                        (targetSize * aspect).toInt() to targetSize
                    }
                    Bitmap.createScaledBitmap(
                        original,
                        w.coerceAtLeast(1),
                        h.coerceAtLeast(1),
                        true,
                    )
                }
            } catch (_: Exception) {
                null
            }
        }
    }

    private fun teamInitials(name: String): String {
        val parts = name.trim().split(Regex("\\s+")).filter { it.isNotEmpty() }
        return when {
            parts.size >= 2 ->
                "${parts[0].first()}${parts[1].first()}".uppercase()
            name.isNotEmpty() -> name.take(2).uppercase()
            else -> "—"
        }
    }

    private fun maybePlayEventSound(data: Map<String, Any>, event: String) {
        val key = (data["liveEventSoundKey"] as? String)?.trim().orEmpty()
        if (key.isEmpty()) return
        if (event != "update") {
            lastPlayedSoundKey = key
            return
        }
        if (key == lastPlayedSoundKey) return
        lastPlayedSoundKey = key

        val type = (data["lastEventType"] as? String).orEmpty()
        val tone = when (type) {
            "goal", "own_goal" -> ToneGenerator.TONE_CDMA_ALERT_CALL_GUARD
            "red" -> ToneGenerator.TONE_CDMA_ALERT_NETWORK_LITE
            "yellow" -> ToneGenerator.TONE_PROP_BEEP2
            "substitution" -> ToneGenerator.TONE_PROP_PROMPT
            "goal_cancelled", "goal_disallowed", "offside" -> ToneGenerator.TONE_PROP_ACK
            else -> return
        }

        try {
            val generator = ToneGenerator(AudioManager.STREAM_NOTIFICATION, 88)
            generator.startTone(tone, 240)
            generator.release()
        } catch (_: Exception) {
        }
    }

    private fun applyTeamSide(
        imageViewId: Int,
        monogramViewId: Int,
        abbrevViewId: Int,
        scoreViewId: Int,
        name: String,
        score: Int,
        bitmap: Bitmap?,
    ) {
        val label = name.ifBlank { "—" }
        // Abréviation : 2 premières lettres majuscules ou initiales
        val abbrev = teamInitials(label).take(3)
        remoteViews.setTextViewText(abbrevViewId, abbrev)
        remoteViews.setTextViewText(scoreViewId, score.toString())

        if (bitmap != null) {
            remoteViews.setImageViewBitmap(imageViewId, bitmap)
            remoteViews.setViewVisibility(imageViewId, View.VISIBLE)
            remoteViews.setViewVisibility(monogramViewId, View.GONE)
        } else {
            remoteViews.setViewVisibility(imageViewId, View.GONE)
            remoteViews.setViewVisibility(monogramViewId, View.VISIBLE)
            remoteViews.setTextViewText(monogramViewId, teamInitials(label))
        }
    }

    private suspend fun updateRemoteViews(
        matchLabel: String,
        team1Name: String,
        team1Score: Int,
        team2Name: String,
        team2Score: Int,
        minuteLabel: String,
        lastEventLine: String,
        team1ImageUrl: String?,
        team2ImageUrl: String?,
    ) {
        if (!team1ImageUrl.isNullOrBlank()) {
            if (team1ImageUrl != lastTeam1Url) {
                cachedTeam1Bitmap = null
                lastTeam1Url = team1ImageUrl
            }
            cachedTeam1Bitmap = loadImageBitmap(team1ImageUrl) ?: cachedTeam1Bitmap
        }
        if (!team2ImageUrl.isNullOrBlank()) {
            if (team2ImageUrl != lastTeam2Url) {
                cachedTeam2Bitmap = null
                lastTeam2Url = team2ImageUrl
            }
            cachedTeam2Bitmap = loadImageBitmap(team2ImageUrl) ?: cachedTeam2Bitmap
        }

        remoteViews.setTextViewText(R.id.match_status, minuteLabel)

        applyTeamSide(
            R.id.team1_image,
            R.id.team1_monogram,
            R.id.team1_abbrev,
            R.id.team1_score,
            team1Name,
            team1Score,
            cachedTeam1Bitmap,
        )
        applyTeamSide(
            R.id.team2_image,
            R.id.team2_monogram,
            R.id.team2_abbrev,
            R.id.team2_score,
            team2Name,
            team2Score,
            cachedTeam2Bitmap,
        )

        // Barre événement : toujours visible, texte vide si pas d'event
        val compactEvent = compactEventLine(lastEventLine)
        if (compactEvent.isNotBlank()) {
            remoteViews.setViewVisibility(R.id.event_separator, View.VISIBLE)
            remoteViews.setViewVisibility(R.id.event_bar, View.VISIBLE)
            remoteViews.setTextViewText(R.id.last_event, compactEvent)
        } else {
            remoteViews.setViewVisibility(R.id.event_separator, View.GONE)
            remoteViews.setViewVisibility(R.id.event_bar, View.GONE)
        }
    }

    private fun compactEventLine(raw: String): String {
        val line = raw.trim()
        if (line.isEmpty()) return ""
        return if (line.length <= 34) line else "${line.take(32)}…"
    }

    @Suppress("UNCHECKED_CAST")
    override suspend fun buildNotification(
        notification: Notification.Builder,
        event: String,
        data: Map<String, Any>,
    ): Notification {
        val matchLabel = (data["matchName"] as? String).orEmpty()
            .ifEmpty { "Drapeau Vert Carton Rouge" }
        val team1Name = (data["teamAName"] as? String).orEmpty().ifEmpty { "—" }
        val team2Name = (data["teamBName"] as? String).orEmpty().ifEmpty { "—" }
        val team1Score = (data["teamAScore"] as? Number)?.toInt() ?: 0
        val team2Score = (data["teamBScore"] as? Number)?.toInt() ?: 0
        val minuteLabel = ((data["matchMinute"] as? String)
            ?: (data["teamAState"] as? String).orEmpty()).trim()
        val lastEventLine = (data["lastEventLine"] as? String)
            ?: (data["lastGoalLine"] as? String).orEmpty()

        val team1ImageUrl = data["teamAImageUrl"] as? String
        val team2ImageUrl = data["teamBImageUrl"] as? String

        updateRemoteViews(
            matchLabel,
            team1Name,
            team1Score,
            team2Name,
            team2Score,
            minuteLabel,
            lastEventLine,
            team1ImageUrl,
            team2ImageUrl,
        )

        maybePlayEventSound(data, event)

        val lockTitle = "${teamInitials(team1Name)} $team1Score – $team2Score ${teamInitials(team2Name)}"
        val lockText = buildString {
            append("$minuteLabel · $team1Name – $team2Name")
            if (lastEventLine.isNotBlank()) {
                append('\n')
                append(lastEventLine)
            }
        }

        notification
            .setSmallIcon(R.drawable.ic_launcher_foreground)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setShowWhen(false)
            .setContentTitle(lockTitle)
            .setContentText(lockText)
            .setContentIntent(pendingIntent)
            .setCustomContentView(remoteViews)
            .setCustomBigContentView(remoteViews)
            .setPriority(Notification.PRIORITY_MAX)
            .setCategory(Notification.CATEGORY_STATUS)
            .setVisibility(Notification.VISIBILITY_PUBLIC)
            .setColor(0xFF0A4438.toInt())

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val publicBuilder = Notification.Builder(appContext, LIVE_CHANNEL_ID)
                .setSmallIcon(R.drawable.ic_launcher_foreground)
                .setContentTitle(lockTitle)
                .setContentText(lockText)
                .setVisibility(Notification.VISIBILITY_PUBLIC)
                .setShowWhen(false)
                .setOngoing(true)
            notification.setPublicVersion(publicBuilder.build())
        }

        return notification.build()
    }

    companion object {
        const val LIVE_CHANNEL_ID = "Live Activities"
    }
}

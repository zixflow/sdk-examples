package com.zixflow.demo

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage
import com.zixflow.messagingpush.ZixflowFirebaseMessagingService
import com.zixflow.sdk.Zixflow
import com.zixflow.sdk.events.Metric
import com.zixflow.sdk.events.TrackMetric
import java.net.URL

/**
 * Dual-path FCM handling:
 *
 * 1. First tries the SDK's own [ZixflowFirebaseMessagingService.onMessageReceived]
 *    static helper, exactly what the SDK's own manifest-declared service would have
 *    done. If the SDK recognizes and fully handles the push (displays the
 *    notification + tracks delivered), we stop there.
 * 2. If the SDK does NOT recognize the push (returns false) — which happens for
 *    every real dashboard push today because the SDK's internal validator checks
 *    for `ZIXFLOW-Delivery-ID` / `ZIXFLOW-Delivery-Token` (all-caps) while the
 *    dashboard actually sends `Zixflow-Delivery-ID` / `Zixflow-Delivery-Token`
 *    (see BUG-A12 in extra-docs/ANDROID_SDK_BUGS.md) — we fall back to handling
 *    the push ourselves: parse the payload, display a rich notification with
 *    action buttons, and track the delivered metric via the SDK's public
 *    `trackMetric` API. This mirrors the workaround already used in the
 *    Flutter/React Native sample apps.
 *
 * This is registered as the app's *only* FirebaseMessagingService — the SDK's own
 * service is removed from the merged manifest (see AndroidManifest.xml) since
 * Android only routes messages to one declared service per app.
 */
class CustomFirebaseMessagingService : FirebaseMessagingService() {

    companion object {
        private const val TAG = "CustomFCMService"
        private const val CHANNEL_ID = "zixflow_default"
        private const val CHANNEL_NAME = "Zixflow Notifications"
        // Selected when data["priority"] == "normal" — lower importance, no heads-up banner,
        // making FCM's high/normal priority distinction (otherwise only a delivery-timing
        // hint) observable in the custom-handled path.
        private const val CHANNEL_ID_NORMAL = "zixflow_normal"
        private const val CHANNEL_NAME_NORMAL = "Zixflow Notifications (normal priority)"
        const val EXTRA_DEEPLINK = "deeplink_url"
        const val EXTRA_CLICK_ACTION = "click_action"

        private const val PREFS_NAME = "zixflow_demo_prefs"
        private const val KEY_LAST_REGISTERED_DEVICE_TOKEN = "last_registered_device_token"

        /**
         * App-level guard: only call registerDeviceToken() when the token has
         * actually changed since the last time we registered it. onNewToken()
         * (and other places apps typically call registerDeviceToken from, e.g.
         * on every app launch) can otherwise fire repeatedly with the exact same
         * token, spamming a "Device Created or Updated" event each time for no
         * reason. Persisted in SharedPreferences (not just an in-memory field)
         * so the check survives the process being killed while backgrounded.
         */
        private fun hasDeviceTokenChanged(context: Context, token: String): Boolean {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val lastToken = prefs.getString(KEY_LAST_REGISTERED_DEVICE_TOKEN, null)
            if (lastToken == token) return false
            prefs.edit().putString(KEY_LAST_REGISTERED_DEVICE_TOKEN, token).apply()
            return true
        }
    }

    override fun onNewToken(token: String) {
        super.onNewToken(token)

        if (!hasDeviceTokenChanged(applicationContext, token)) {
            Log.d(TAG, "Device token unchanged since last registration, skipping duplicate registerDeviceToken call")
            return
        }

        // Try the SDK's own token handling first (unaffected by the push-casing bug).
        try {
            ZixflowFirebaseMessagingService.onNewToken(applicationContext, token)
        } catch (e: Exception) {
            Log.w(TAG, "SDK onNewToken failed, registering manually: ${e.message}")
        }
        // Guaranteed fallback — idempotent if the SDK already registered it.
        try {
            Zixflow.instance().registerDeviceToken(token)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to register device token", e)
        }
    }

    override fun onMessageReceived(remoteMessage: RemoteMessage) {
        super.onMessageReceived(remoteMessage)
        logIncomingPush(remoteMessage)

        if (!PushSettings.isCustomHandlingEnabled(applicationContext)) {
            Log.i(TAG, "Custom handling OFF — Firebase handles this push entirely, app code does nothing")
            return
        }

        val sdkHandled = try {
            ZixflowFirebaseMessagingService.onMessageReceived(
                applicationContext,
                remoteMessage,
                true
            )
        } catch (e: Exception) {
            Log.w(TAG, "SDK onMessageReceived threw, falling back: ${e.message}")
            false
        }

        if (sdkHandled) {
            Log.i(TAG, "Push handled natively by the Zixflow SDK")
            return
        }

        Log.i(TAG, "SDK did not recognize this push (see BUG-A12) — handling manually")
        Thread { handlePushManually(remoteMessage) }.start()
    }

    private fun handlePushManually(remoteMessage: RemoteMessage) {
        val data = remoteMessage.data
        val title = remoteMessage.notification?.title ?: data["title"]
        val body = remoteMessage.notification?.body ?: data["body"]

        // Correct casing first (matches actual dashboard payload); all-caps kept as
        // a defensive fallback in case a future payload variant uses it.
        val deliveryId = data["Zixflow-Delivery-ID"] ?: data["ZIXFLOW-Delivery-ID"] ?: ""
        val deliveryToken = data["Zixflow-Delivery-Token"]
            ?: data["ZIXFLOW-Delivery-Token"]
            ?: Zixflow.instance().registeredDeviceToken
            ?: ""

        if (deliveryId.isNotEmpty() && deliveryToken.isNotEmpty()) {
            try {
                PushTrackLogger.logOutgoingTrack(
                    "DELIVERED",
                    "CustomFirebaseMessagingService.handlePushManually",
                    mapOf(
                        "Zixflow-Delivery-ID" to deliveryId,
                        "Zixflow-Delivery-Token" to deliveryToken,
                        "metric" to Metric.Delivered
                    )
                )
                Zixflow.instance().trackMetric(
                    TrackMetric.Push(
                        metric = Metric.Delivered,
                        deliveryId = deliveryId,
                        deviceToken = deliveryToken
                    )
                )
                Log.i(TAG, "Tracked delivered metric for delivery $deliveryId")
            } catch (e: Exception) {
                Log.e(TAG, "Failed to track delivered metric", e)
            }
        } else {
            PushTrackLogger.logSkipped(
                "DELIVERED",
                "CustomFirebaseMessagingService.handlePushManually",
                "missing Zixflow-Delivery-ID/Token in payload"
            )
        }

        // Test Case 12 (android-fcm-push-test-cases-v2.md) / silent data sync pushes:
        // no `notification` block and no title/body anywhere in `data` means this push
        // carries no displayable content at all. "Handled by ourselves, no custom UI" —
        // we still process the data (delivery tracking above already ran) but must NOT
        // fabricate a visible notification for it.
        if (title == null && body == null) {
            Log.i(TAG, "Silent/data-only push (no notification content) — processing data, showing no UI")
            return
        }

        showNotification(title ?: "Notification", body ?: "", data, deliveryId, deliveryToken)
    }

    private fun showNotification(
        title: String,
        body: String,
        data: Map<String, String>,
        deliveryId: String,
        deliveryToken: String
    ) {
        ensureNotificationChannels()

        val imageBitmap = downloadBitmap(data["image_url"])
        val largeIconBitmap = downloadBitmap(data["large_icon_url"])
        val badgeCount = data["badge"]?.toIntOrNull()
        val soundName = data["sound"]
        // "sticky": true means the notification survives swipe-dismiss and "Clear all", but
        // STILL gets removed when tapped or when an action button is pressed — sticky only
        // blocks passive dismissal, not active interaction. setAutoCancel is therefore always
        // true; setOngoing is what's actually driven by `sticky`.
        val sticky = data["sticky"]?.toBooleanStrictOrNull() ?: false
        // Notification ID is generated once here so it can be reused both for `.notify()` and
        // for the action buttons' PendingIntents — required so NotificationActionReceiver can
        // explicitly cancel this exact notification when an action button is pressed (Android
        // does NOT auto-dismiss for action buttons routed through a BroadcastReceiver, unlike
        // a tap on the notification body which goes through an Activity PendingIntent).
        val notificationId = System.currentTimeMillis().toInt()

        // Custom `data.priority` (distinct from FCM's own android.priority header, which the
        // app never observes directly) picks the channel — this is what makes priority visibly
        // different in the custom-handled path (normal = no heads-up banner).
        val priority = data["priority"]
        val channelId = if (priority == "normal") CHANNEL_ID_NORMAL else CHANNEL_ID

        val builder = NotificationCompat.Builder(this, channelId)
            .setContentTitle(title)
            .setContentText(body)
            .setSmallIcon(R.drawable.ic_notification)
            .setColor(getColor(R.color.notification_accent))
            .setAutoCancel(true)
            .setOngoing(sticky)
            .setPriority(
                if (priority == "normal") NotificationCompat.PRIORITY_DEFAULT else NotificationCompat.PRIORITY_HIGH
            )

        if (largeIconBitmap != null) builder.setLargeIcon(largeIconBitmap)
        if (imageBitmap != null) {
            builder.setStyle(
                NotificationCompat.BigPictureStyle()
                    .bigPicture(imageBitmap)
                    .bigLargeIcon(null as Bitmap?)
                    .setBigContentTitle(title)
                    .setSummaryText(body)
            )
        }
        if (badgeCount != null) builder.setNumber(badgeCount)
        if (!soundName.isNullOrEmpty() && soundName != "default" && soundName != "none") {
            val soundUri = android.net.Uri.parse(
                "android.resource://$packageName/raw/$soundName"
            )
            builder.setSound(soundUri)
        }

        val deeplink = data["deeplink_url"]
        val clickAction = data["click_action"]
        builder.setContentIntent(buildContentPendingIntent(deliveryId, deliveryToken, deeplink, clickAction))

        PushActionButtons.attachFromRawData(
            deliveryId = deliveryId,
            deliveryToken = deliveryToken,
            actionButtonsJson = data["action_buttons"],
            notificationId = notificationId,
            builder = builder,
            context = this
        )

        NotificationManagerCompat.from(this).notify(notificationId, builder.build())

        // ttl_seconds — our own demo interpretation of "how long this notification stays
        // visible", distinct from FCM's actual server-side delivery-queue TTL (which the app
        // never observes directly). Not part of the official Zixflow payload schema — opt-in
        // via `data.ttl_seconds` for testing.
        val ttlSeconds = data["ttl_seconds"]?.toIntOrNull()
        if (ttlSeconds != null && ttlSeconds > 0) {
            Handler(Looper.getMainLooper()).postDelayed({
                NotificationManagerCompat.from(this).cancel(notificationId)
                Log.i(TAG, "Notification $notificationId auto-cancelled after ttl_seconds=$ttlSeconds")
            }, ttlSeconds * 1000L)
        }

        val analyticsLabel = data["analytics_label"]
        if (priority != null || analyticsLabel != null) {
            Log.i(TAG, "Diagnostics — priority: ${priority ?: "(unset)"}, analytics_label: ${analyticsLabel ?: "(unset)"}")
        }
    }

    /** Opens [MainActivity], which tracks the Opened metric and resolves click_action/deeplink on launch. */
    private fun buildContentPendingIntent(
        deliveryId: String,
        deliveryToken: String,
        deeplink: String?,
        clickAction: String? = null
    ): PendingIntent {
        val intent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra(PushActionButtons.EXTRA_DELIVERY_ID, deliveryId)
            putExtra(PushActionButtons.EXTRA_DELIVERY_TOKEN, deliveryToken)
            putExtra(EXTRA_DEEPLINK, deeplink)
            putExtra(EXTRA_CLICK_ACTION, clickAction)
        }
        return PendingIntent.getActivity(
            this,
            0,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    private fun ensureNotificationChannels() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val manager = getSystemService(NotificationManager::class.java)
            if (manager.getNotificationChannel(CHANNEL_ID) == null) {
                manager.createNotificationChannel(
                    NotificationChannel(
                        CHANNEL_ID,
                        CHANNEL_NAME,
                        NotificationManager.IMPORTANCE_HIGH
                    ).apply { description = "Zixflow push notifications" }
                )
            }
            if (manager.getNotificationChannel(CHANNEL_ID_NORMAL) == null) {
                manager.createNotificationChannel(
                    NotificationChannel(
                        CHANNEL_ID_NORMAL,
                        CHANNEL_NAME_NORMAL,
                        NotificationManager.IMPORTANCE_DEFAULT
                    ).apply { description = "Zixflow push notifications (data.priority = normal)" }
                )
            }
        }
    }

    private fun downloadBitmap(url: String?): Bitmap? {
        if (url.isNullOrEmpty() || !url.startsWith("http")) return null
        return try {
            URL(url).openStream().use { BitmapFactory.decodeStream(it) }
        } catch (e: Exception) {
            Log.w(TAG, "Failed to download $url: ${e.message}")
            null
        }
    }

    private fun logIncomingPush(remoteMessage: RemoteMessage) {
        Log.i(TAG, "PUSH RECEIVED messageId=${remoteMessage.messageId}")
        Log.i(TAG, "  title=${remoteMessage.notification?.title}")
        Log.i(TAG, "  body=${remoteMessage.notification?.body}")
        Log.i(TAG, "  data=${remoteMessage.data}")
    }
}

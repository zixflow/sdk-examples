package com.zixflow.demo

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.os.Build
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
        const val EXTRA_DEEPLINK = "deeplink_url"
    }

    override fun onNewToken(token: String) {
        super.onNewToken(token)
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
        val title = remoteMessage.notification?.title ?: data["title"] ?: "Notification"
        val body = remoteMessage.notification?.body ?: data["body"] ?: ""

        // Correct casing first (matches actual dashboard payload); all-caps kept as
        // a defensive fallback in case a future payload variant uses it.
        val deliveryId = data["Zixflow-Delivery-ID"] ?: data["ZIXFLOW-Delivery-ID"] ?: ""
        val deliveryToken = data["Zixflow-Delivery-Token"]
            ?: data["ZIXFLOW-Delivery-Token"]
            ?: Zixflow.instance().registeredDeviceToken
            ?: ""

        if (deliveryId.isNotEmpty() && deliveryToken.isNotEmpty()) {
            try {
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
        }

        showNotification(title, body, data, deliveryId, deliveryToken)
    }

    private fun showNotification(
        title: String,
        body: String,
        data: Map<String, String>,
        deliveryId: String,
        deliveryToken: String
    ) {
        ensureNotificationChannel()

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

        val builder = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle(title)
            .setContentText(body)
            .setSmallIcon(R.drawable.ic_launcher_foreground)
            .setAutoCancel(true)
            .setOngoing(sticky)
            .setPriority(NotificationCompat.PRIORITY_HIGH)

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
        builder.setContentIntent(buildContentPendingIntent(deliveryId, deliveryToken, deeplink))

        PushActionButtons.attachFromRawData(
            deliveryId = deliveryId,
            deliveryToken = deliveryToken,
            actionButtonsJson = data["action_buttons"],
            notificationId = notificationId,
            builder = builder,
            context = this
        )

        NotificationManagerCompat.from(this).notify(notificationId, builder.build())
    }

    /** Opens [MainActivity], which tracks the Opened metric and the deeplink on launch. */
    private fun buildContentPendingIntent(
        deliveryId: String,
        deliveryToken: String,
        deeplink: String?
    ): PendingIntent {
        val intent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra(PushActionButtons.EXTRA_DELIVERY_ID, deliveryId)
            putExtra(PushActionButtons.EXTRA_DELIVERY_TOKEN, deliveryToken)
            putExtra(EXTRA_DEEPLINK, deeplink)
        }
        return PendingIntent.getActivity(
            this,
            0,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    private fun ensureNotificationChannel() {
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

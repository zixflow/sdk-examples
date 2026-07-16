package com.zixflow.demo

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.util.Log
import androidx.core.app.NotificationManagerCompat
import com.zixflow.sdk.Zixflow
import com.zixflow.sdk.events.Metric
import com.zixflow.sdk.events.TrackMetric

/**
 * Handles push notification action-button taps: tracks Opened, then
 * "Push Notification Action Clicked", dismisses the notification, and opens
 * the button deeplink if set.
 */
class NotificationActionReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != PushActionButtons.ACTION_CLICK) return

        val deliveryId = intent.getStringExtra(PushActionButtons.EXTRA_DELIVERY_ID) ?: ""
        val deliveryToken = intent.getStringExtra(PushActionButtons.EXTRA_DELIVERY_TOKEN)
            ?.takeIf { it.isNotEmpty() }
            ?: Zixflow.instance().registeredDeviceToken
            ?: ""
        val actionIndex = intent.getIntExtra(PushActionButtons.EXTRA_ACTION_INDEX, -1)
        val actionName = intent.getStringExtra(PushActionButtons.EXTRA_ACTION_NAME)
            ?: "Action ${actionIndex + 1}"
        val actionDeeplink = intent.getStringExtra(PushActionButtons.EXTRA_ACTION_DEEPLINK) ?: ""

        try {
            // Always fire opened first
            Zixflow.instance().trackMetric(
                TrackMetric.Push(
                    metric = Metric.Opened,
                    deliveryId = deliveryId,
                    deviceToken = deliveryToken
                )
            )

            Zixflow.instance().track(
                name = "Push Notification Action Clicked",
                properties = mapOf(
                    "Zixflow-Delivery-ID" to deliveryId,
                    "Zixflow-Delivery-Token" to deliveryToken,
                    "action_index" to actionIndex,
                    "action_name" to actionName,
                    "action_deeplink" to actionDeeplink
                )
            )
        } catch (e: Exception) {
            Log.e(TAG, "Failed to track push action click", e)
        }

        // Action buttons are routed through this BroadcastReceiver, so Android's
        // `setAutoCancel(true)` (which only fires for Activity-based content-intent taps)
        // does NOT dismiss the notification here — it must be cancelled explicitly. This
        // applies regardless of `sticky`: pressing an action button always removes the
        // notification; only swipe/"Clear all" is blocked when the push was marked sticky.
        val notificationId = intent.getIntExtra(PushActionButtons.EXTRA_NOTIFICATION_ID, -1)
        if (notificationId != -1) {
            NotificationManagerCompat.from(context).cancel(notificationId)
        }

        if (actionDeeplink.isNotEmpty()) {
            val viewIntent = Intent(Intent.ACTION_VIEW, Uri.parse(actionDeeplink)).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            context.startActivity(viewIntent)
        }
    }

    companion object {
        private const val TAG = "NotificationActionReceiver"
    }
}

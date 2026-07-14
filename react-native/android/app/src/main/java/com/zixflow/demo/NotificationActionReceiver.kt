package com.zixflow.demo

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.util.Log
import com.zixflow.sdk.Zixflow
import com.zixflow.sdk.events.Metric
import com.zixflow.sdk.events.TrackMetric

/**
 * Handles push notification action-button taps: tracks Opened, then
 * "Push Notification Action Clicked", and opens the button deeplink if set.
 *
 * Register in AndroidManifest.xml (exported=false), for example:
 *
 * ```xml
 * <receiver
 *     android:name=".NotificationActionReceiver"
 *     android:exported="false">
 *     <intent-filter>
 *         <action android:name="com.zixflow.demo.PUSH_NOTIFICATION_ACTION" />
 *     </intent-filter>
 * </receiver>
 * ```
 *
 * Pair with [PushActionButtons] and
 * `MessagingPushModuleConfig.setNotificationCallback`. The RN package does not
 * pass `notificationCallback` from JS today — see `sdk-examples/android/`.
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

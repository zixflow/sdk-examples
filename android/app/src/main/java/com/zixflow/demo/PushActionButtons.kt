package com.zixflow.demo

import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import androidx.core.app.NotificationCompat
import com.zixflow.messagingpush.data.model.ZixflowParsedPushPayload
import org.json.JSONArray

data class ActionButton(
    val name: String,
    val deeplink: String
)

/**
 * Parses Zixflow `action_buttons` from push extras and attaches up to two
 * [NotificationCompat] actions that route taps to [NotificationActionReceiver].
 */
object PushActionButtons {
    const val ACTION_CLICK = "com.zixflow.demo.PUSH_NOTIFICATION_ACTION"

    const val EXTRA_DELIVERY_ID = "Zixflow-Delivery-ID"
    const val EXTRA_DELIVERY_TOKEN = "Zixflow-Delivery-Token"
    const val EXTRA_ACTION_INDEX = "action_index"
    const val EXTRA_ACTION_NAME = "action_name"
    const val EXTRA_ACTION_DEEPLINK = "action_deeplink"
    const val EXTRA_NOTIFICATION_ID = "notification_id"

    /** Bundle key the SDK stores its own generated notification ID under (see
     * `ZixflowPushNotificationHandler.NOTIFICATION_REQUEST_CODE`) — duplicated here as a
     * plain string since that class is internal to the messagingpush module. */
    private const val SDK_NOTIFICATION_REQUEST_CODE_KEY = "requestCode"

    private const val MAX_ACTIONS = 2

    fun parseActionButtons(buttonsJson: String?): List<ActionButton> {
        if (buttonsJson.isNullOrEmpty()) return emptyList()

        return try {
            val jsonArray = JSONArray(buttonsJson)
            val count = minOf(jsonArray.length(), MAX_ACTIONS)
            List(count) { index ->
                val button = jsonArray.getJSONObject(index)
                ActionButton(
                    name = button.getString("name"),
                    deeplink = button.optString("deeplink", "")
                )
            }
        } catch (_: Exception) {
            emptyList()
        }
    }

    fun attach(
        payload: ZixflowParsedPushPayload,
        builder: NotificationCompat.Builder,
        context: Context
    ) {
        attachFromRawData(
            deliveryId = payload.zixflowDeliveryId,
            deliveryToken = payload.zixflowDeliveryToken,
            actionButtonsJson = payload.extras.getString("action_buttons"),
            notificationId = payload.extras.getInt(SDK_NOTIFICATION_REQUEST_CODE_KEY, 0),
            builder = builder,
            context = context
        )
    }

    /**
     * Same as [attach] but for pushes handled manually (not via the SDK's
     * [ZixflowParsedPushPayload]) — e.g. the fallback path in
     * [CustomFirebaseMessagingService] for pushes the SDK's own delivery-ID/token
     * casing check fails to recognize (see BUG-A12).
     *
     * [notificationId] must be the *same* ID passed to `NotificationManagerCompat.notify()`
     * for this notification — [NotificationActionReceiver] needs it to explicitly cancel the
     * notification when an action button is pressed (Android does not auto-dismiss for
     * actions routed through a `BroadcastReceiver`, unlike a body tap which goes through an
     * `Activity` `PendingIntent` and is auto-cancelled by `setAutoCancel(true)`).
     */
    fun attachFromRawData(
        deliveryId: String?,
        deliveryToken: String?,
        actionButtonsJson: String?,
        notificationId: Int,
        builder: NotificationCompat.Builder,
        context: Context
    ) {
        val buttons = parseActionButtons(actionButtonsJson)
        if (buttons.isEmpty()) return

        val flags = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE

        buttons.forEachIndexed { index, button ->
            val intent = Intent(context, NotificationActionReceiver::class.java).apply {
                action = ACTION_CLICK
                putExtra(EXTRA_DELIVERY_ID, deliveryId)
                putExtra(EXTRA_DELIVERY_TOKEN, deliveryToken)
                putExtra(EXTRA_ACTION_INDEX, index)
                putExtra(EXTRA_ACTION_NAME, button.name)
                putExtra(EXTRA_ACTION_DEEPLINK, button.deeplink)
                putExtra(EXTRA_NOTIFICATION_ID, notificationId)
            }

            val pendingIntent = PendingIntent.getBroadcast(
                context,
                index,
                intent,
                flags
            )

            builder.addAction(
                /* icon = */ 0,
                button.name,
                pendingIntent
            )
        }
    }
}

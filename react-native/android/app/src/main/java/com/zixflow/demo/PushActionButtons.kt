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
 *
 * ## React Native gap
 *
 * The `zixflow-reactnative` Android bridge currently only configures
 * `pushClickBehavior` — it does **not** call
 * `MessagingPushModuleConfig.setNotificationCallback`. To show action buttons
 * on Android you must wire this helper from native Kotlin, for example:
 *
 * ```kotlin
 * MessagingPushModuleConfig.Builder()
 *     .setNotificationCallback(object : ZixflowPushNotificationCallback {
 *         override fun onNotificationComposed(
 *             payload: ZixflowParsedPushPayload,
 *             builder: NotificationCompat.Builder
 *         ) {
 *             PushActionButtons.attach(payload, builder, applicationContext)
 *         }
 *     })
 *     .setAutoTrackPushEvents(true)
 *     .build()
 * ```
 *
 * See the working end-to-end app under `sdk-examples/android/`
 * (`MainApplication.kt`, `PushActionButtons.kt`, `NotificationActionReceiver.kt`).
 */
object PushActionButtons {
    const val ACTION_CLICK = "com.zixflow.demo.PUSH_NOTIFICATION_ACTION"

    const val EXTRA_DELIVERY_ID = "Zixflow-Delivery-ID"
    const val EXTRA_DELIVERY_TOKEN = "Zixflow-Delivery-Token"
    const val EXTRA_ACTION_INDEX = "action_index"
    const val EXTRA_ACTION_NAME = "action_name"
    const val EXTRA_ACTION_DEEPLINK = "action_deeplink"

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
        val buttons = parseActionButtons(payload.extras.getString("action_buttons"))
        if (buttons.isEmpty()) return

        val flags = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE

        buttons.forEachIndexed { index, button ->
            val intent = Intent(context, NotificationActionReceiver::class.java).apply {
                action = ACTION_CLICK
                putExtra(EXTRA_DELIVERY_ID, payload.zixflowDeliveryId)
                putExtra(EXTRA_DELIVERY_TOKEN, payload.zixflowDeliveryToken)
                putExtra(EXTRA_ACTION_INDEX, index)
                putExtra(EXTRA_ACTION_NAME, button.name)
                putExtra(EXTRA_ACTION_DEEPLINK, button.deeplink)
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

package com.zixflow.demo

import android.app.Application
import android.util.Log
import androidx.core.app.NotificationCompat
import com.zixflow.messagingpush.MessagingPushModuleConfig
import com.zixflow.messagingpush.ModuleMessagingPushFCM
import com.zixflow.messagingpush.config.PushClickBehavior
import com.zixflow.messagingpush.data.communication.ZixflowPushNotificationCallback
import com.zixflow.messagingpush.data.model.ZixflowParsedPushPayload
import com.zixflow.sdk.Zixflow
import com.zixflow.sdk.core.di.SDKComponent

/**
 * Registers [ModuleMessagingPushFCM] with [PushActionButtons] after the RN JS
 * layer calls [Zixflow.initialize].
 *
 * The RN package does not pass `notificationCallback` from JS. This demo
 * replaces the push module entry in [SDKComponent.modules] so
 * [ZixflowPushNotificationCallback.onNotificationComposed] can attach actions.
 * Key `"MessagingPushFCM"` matches [ModuleMessagingPushFCM]'s module name.
 */
object PushActionButtonsInstaller {
  private const val TAG = "PushActionButtonsInstaller"
  private const val MESSAGING_PUSH_MODULE_NAME = "MessagingPushFCM"

  @Volatile
  private var installed = false

  /**
   * @return true if the callback module is installed (or was already installed)
   */
  fun installIfReady(application: Application): Boolean {
    if (installed) return true

    return try {
      // Throws when JS has not finished Zixflow.initialize yet.
      Zixflow.instance()

      val pushConfig =
        MessagingPushModuleConfig.Builder()
          .setPushClickBehavior(PushClickBehavior.ACTIVITY_PREVENT_RESTART)
          .setAutoTrackPushEvents(true)
          .setNotificationCallback(
            object : ZixflowPushNotificationCallback {
              override fun onNotificationComposed(
                payload: ZixflowParsedPushPayload,
                builder: NotificationCompat.Builder,
              ) {
                PushActionButtons.attach(payload, builder, application)
              }
            },
          )
          .build()

      val module = ModuleMessagingPushFCM(pushConfig)
      SDKComponent.modules[MESSAGING_PUSH_MODULE_NAME] = module
      runCatching { module.initialize() }

      installed = true
      Log.i(TAG, "Push action buttons installed via onNotificationComposed")
      true
    } catch (e: Exception) {
      Log.d(TAG, "SDK not ready yet; will retry: ${e.message}")
      false
    }
  }
}

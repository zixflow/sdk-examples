package com.zixflow.demo

import android.app.Application
import androidx.core.app.NotificationCompat
import com.zixflow.location.ModuleLocation
import com.zixflow.messagingpush.MessagingPushModuleConfig
import com.zixflow.messagingpush.ModuleMessagingPushFCM
import com.zixflow.messagingpush.data.communication.ZixflowPushNotificationCallback
import com.zixflow.messagingpush.data.model.ZixflowParsedPushPayload
import com.zixflow.sdk.Zixflow
import com.zixflow.sdk.ZixflowConfigBuilder
import com.zixflow.sdk.core.util.ZixflowLogLevel

class MainApplication : Application() {
    override fun onCreate() {
        super.onCreate()

        val builder = ZixflowConfigBuilder(
            applicationContext = this,
            apiKey = Config.apiKey
        )
            .autoTrackDeviceAttributes(true)
            .autoTrackActivityScreens(true)
            .trackApplicationLifecycleEvents(true)
            .logLevel(ZixflowLogLevel.DEBUG)

        if (Config.enableOptionalModules) {
            val pushConfig = MessagingPushModuleConfig.Builder()
                .setNotificationCallback(object : ZixflowPushNotificationCallback {
                    override fun onNotificationComposed(
                        payload: ZixflowParsedPushPayload,
                        builder: NotificationCompat.Builder
                    ) {
                        PushActionButtons.attach(payload, builder, this@MainApplication)
                    }
                })
                .setAutoTrackPushEvents(true)
                .build()

            builder
                .addZixflowModule(ModuleMessagingPushFCM(pushConfig))
                .addZixflowModule(ModuleLocation())
        }

        Zixflow.initialize(builder.build())
    }
}

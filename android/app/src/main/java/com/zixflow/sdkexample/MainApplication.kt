package com.zixflow.sdkexample

import android.app.Application
import com.zixflow.location.ModuleLocation
import com.zixflow.messagingpush.ModuleMessagingPushFCM
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
            builder
                .addZixflowModule(ModuleMessagingPushFCM())
                .addZixflowModule(ModuleLocation())
        }

        Zixflow.initialize(builder.build())
    }
}

import UIKit
import ZixflowDataPipelines
import ZixflowMessagingPushAPN
import ZixflowMessagingInApp
import ZixflowLocation

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        let config: SDKConfigBuilderResult

        if Config.enableOptionalModules {
            config = SDKConfigBuilder(apiKey: Config.apiKey)
                .autoTrackDeviceAttributes(true)
                .trackApplicationLifecycleEvents(true)
                .logLevel(.debug)
                .addModule(
                    LocationModule(
                        config: LocationConfig(mode: .onAppStart)
                    )
                )
                .build()
        } else {
            config = SDKConfigBuilder(apiKey: Config.apiKey)
                .autoTrackDeviceAttributes(true)
                .trackApplicationLifecycleEvents(true)
                .logLevel(.debug)
                .build()
        }

        Zixflow.initialize(withConfig: config)

        if Config.enableOptionalModules {
            MessagingPushAPN.initialize(
                withConfig: MessagingPushConfigBuilder()
                    .autoFetchDeviceToken(true)
                    .autoTrackPushEvents(true)
                    .showPushAppInForeground(true)
                    .build()
            )

            MessagingInApp.initialize(
                withConfig: MessagingInAppConfigBuilder().build()
            )
        }

        return true
    }
}

import UIKit
import UserNotifications
import ZixflowDataPipelines
import ZixflowMessagingPushAPN
import ZixflowLocation

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
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

            registerPushActionCategories()
            UNUserNotificationCenter.current().delegate = self
        }

        return true
    }

    // MARK: - Push action buttons (ZX_2BTN)

    private func registerPushActionCategories() {
        let actions = [
            UNNotificationAction(identifier: "ACTION_0", title: "Action 1", options: .foreground),
            UNNotificationAction(identifier: "ACTION_1", title: "Action 2", options: .foreground),
        ]
        let category = UNNotificationCategory(
            identifier: "ZX_2BTN",
            actions: actions,
            intentIdentifiers: [],
            options: []
        )
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let actionId = response.actionIdentifier
        guard actionId == "ACTION_0" || actionId == "ACTION_1" else {
            completionHandler()
            return
        }

        let userInfo = response.notification.request.content.userInfo
        let deliveryId = deliveryValue(from: userInfo, keys: ["ZIXFLOW-Delivery-ID", "Zixflow-Delivery-ID"])
        let deliveryToken = deliveryValue(from: userInfo, keys: ["ZIXFLOW-Delivery-Token", "Zixflow-Delivery-Token"])

        // Body taps are auto-tracked when autoTrackPushEvents(true). Action-button taps are not
        // (SDK only treats UNNotificationDefaultActionIdentifier as an open).
        if !deliveryId.isEmpty && !deliveryToken.isEmpty {
            MessagingPush.shared.trackMetric(
                deliveryID: deliveryId,
                event: .opened,
                deviceToken: deliveryToken
            )
        }

        let actionIndex = Int(actionId.replacingOccurrences(of: "ACTION_", with: "")) ?? -1
        let buttons = parseActionButtons(userInfo["action_buttons"])
        let actionName: String
        let deeplink: String
        if actionIndex >= 0 && actionIndex < buttons.count {
            actionName = buttons[actionIndex]["name"] as? String ?? "Action \(actionIndex + 1)"
            deeplink = buttons[actionIndex]["deeplink"] as? String ?? ""
        } else {
            actionName = "Action \(max(actionIndex, 0) + 1)"
            deeplink = ""
        }

        Zixflow.shared.track(
            name: "Push Notification Action Clicked",
            properties: [
                "Zixflow-Delivery-ID": deliveryId,
                "Zixflow-Delivery-Token": deliveryToken,
                "action_index": actionIndex,
                "action_name": actionName,
                "action_deeplink": deeplink,
            ]
        )

        if !deeplink.isEmpty, let url = URL(string: deeplink) {
            UIApplication.shared.open(url)
        }

        completionHandler()
    }

    private func deliveryValue(from userInfo: [AnyHashable: Any], keys: [String]) -> String {
        for key in keys {
            if let value = userInfo[key] as? String, !value.isEmpty {
                return value
            }
        }
        return ""
    }

    private func parseActionButtons(_ raw: Any?) -> [[String: Any]] {
        guard let jsonString = raw as? String,
              let data = jsonString.data(using: .utf8),
              let buttons = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]
        else {
            return []
        }
        return buttons
    }
}

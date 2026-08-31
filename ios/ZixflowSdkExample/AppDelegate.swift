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
                    .autoFetchDeviceToken(false)
                    .autoTrackPushEvents(true)
                    .showPushAppInForeground(true)
                    .build()
            )

            registerPushActionCategories()
            UNUserNotificationCenter.current().delegate = self
            // Manually trigger APN registration since autoFetchDeviceToken is
            // disabled above -- didRegisterForRemoteNotificationsWithDeviceToken
            // below is where we apply the app-level "only register if changed" guard.
            application.registerForRemoteNotifications()
        }

        return true
    }

    // MARK: - Device token registration (app-level guard)

    private static let lastRegisteredDeviceTokenKey = "zixflow_demo_last_registered_device_token"

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        let tokenString = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()

        // App-level guard: only call registerDeviceToken() when the token has
        // actually changed since the last time we registered it. iOS commonly
        // calls this delegate method again on every app launch even when the
        // token hasn't changed, which would otherwise spam a "Device Created or
        // Updated" event each time for no reason. Persisted in UserDefaults (not
        // just an in-memory field) so the check survives the app process being
        // killed while backgrounded.
        let defaults = UserDefaults.standard
        if defaults.string(forKey: Self.lastRegisteredDeviceTokenKey) == tokenString {
            print("[ZixflowDemo] Device token unchanged since last registration, skipping duplicate registerDeviceToken call")
            return
        }

        MessagingPushAPN.shared.registerDeviceToken(apnDeviceToken: deviceToken)
        defaults.set(tokenString, forKey: Self.lastRegisteredDeviceTokenKey)
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("[ZixflowDemo] Failed to register for remote notifications: \(error.localizedDescription)")
    }

    // MARK: - Silent / background push (Case 8 & 18: content-available, no aps.alert)

    /// Called for pure data/"content-available" pushes when the app is backgrounded or
    /// killed — NOT for alert pushes (those go through `willPresent`/the system tray
    /// instead). This is "handled by ourselves, no custom UI": we process `data`/
    /// `userInfo` and track Delivered, but deliberately show nothing — there is no
    /// `aps.alert` to present. Requires `UIBackgroundModes: remote-notification` in
    /// Info.plist (added) or this method is never invoked.
    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        guard PushSettings.isCustomHandlingEnabled else {
            print("[PushHandlers] Custom handling OFF — APNs handles this push entirely, app code does nothing")
            completionHandler(.noData)
            return
        }

        print("[PushHandlers] Silent/background push received (no UI) — userInfo: \(userInfo)")

        let deliveryId = deliveryValue(from: userInfo, keys: ["Zixflow-Delivery-ID", "ZIXFLOW-Delivery-ID"])
        let deliveryToken = deliveryValue(from: userInfo, keys: ["Zixflow-Delivery-Token", "ZIXFLOW-Delivery-Token"])

        if !deliveryId.isEmpty && !deliveryToken.isEmpty {
            logOutgoingTrack(
                kind: "DELIVERED",
                source: "application(_:didReceiveRemoteNotification:fetchCompletionHandler:) (silent push)",
                payload: [
                    "Zixflow-Delivery-ID": deliveryId,
                    "Zixflow-Delivery-Token": deliveryToken,
                    "event": "delivered",
                ]
            )
            MessagingPush.shared.trackMetric(
                deliveryID: deliveryId,
                event: .delivered,
                deviceToken: deliveryToken
            )
        } else {
            print("[PushHandlers] Skipped DELIVERED tracking (silent push): missing Zixflow-Delivery-ID/Token in payload")
        }

        // Real app-specific background work (data sync, etc.) would go here.
        completionHandler(.newData)
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
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        guard PushSettings.isCustomHandlingEnabled else {
            print("[PushHandlers] Custom handling OFF — APNs handles this push entirely, app code does nothing")
            completionHandler([])
            return
        }

        let userInfo = notification.request.content.userInfo
        let deliveryId = deliveryValue(from: userInfo, keys: ["Zixflow-Delivery-ID", "ZIXFLOW-Delivery-ID"])
        let deliveryToken = deliveryValue(from: userInfo, keys: ["Zixflow-Delivery-Token", "ZIXFLOW-Delivery-Token"])

        // Explicit "Delivered" tracking mirrors the Android/Flutter/RN sample apps'
        // trackDelivered() calls, fired the moment the push arrives while the app is in the
        // foreground. autoTrackPushEvents(true) should also track this internally, but being
        // explicit here keeps behavior verifiable/consistent across all 4 platforms.
        if !deliveryId.isEmpty && !deliveryToken.isEmpty {
            logOutgoingTrack(
                kind: "DELIVERED",
                source: "userNotificationCenter(willPresent:) (foreground)",
                payload: [
                    "Zixflow-Delivery-ID": deliveryId,
                    "Zixflow-Delivery-Token": deliveryToken,
                    "event": "delivered",
                ]
            )
            MessagingPush.shared.trackMetric(
                deliveryID: deliveryId,
                event: .delivered,
                deviceToken: deliveryToken
            )
        } else {
            print("[PushHandlers] Skipped DELIVERED tracking: missing Zixflow-Delivery-ID/Token in payload")
        }

        // Diagnostics only — on iOS, the real `apns-priority` header and Firebase's
        // `fcm_options.analytics_label` are server-side/APNs-level concerns with no
        // client-visible equivalent. These are our own custom `data.*`-style fields
        // (if Zixflow chooses to send them) for demo parity with Android/Flutter/RN.
        let priority = userInfo["priority"] as? String
        let analyticsLabel = userInfo["analytics_label"] as? String
        if priority != nil || analyticsLabel != nil {
            print("[PushHandlers] Diagnostics — priority: \(priority ?? "(unset)"), analytics_label: \(analyticsLabel ?? "(unset)")")
        }

        completionHandler([.banner, .sound, .badge, .list])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        let actionId = response.actionIdentifier

        guard actionId == "ACTION_0" || actionId == "ACTION_1" else {
            // Default tap (notification body) or dismiss action.
            if actionId == UNNotificationDefaultActionIdentifier {
                // NOTE: this used to rely solely on the SDK's autoTrackPushEvents(true) to
                // auto-track "Opened" for body taps. That auto-tracking is implemented via
                // swizzling `UNUserNotificationCenter.current().delegate` (see
                // AutomaticPushClickHandling.swift) and is NOT guaranteed to fire once this
                // AppDelegate sets itself as the delegate (`UNUserNotificationCenter.current().delegate
                // = self` in didFinishLaunching) — that mechanism is also marked deprecated in the
                // SDK. Track explicitly here instead, exactly like the action-button branch below,
                // so body-tap click tracking doesn't silently depend on undocumented SDK internals.
                let deliveryId = deliveryValue(from: userInfo, keys: ["Zixflow-Delivery-ID", "ZIXFLOW-Delivery-ID"])
                let deliveryToken = deliveryValue(from: userInfo, keys: ["Zixflow-Delivery-Token", "ZIXFLOW-Delivery-Token"])

                print("[PushHandlers] Notification BODY tapped")
                if !deliveryId.isEmpty && !deliveryToken.isEmpty {
                    logOutgoingTrack(
                        kind: "OPENED",
                        source: "userNotificationCenter(didReceive:) body tap",
                        payload: [
                            "Zixflow-Delivery-ID": deliveryId,
                            "Zixflow-Delivery-Token": deliveryToken,
                            "event": "opened",
                        ]
                    )
                    MessagingPush.shared.trackMetric(
                        deliveryID: deliveryId,
                        event: .opened,
                        deviceToken: deliveryToken
                    )
                } else {
                    print("[PushHandlers] Skipped OPENED tracking (body tap): missing Zixflow-Delivery-ID/Token in payload")
                }

                let deeplink = userInfo["deeplink_url"] as? String ?? ""
                let clickAction = userInfo["click_action"] as? String
                // click_action takes priority over deeplink_url — mirrors the historical
                // Android "which screen" signal, resolved to our own routes for parity
                // across all 4 sample apps (iOS has no native client-visible click_action).
                if !NavigationRouter.shared.openClickAction(clickAction),
                   !NavigationRouter.shared.open(deeplink: deeplink),
                   !deeplink.isEmpty, let url = URL(string: deeplink) {
                    UIApplication.shared.open(url)
                }
            }
            completionHandler()
            return
        }

        let deliveryId = deliveryValue(from: userInfo, keys: ["Zixflow-Delivery-ID", "ZIXFLOW-Delivery-ID"])
        let deliveryToken = deliveryValue(from: userInfo, keys: ["Zixflow-Delivery-Token", "ZIXFLOW-Delivery-Token"])

        // Action-button taps: explicit "Opened" tracking, same reasoning as the body-tap
        // branch above — do not rely on autoTrackPushEvents for this either.
        if !deliveryId.isEmpty && !deliveryToken.isEmpty {
            logOutgoingTrack(
                kind: "OPENED",
                source: "userNotificationCenter(didReceive:) action button (\(actionId))",
                payload: [
                    "Zixflow-Delivery-ID": deliveryId,
                    "Zixflow-Delivery-Token": deliveryToken,
                    "event": "opened",
                ]
            )
            MessagingPush.shared.trackMetric(
                deliveryID: deliveryId,
                event: .opened,
                deviceToken: deliveryToken
            )
        } else {
            print("[PushHandlers] Skipped OPENED tracking (action button): missing Zixflow-Delivery-ID/Token in payload")
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

        let clickProperties: [String: Any] = [
            "Zixflow-Delivery-ID": deliveryId,
            "Zixflow-Delivery-Token": deliveryToken,
            "action_index": actionIndex,
            "action_name": actionName,
            "action_deeplink": deeplink,
        ]
        logOutgoingTrack(
            kind: "CLICKED (action button)",
            source: "userNotificationCenter(didReceive:) action button (\(actionId))",
            payload: ["event": "Push Notification Action Clicked", "properties": clickProperties]
        )
        Zixflow.shared.track(
            name: "Push Notification Action Clicked",
            properties: clickProperties
        )

        // Route in-app for zixflowdemo://sale|dashboard, external otherwise — same as the
        // body-tap path above and matching DeeplinkRouter.kt / navigation.ts / navigation.dart.
        if !NavigationRouter.shared.open(deeplink: deeplink),
           !deeplink.isEmpty, let url = URL(string: deeplink) {
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

    /// Logs the exact outgoing payload being sent to the Zixflow SDK for a
    /// Delivered/Opened/Clicked tracking call — use this to verify what's actually
    /// being sent for each notification lifecycle event during testing.
    private func logOutgoingTrack(kind: String, source: String, payload: [String: Any]) {
        print("")
        print("----------------------------------------")
        print("\u{1F4E4} OUTGOING TRACK [\(kind)] via \(source)")
        print(payload)
        print("----------------------------------------")
        print("")
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

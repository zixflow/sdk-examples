import UIKit
import Flutter
import UserNotifications

// For full Firebase + Zixflow native push, replace AppDelegate with
// ZixflowAppDelegateWrapper per push-notifications docs:
//
// import ZixflowMessagingPushFCM
// import FirebaseCore
// import FirebaseMessaging
//
// @main
// class AppDelegateWithZfIntegration: ZixflowAppDelegateWrapper<AppDelegate> {}

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    // Register ZX_2BTN so remote / local notifications can show ACTION_0 / ACTION_1.
    // Required for Zixflow campaigns that include action buttons (iOS category).
    registerPushActionCategories()

    // Push: add GoogleService-Info.plist, enable Push Notifications capability in Xcode,
    // set AppConfig.enablePush = true, and optionally use ZixflowAppDelegateWrapper (see README).

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

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
}

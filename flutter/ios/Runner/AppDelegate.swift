import UIKit
import Flutter

// For Firebase push, replace AppDelegate with ZixflowAppDelegateWrapper per push-notifications docs:
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

    // Push: add GoogleService-Info.plist, enable Push Notifications capability in Xcode,
    // and use ZixflowAppDelegateWrapper (see README).

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}

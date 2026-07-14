# Zixflow iOS SDK Example

SwiftUI feature demo for `ZixflowDataPipelines` with optional push (APNs) and location pods.

Docs: [Quick Start](https://docs.zixflow.com/documentation/sdk/ios/quick-start) · [Core Features](https://docs.zixflow.com/documentation/sdk/ios/core-features) · [Installation](https://docs.zixflow.com/documentation/sdk/ios/installation)

## Setup

1. Install CocoaPods dependencies (creates the `.xcworkspace`):

```bash
cd sdk-examples/ios
pod install
open ZixflowSdkExample.xcworkspace
```

If Xcode asks about signing, select your team under Signing & Capabilities.

2. Set your API key in `ZixflowSdkExample/Config.swift` (`YOUR_API_KEY`).
3. Select an iOS 13+ simulator or device and Run.

### Optional modules

The `Podfile` includes push APN and location pods. `AppDelegate` initializes them when `Config.enableOptionalModules` is `true`.

For real push:
- Enable Push Notifications + Background Modes capabilities
- Use a physical device
- Do not commit provisioning profiles or APNs keys

### Push action buttons

When optional modules are enabled, `AppDelegate` registers the `ZX_2BTN` notification category (`ACTION_0` / `ACTION_1`) and handles action taps:

1. Tracks **Opened** via `MessagingPush.shared.trackMetric` (action taps are not auto-tracked as opens)
2. Tracks **Push Notification Action Clicked** with delivery ID/token, `action_index`, `action_name`, `action_deeplink`
3. Opens the button deeplink with `UIApplication.shared.open` when non-empty

Send a test push with `aps.category` = `ZX_2BTN` and an `action_buttons` JSON array (max 2 buttons). Tap a button on a physical device and confirm both events in the dashboard.

## What you can try

| Action | SDK API |
|--------|---------|
| Identify / Track / Screen | Core |
| Profile / device attributes | `setProfileAttributes` / `setDeviceAttributes` |
| Alias | `alias(newId:)` |
| Flush | `flush` |
| Clear identify / Reset | Logout helpers |
| Device token | `registeredDeviceToken` |

## Verify

Identify → Track → Screen, then confirm events in the Zixflow dashboard for `user@example.com`.

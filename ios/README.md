# Zixflow iOS SDK Example

SwiftUI feature demo for `ZixflowDataPipelines` with optional push (APNs), in-app, and location pods.

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

The `Podfile` includes push APN, in-app, and location pods. `AppDelegate` initializes them when `Config.enableOptionalModules` is `true`.

For real push:
- Enable Push Notifications + Background Modes capabilities
- Use a physical device
- Do not commit provisioning profiles or APNs keys

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

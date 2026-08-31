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

## Push Test Matrix (gorush FCM/APNs cases)

Test cases: [`ios-push-test-cases-v2.md`](../../ios-push-test-cases-v2.md) (19 cases, direct gorush `/api/v1/push` payloads, `platform: 1`).

Two distinct handling paths exist in this app — no code change needed to switch between them, just the **app's foreground/background state** and whether the payload has `aps.alert` content:

| Path | When it fires | Code involved | What you'll see |
|---|---|---|---|
| **Solely handled by APNs** | App backgrounded/killed + payload has `aps.alert` (Cases 1–7, 9–17, 19) | None — `AppDelegate` is never invoked | System banner/Lock Screen notification renders exactly what APNs sent (title/subtitle/badge/sound/category actions), with zero app code touching it |
| **Custom handled, no UI** | Payload has **no** `aps.alert` (`content-available` only — Case 8, 18) — any app state | `application(_:didReceiveRemoteNotification:fetchCompletionHandler:)` (added) | Nothing appears in the tray. Xcode console logs `[PushHandlers] Silent/background push received (no UI)`, Delivered is tracked, `completionHandler(.newData)` is called |

Foreground delivery is a third, pre-existing case: `willPresent` always fires for alert pushes while the app is open (iOS never auto-shows a banner in foreground regardless of app code) — this app's `willPresent` returns `[.banner, .sound, .badge, .list]` so testing feels the same as background. This is the existing "custom UI" feature area (action buttons, tracking) and is unchanged here.

### Running each case

0. Use the **Custom handling** toggle on the home screen (persisted via `PushSettings`) to make `willPresent`/the silent-push handler do nothing at all, regardless of app state — proves "solely handled by APNs" even in foreground (with the toggle off, foreground alert pushes show *nothing*, exactly like a zero-push-code app; only backgrounding still shows the OS banner).
1. Run the app once, grab the APNs device token via `MessagingPush.shared.registeredDeviceToken` (or Xcode console — token is printed on registration).
2. Send the corresponding payload from `ios-push-test-cases-v2.md` to your own gorush instance (never embed gorush/admin credentials in this app).
3. For Cases 1–7, 9–17, 19: **background the app** (press Home) before sending, to observe the pure-APNs path.
4. For Case 8 and 18 (silent/data-only): app state doesn't matter — watch Xcode console for the silent-push log line instead of the tray.
5. Case 19 (kitchen sink): background the app; all `aps` fields should render as APNs defines them.

### Notification Service Extension (Case 7 — image / `mutable_content`)

Attaching a remote image to a push is **only** possible via a Notification Service Extension — there's no zero-code way to do this on iOS. Source is provided at [`ZixflowNotificationService/`](../ios/ZixflowNotificationService) but Xcode targets can't be safely wired by hand-editing `project.pbxproj`, so add it via Xcode:

1. Xcode → **File → New → Target… → Notification Service Extension**.
2. Name it `ZixflowNotificationService`, same team/bundle-id prefix as the app, do not activate the new scheme when prompted.
3. Xcode generates `NotificationService.swift` + `Info.plist` in a new folder — **replace both** with the versions already in [`ZixflowNotificationService/`](../ios/ZixflowNotificationService).
4. Build. The extension needs no CocoaPods (uses only `UserNotifications`/`Foundation`).
5. Send Case 7's payload (`mutable_content: true` + `data.image_url` = a reachable HTTPS image) — background the app first — long-press/expand the notification to see the image.

**The extension also tracks `Delivered` on the lock screen.** `NotificationService.didReceive` runs the instant a push arrives — even when the device is locked or the app is killed — which is the only client-side hook iOS provides for that state (`willPresent`/`didReceive` in `AppDelegate` only fire in the foreground or on tap). `trackDelivered(...)` posts the `Delivered` event directly to the Zixflow tracking API from the extension. Set `NSEConfig.writeKey` in `NotificationService.swift` to a **write-only** event-ingestion key (never a service-account/admin credential); it's left blank by default, which disables the call. See [Tracking Delivery When the Device Is Locked](../../event-module-docs/10-push-notification-endtoend.md#tracking-delivery-when-the-device-is-locked) for the full rationale.

### Custom sound, `click_action`, `priority`, `analytics_label`, `ttl` (custom-handled fields)

iOS is fundamentally different from Android/Flutter/RN here: almost all of these are either **server-side APNs headers/payload keys with no client-visible effect**, or require **manual Xcode project changes** that can't be safely scripted (no `pbxproj` editing). What's implemented in this sample, and what isn't possible at all:

| Field | Native (zero app code) | Custom-handled (this app) |
|---|---|---|
| Custom sound | ✅ `aps.sound: "notification_tone.wav"` — but **only if the file is bundled in the app target** (see step below) | Same requirement — this is an Xcode project membership issue, not a code issue |
| `click_action` | ❌ Not a real APNs field — iOS has no client-visible equivalent at all | ✅ `data.click_action` read in `AppDelegate`'s body-tap handler (`"OPEN_SALE"` / `"OPEN_DASHBOARD"` → `NavigationRouter.shared.openClickAction(_:)`), takes priority over `deeplink_url` |
| `priority` | `apns-priority` is an HTTP/2 **header**, not a payload key — invisible to any client code, no way to read it | ✅ `data.priority` logged diagnostically in `willPresent` (`[PushHandlers] Diagnostics — priority: ...`) — informational only, does not change how the notification is presented |
| `analytics_label` | Real field is Firebase Analytics-only (`fcm_options.analytics_label`), never delivered to APNs/iOS at all | ✅ `data.analytics_label` logged diagnostically in `willPresent`, same as above — our own convenience field, not part of the official Zixflow payload schema |
| `ttl` | `apns-expiration` is also an HTTP/2 header (delivery-queue expiry) — no client-visible effect on a normally-delivered push | Not implemented on iOS (unlike Android/Flutter/RN's `ttl_seconds` self-destruct convention) — local notification cancellation isn't meaningful here since APNs pushes don't go through `UNUserNotificationCenter.add(request:)` on this app; would require re-scheduling via the NSE instead |

**Bundling the custom sound file** (`notification_tone.wav`, already copied to [`ZixflowSdkExample/notification_tone.wav`](../ios/ZixflowSdkExample/notification_tone.wav)):

1. In Xcode, right-click the `ZixflowSdkExample` group → **Add Files to "ZixflowSdkExample"…**.
2. Select `notification_tone.wav`, ensure **"Copy items if needed"** is checked and the main app target's checkbox is ticked under "Add to targets".
3. Send a payload with `aps.sound: "notification_tone.wav"` (exact filename, extension included) — background the app first to test the pure-APNs path.

Without this step, `aps.sound` referencing a name with no matching bundled file **silently falls back to the default system sound** — there's no error, no crash, just the default tone playing instead.


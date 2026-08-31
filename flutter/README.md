# Zixflow Flutter SDK Example

Runnable demo for the [`zixflow`](https://pub.dev/packages/zixflow) Flutter SDK (core identify, track, screen, attributes, device token, and optional Firebase push with action buttons).

**Docs:** [Quick Start](https://docs.zixflow.com/documentation/sdk/flutter/quick-start) · [Core Features](https://docs.zixflow.com/documentation/sdk/flutter/core-features) · [Push Notifications](https://docs.zixflow.com/documentation/sdk/flutter/push-notifications) · [Push Tracking](https://docs.zixflow.com/documentation/sdk/flutter/push-notification-tracking)

## Prerequisites

- Flutter 3.x ([install Flutter](https://docs.flutter.dev/get-started/install))
- A Zixflow **API key** from **Settings → Developers → API Keys**

## Setup

### 1. API key

**Option A — `--dart-define` (recommended, no file edits):**

```bash
flutter run --dart-define=ZIXFLOW_API_KEY=your_api_key_here
```

**Option B — edit config file:**

```bash
cp lib/config.dart.example lib/config.dart
# Replace YOUR_API_KEY in lib/config.dart
```

The repo ships `lib/config.dart` with the `YOUR_API_KEY` placeholder only. Do not commit a real key.

### 2. Install dependencies

```bash
cd sdk-examples/flutter
flutter pub get
```

On iOS, install pods after the first `flutter pub get`:

```bash
cd ios && pod install && cd ..
```

### 3. Run (core demo — no Firebase required)

```bash
flutter run
# or with dart-define:
flutter run --dart-define=ZIXFLOW_API_KEY=your_api_key_here
```

`AppConfig.enablePush` defaults to **`false`**, so the app runs without Firebase config files.

## What the demo does

The home screen lists buttons that call:

| Button | SDK method |
|--------|------------|
| Identify | `Zixflow.instance.identify()` |
| Track Event | `Zixflow.instance.track()` |
| Screen View | `Zixflow.instance.screen()` |
| Set Profile Attributes | `Zixflow.instance.setProfileAttributes()` |
| Set Device Attributes | `Zixflow.instance.setDeviceAttributes()` |
| Clear Identify | `Zixflow.instance.clearIdentify()` |
| Register Device Token (demo) | `Zixflow.instance.registerDeviceToken()` with a placeholder token |
| Delete Device Token | `Zixflow.instance.deleteDeviceToken()` |

SDK initialization (in `lib/main.dart`) enables optional **location** (`LocationConfig`). Push is gated by `AppConfig.enablePush` / `ENABLE_PUSH` and implemented in `lib/push_handlers.dart`.

## Verify

1. Set your API key and run the app on a simulator, emulator, or device.
2. Tap **Identify**, then **Track Event** and **Screen View**.
3. Open the Zixflow dashboard and confirm events for `user@example.com`.
4. Enable debug logging (`LogLevel.debug` is set in `main.dart`) and watch console output.

## Optional: Push notifications (Firebase + action buttons)

Core analytics works without Firebase. For push with action buttons:

### 1. Firebase project files

1. Create a Firebase project and add iOS + Android apps with bundle / package ID **`com.zixflow.demo`**.
2. Download config files from Firebase Console:
   - **`google-services.json`** → `android/app/google-services.json`
   - **`GoogleService-Info.plist`** → `ios/Runner/GoogleService-Info.plist`
3. **Do not commit these files.** They are listed in `.gitignore`. Use the `.example` placeholders as a guide.

### 2. Platform wiring

1. Uncomment `id "com.google.gms.google-services"` in `android/app/build.gradle`.
2. Uncomment `POST_NOTIFICATIONS` in `android/app/src/main/AndroidManifest.xml`.
3. iOS: enable **Push Notifications** (+ Background Modes → Remote notifications) in Xcode. `AppDelegate.swift` already registers the `ZX_2BTN` category (`ACTION_0` / `ACTION_1`).
4. Optional: run `dart pub global activate flutterfire_cli && flutterfire configure` to generate `lib/firebase_options.dart`, then switch `main.dart` to `Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)`. Without that file, `Firebase.initializeApp()` uses the native plist / json.

### 3. Enable push in the demo

**Option A — dart-define:**

```bash
flutter run \
  --dart-define=ZIXFLOW_API_KEY=your_api_key_here \
  --dart-define=ENABLE_PUSH=true
```

**Option B — config:**

In `lib/config.dart`, change the `enablePush` `defaultValue` to `true` (or set `enablePush = true` if you use the simple form from `config.dart.example`).

When `enablePush` is true, `main.dart` initializes Firebase and `PushHandlers` (token registration, foreground local notifications with actions, Opened + Action Clicked tracking).

### 4. Test action buttons

1. Run on a **physical device** (required for reliable push).
2. Tap **Identify** so the FCM token is linked to a profile.
3. In Zixflow, send a test push that includes `action_buttons`, for example:

   ```json
   [
     { "name": "Shop Now", "deeplink": "https://example.com/sale" },
     { "name": "Remind Me", "deeplink": "" }
   ]
   ```

4. With the app in the **foreground**, the demo shows a local notification with up to two actions (`ACTION_0` / `ACTION_1`).
5. Tap an action button and confirm in the dashboard / debug logs:
   - `Push Notification Opened` (`trackMetric` / MetricEvent.opened)
   - `Push Notification Action Clicked` (`track` with `action_index`, `action_name`, etc.)

See [Push Notification Tracking](https://docs.zixflow.com/documentation/sdk/flutter/push-notification-tracking) for payload field details.

## Push Test Matrix (gorush FCM/APNs cases)

Test cases: [`android-fcm-push-test-cases-v2.md`](../../android-fcm-push-test-cases-v2.md) (13 Android cases) · [`ios-push-test-cases-v2.md`](../../ios-push-test-cases-v2.md) (19 iOS cases) — direct gorush `/api/v1/push` payloads.

> **Native vs. Custom payload modes:** a Zixflow campaign can send in **Native** mode (display content in the `notification`/`aps.alert` blocks, `data` carries only tracking + routing keys — the OS renders it) or **Custom** mode (no `notification` block; the full content is in `data`, sent as a high-priority data message so this app renders it). High priority is also what lets the background handler track `Delivered` while the device is **locked** on Android; on iOS a Notification Service Extension is required for the same. See the [payload wire format](../../event-module-docs/10-push-notification-endtoend.md#fcm-android-wire-format) and [Tracking Delivery When the Device Is Locked](../../event-module-docs/10-push-notification-endtoend.md#tracking-delivery-when-the-device-is-locked).

`lib/push_handlers.dart` is pure Dart on both platforms (no native Kotlin/Swift push code) and now has two distinct paths, switched purely by **app state** + **payload shape** — no toggle needed:

| Path | When it fires | Code involved | What you'll see |
|---|---|---|---|
| **Solely handled by FCM/APNs** | App backgrounded/killed + payload has a `notification` block | Neither `onMessage` nor `firebaseMessagingBackgroundHandler` builds a local notification | System tray shows exactly what FCM/APNs sent, untouched by Dart code |
| **Custom handled, no UI** | Payload has **no** `notification` block and no `title`/`body` in `data` (pure silent/data-sync — Android Case 12, iOS Case 8 & 18) — any app state | `firebaseMessagingBackgroundHandler` / `onMessage` listener (both fixed) | Nothing appears in the tray. Console logs `Silent/data-only push (no notification content) — processing data, showing no UI`; Delivered is still tracked |

Foreground delivery is a third, pre-existing case: the `onMessage` listener always fires while the app is open (neither platform auto-shows a notification in foreground) — this app then builds a local notification itself via `flutter_local_notifications` (image, actions, sound, sticky). That's the existing "custom UI" feature area and is unchanged here.

**Why the background handler also checks `message.notification != null`:** FCM/APNs already auto-display a `notification`-block push while backgrounded — `firebaseMessagingBackgroundHandler` still runs (Firebase spawns the isolate so the app can process the accompanying `data`), but it must **not** also call `_showLocalNotification`, or the user sees a duplicate.

### Running each case

0. Use the **Custom handling** switch on the home screen (persisted via `SharedPreferences`, read by both the foreground listener and the background isolate) to make `push_handlers.dart` do nothing at all, regardless of app state — proves "solely handled by FCM/APNs" even in foreground.
1. Run the app, grab the token from the on-screen field / console (`FCM token registered:` / `FCM token refreshed:`).
2. Send the corresponding payload from the docs above to your own gorush instance (never embed gorush/admin credentials in this app).
3. For notification-block cases: **background the app** before sending to observe the pure-FCM/APNs path.
4. For the silent/data-only cases: app state doesn't matter — watch the console for the silent-push log line instead of the tray.

### Custom icon, sound, priority, `click_action`, `analytics_label`, `ttl_seconds` (Android)

`_showLocalNotification()` in `lib/push_handlers.dart` (the custom-handled/foreground path) supports every one of these fields:

| Field | Behaviour |
|---|---|
| `icon` | Notifications always pass `icon: 'ic_notification'` and the manifest declares `default_notification_icon` / `default_notification_color` meta-data — a status-bar icon that isn't a matching bundled drawable renders as a blank icon on the native path, so this app ships a ready-made one instead of relying on a downloaded name. |
| `sound` | `data.sound` is played from a matching file in `android/app/src/main/res/raw/` (bare name, no extension) — a bundled `notification_tone.wav` is included for testing (`"sound": "notification_tone"`). |
| `priority` | `data.priority == "normal"` routes the notification to a second, lower-importance channel (`zixflow_normal`, no heads-up banner) instead of the default `zixflow_default` channel. This is a demo convention to make the difference visible — the real FCM `android.priority` header only affects delivery timing and isn't readable by app code. |
| `click_action` | `data.click_action` (`"OPEN_SALE"` / `"OPEN_DASHBOARD"`) is resolved on tap, taking priority over `deeplink_url` when both are present. This is a custom convention — it's unrelated to FCM's own `android.notification.click_action`, which requires an exact matching `<intent-filter>` action string on the native path or the tap does nothing at all. |
| `analytics_label` | Logged via `debugPrint` for visibility during testing — the real `fcm_options.analytics_label` is Firebase Analytics-only and never reaches app code. |
| `ttl_seconds` | Self-cancels the notification N seconds after it's shown (`Future.delayed` + `plugin.cancel`) — a demo-only convenience, distinct from FCM's real `android.ttl` delivery-queue expiry (which has no client-visible effect on a normal online send). |

Send a payload with any combination of these fields in `data` (with the app in the foreground) to see them applied. iOS has no client-visible equivalent for `priority`/`ttl`/`click_action`/`analytics_label` — see the iOS sample's README for what's supported there.




- **Android:** `zixflow_location_enabled=true` is set in `android/gradle.properties`.
- **Android permissions:** `ACCESS_COARSE_LOCATION` / `ACCESS_FINE_LOCATION` in `AndroidManifest.xml`.
- **iOS:** `NSLocationWhenInUseUsageDescription` in `Info.plist`. Uncomment the location pod in `ios/Podfile` if using CocoaPods location subspec.
- Request runtime permission in your app before calling `Zixflow.location.requestLocationUpdate()`.

See [Location Tracking](https://docs.zixflow.com/documentation/sdk/flutter/location-tracking).

## Platform notes

| Platform | File | Notes |
|----------|------|--------|
| Android | `android/app/build.gradle` | Uncomment Google Services plugin when using Firebase |
| Android | `android/app/src/main/AndroidManifest.xml` | Internet + location; POST_NOTIFICATIONS for push |
| iOS | `ios/Runner/Info.plist` | Location usage string; `remote-notification` background mode |
| iOS | `ios/Runner/AppDelegate.swift` | Registers `ZX_2BTN`; comments for `ZixflowAppDelegateWrapper` |
| Dart | `lib/push_handlers.dart` | FCM + local notifications + action-button tracking |
| Dart | `lib/config.dart` | `enablePush` / `ENABLE_PUSH` flag (default `false`) |

## License

MIT — see [LICENSE](../LICENSE).

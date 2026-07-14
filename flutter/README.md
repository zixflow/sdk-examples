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

## Optional: Location tracking

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

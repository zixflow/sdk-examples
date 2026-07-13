# Zixflow Flutter SDK Example

Runnable demo for the [`zixflow`](https://pub.dev/packages/zixflow) Flutter SDK (core identify, track, screen, attributes, and device token APIs).

**Docs:** [Quick Start](https://docs.zixflow.com/documentation/sdk/flutter/quick-start) · [Core Features](https://docs.zixflow.com/documentation/sdk/flutter/core-features) · [Installation](https://docs.zixflow.com/documentation/sdk/flutter/installation)

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

### 3. Run

```bash
flutter run
# or with dart-define:
flutter run --dart-define=ZIXFLOW_API_KEY=your_api_key_here
```

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

SDK initialization (in `lib/main.dart`) enables optional **location** (`LocationConfig`). Push/Firebase setup is commented with instructions.

## Verify

1. Set your API key and run the app on a simulator, emulator, or device.
2. Tap **Identify**, then **Track Event** and **Screen View**.
3. Open the Zixflow dashboard and confirm events for `user@example.com`.
4. Enable debug logging (`LogLevel.debug` is set in `main.dart`) and watch console output.

## Optional: Push notifications (Firebase)

Core analytics works without Firebase. For push:

1. Create a Firebase project and add iOS + Android apps with bundle ID **`com.zixflow.demo`**.
2. Download config files from Firebase Console:
   - **`google-services.json`** → `android/app/google-services.json`
   - **`GoogleService-Info.plist`** → `ios/Runner/GoogleService-Info.plist`
3. **Do not commit these files.** They are listed in `.gitignore`. Use your own Firebase project files locally.

Example placeholder (replace with your Firebase Android app config):

```json
{
  "project_info": {
    "project_number": "YOUR_PROJECT_NUMBER",
    "project_id": "YOUR_PROJECT_ID"
  },
  "client": [
    {
      "client_info": {
        "mobilesdk_app_id": "YOUR_APP_ID",
        "android_client_info": {
          "package_name": "com.zixflow.demo"
        }
      }
    }
  ]
}
```

4. Add to `pubspec.yaml`:

   ```yaml
   firebase_core: ^3.3.0
   firebase_messaging: ^15.0.4
   ```

5. Run `dart pub global activate flutterfire_cli && flutterfire configure`.
6. Uncomment Firebase initialization in `lib/main.dart`.
7. Uncomment `com.google.gms.google-services` in `android/app/build.gradle`.
8. Uncomment `POST_NOTIFICATIONS` in `android/app/src/main/AndroidManifest.xml`.
9. Configure iOS: Push Notifications capability, `ZixflowAppDelegateWrapper` in `AppDelegate.swift` — see [Push Notifications](https://docs.zixflow.com/documentation/sdk/flutter/push-notifications).

Test push on a **physical device** after `identify()` and registering a real FCM token.

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
| iOS | `ios/Runner/AppDelegate.swift` | Comments for `ZixflowAppDelegateWrapper` push setup |

## License

MIT — see [LICENSE](../LICENSE).

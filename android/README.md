# Zixflow Android SDK Example

Kotlin feature demo for `com.zixflow.com.android:datapipelines` plus optional FCM push and location modules.

Docs: [Quick Start](https://docs.zixflow.com/documentation/sdk/android/quick-start) · [Core Features](https://docs.zixflow.com/documentation/sdk/android/core-features) · [Installation](https://docs.zixflow.com/documentation/sdk/android/installation)

## Setup

1. Open this folder in Android Studio (Giraffe+ / AGP 8+).
2. Copy `local.properties.example` → `local.properties` and set `sdk.dir` (Android Studio usually creates this).
3. Set your API key in `app/src/main/java/com/zixflow/demo/Config.kt` (replace `YOUR_API_KEY`).
4. Sync Gradle and run on an emulator or device (API 21+).

### Optional: push / Firebase

```bash
# Place your Firebase file (do not commit):
cp app/google-services.json.example app/google-services.json
# Replace with a real google-services.json from Firebase Console
```

Then uncomment the Google Services plugin lines in `build.gradle.kts` files (see comments).

## What you can try

| Action | SDK API |
|--------|---------|
| Identify | `Zixflow.instance().identify` |
| Track | `track` |
| Screen | `screen` |
| Profile / device attributes | `setProfileAttributes` / `setDeviceAttributes` |
| Device token | `registerDeviceToken` / `deleteDeviceToken` / `registeredDeviceToken` |
| Logout | `clearIdentify()` |

Init enables `ModuleMessagingPushFCM` and `ModuleLocation` when `Config.enableOptionalModules` is true (default).

## Verify

1. Tap **Identify**, then **Track** / **Screen**.
2. Confirm events in the Zixflow dashboard for `user@example.com`.
3. Push requires a physical device + real `google-services.json`.

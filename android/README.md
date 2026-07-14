# Zixflow Android SDK Example

Kotlin feature demo for `com.zixflow.com.android:datapipelines` plus optional FCM push and location modules.

Docs: [Quick Start](https://docs.zixflow.com/documentation/sdk/android/quick-start) · [Core Features](https://docs.zixflow.com/documentation/sdk/android/core-features) · [Installation](https://docs.zixflow.com/documentation/sdk/android/installation)

## Setup

1. Open this folder in Android Studio (Meerkat+ / AGP 8.9.1+).
2. Copy `local.properties.example` → `local.properties` and set `sdk.dir` (Android Studio usually creates this).
3. Set your API key in `app/src/main/java/com/zixflow/demo/Config.kt` (replace `YOUR_API_KEY`).
4. Sync Gradle and run on an emulator or device (API 21+; project uses `compileSdk` / `targetSdk` 36).

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

Init enables `ModuleMessagingPushFCM` and `ModuleLocation` when `Config.enableOptionalModules` is true (default). Push action buttons are wired via `MessagingPushModuleConfig.setNotificationCallback` → `PushActionButtons.attach` (parses `action_buttons`, `NotificationCompat.addAction`) and `NotificationActionReceiver` (tracks Opened then `Push Notification Action Clicked`).

## Verify

1. Tap **Identify**, then **Track** / **Screen**.
2. Confirm events in the Zixflow dashboard for `user@example.com`.
3. Push requires a physical device + real `google-services.json`.

### Action buttons

1. Identify a user and confirm the device token is registered (use **Show token**).
2. From the Zixflow dashboard, send a push with two action buttons (payload includes `action_buttons` JSON).
3. On the device, expand the notification and tap a button.
4. Confirm in the dashboard: **Opened** metric, then event `Push Notification Action Clicked` with `action_index` / `action_name` / `action_deeplink`.
5. If the button has a non-empty deeplink, the app opens it via `Intent.ACTION_VIEW`.

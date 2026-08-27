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

## Push Test Matrix (gorush FCM cases)

Test cases: [`android-fcm-push-test-cases-v2.md`](../../android-fcm-push-test-cases-v2.md) (13 cases, direct gorush `/api/v1/push` payloads, `platform: 2`).

Two distinct handling paths exist in this app — no build flag needed to switch, just the **app's foreground/background state** and whether the payload has a `notification` block:

| Path | When it fires | Code involved | What you'll see |
|---|---|---|---|
| **Solely handled by FCM** | App backgrounded/killed + payload has a `notification` block (Cases 1–11, 13) | None — `CustomFirebaseMessagingService.onMessageReceived` is never invoked by Android/Play Services for this combination | System tray shows exactly what FCM sent, zero app code touching it |
| **Custom handled, no UI** | Payload has **no** `notification` block and no `title`/`body` in `data` (pure data-only/silent sync — Case 12) — any app state | `onMessageReceived` → `handlePushManually()` (fixed) | Nothing appears in the tray. Logcat tag `CustomFCMService` logs `Silent/data-only push (no notification content) — processing data, showing no UI`; Delivered is still tracked |

Foreground delivery is a third, pre-existing case: `onMessageReceived` always fires for every message type while the app is open (Android never auto-shows a notification in foreground regardless of app code) — this app then builds a rich notification itself (image, actions, sound, sticky). That's the existing "custom UI" feature area and is unchanged here.

### Running each case

0. Use the **Custom handling** switch on the home screen (persisted via `PushSettings`) to force `CustomFirebaseMessagingService.onMessageReceived` to do nothing at all, regardless of app state — the cleanest way to prove "solely handled by FCM" even in foreground (with the switch off, foreground notification-block pushes now show *nothing*, exactly like a zero-push-code app; only backgrounding still shows the OS tray version).
1. Run the app once, tap **Show token** to get the FCM registration token (also printed to Logcat).
2. Send the corresponding payload from `android-fcm-push-test-cases-v2.md` to your own gorush instance (never embed gorush/admin credentials in this app).
3. For Cases 1–11, 13: **background the app** (Home button) before sending, to observe the pure-FCM path in the system tray.
4. For Case 12 (data-only/silent): app state doesn't matter — watch Logcat (`CustomFCMService` tag) for the silent-push log line instead of the tray.
5. Case 13 (kitchen sink): background the app; every `notification`/`android.notification` field should render exactly as FCM defines it.


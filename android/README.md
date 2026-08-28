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

### Custom icon, sound, priority, `click_action`, `analytics_label`, `ttl_seconds`

`CustomFirebaseMessagingService.showNotification()` (the custom-handled/foreground path) supports every one of these fields:

| Field | Behaviour |
|---|---|
| `icon` | The notification always uses the bundled `R.drawable.ic_notification` and `default_notification_icon` / `default_notification_color` manifest meta-data — a status-bar icon that isn't a matching bundled drawable renders as a blank icon on the native path, so this app ships a ready-made one instead of relying on a downloaded name. |
| `sound` | `data.sound` is played from a matching file in `res/raw/` (bare name, no extension) — a bundled `notification_tone.wav` is included for testing (`"sound": "notification_tone"`). |
| `priority` | `data.priority == "normal"` routes the notification to a second, lower-importance channel (`zixflow_normal`, no heads-up banner) instead of the default `zixflow_default` channel. This is a demo convention to make the difference visible — the real FCM `android.priority` header only affects delivery timing and isn't readable by app code. |
| `click_action` | `data.click_action` (`"OPEN_SALE"` / `"OPEN_DASHBOARD"`) is resolved on tap via `DeeplinkRouter.openClickAction()`, taking priority over `deeplink_url` when both are present. This is a custom convention — it's unrelated to FCM's own `android.notification.click_action`, which requires an exact matching `<intent-filter>` action string on the native path or the tap does nothing at all. |
| `analytics_label` | Logged via `Log.i` for visibility during testing — the real `fcm_options.analytics_label` is Firebase Analytics-only and never reaches app code. |
| `ttl_seconds` | Self-cancels the notification N seconds after it's shown (`Handler.postDelayed` + `NotificationManagerCompat.cancel`) — a demo-only convenience, distinct from FCM's real `android.ttl` delivery-queue expiry (which has no client-visible effect on a normal online send). |

Send a payload with any combination of these fields in `data` (with the app in the foreground) to see them applied.


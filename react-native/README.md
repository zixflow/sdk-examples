# Zixflow React Native SDK Example

Feature demo for [`zixflow-reactnative`](https://www.npmjs.com/package/zixflow-reactnative) covering core analytics and push token APIs.

Docs: [Quick Start](https://docs.zixflow.com/documentation/sdk/react-native/quick-start) · [Core Features](https://docs.zixflow.com/documentation/sdk/react-native/core-features) · [Installation](https://docs.zixflow.com/documentation/sdk/react-native/installation) · [Push](https://docs.zixflow.com/documentation/sdk/react-native/push-notifications) · [Location](https://docs.zixflow.com/documentation/sdk/react-native/location-tracking)

## What this folder contains

| Path | Purpose |
|------|---------|
| `App.tsx` | Demo UI and all `Zixflow.*` calls |
| `src/config.ts` | API key and `ZixflowConfig` |
| `src/pushActions.ts` | `parseActionButtons` / `trackActionClick` helpers |
| `native-snippets/` | Critical Android/iOS integration snippets |
| `package.json` | Depends on `zixflow-reactnative@^1.1.3` |

This repo ships **JavaScript/TypeScript source** plus native snippets. Generate `android/` and `ios/` with the React Native CLI (steps below).

## Prerequisites

1. [React Native environment setup](https://reactnative.dev/docs/set-up-your-environment) (Node 20+, Xcode for iOS, Android Studio for Android).
2. A Zixflow **API key** from **Settings → Developers → API Keys**.

## 1. Configure credentials

```bash
cp .env.example .env
# Edit src/config.ts and replace YOUR_API_KEY with your real key
```

> React Native does not load `.env` automatically in this demo — copy the value into `src/config.ts`. Do not commit real keys.

## 2. Create a bare React Native shell (one-time)

From this folder (`sdk-examples/react-native/`):

```bash
# Generate native projects in a temp directory, then merge into this folder
npx @react-native-community/cli@latest init ZixflowRNDemo --version 0.83.0 --skip-install

# Copy native folders and lockfiles from the generated project
cp -R ZixflowRNDemo/android ./
cp -R ZixflowRNDemo/ios ./
cp ZixflowRNDemo/Gemfile ./ 2>/dev/null || true

# Remove the temp scaffold (keep this folder's App.tsx, src/, package.json)
rm -rf ZixflowRNDemo
```

Ensure `app.json` name matches the native app name:

```json
{ "name": "ZixflowRNDemo", "displayName": "Zixflow RN Demo" }
```

Update `android/app/src/main/java/com/zixflow/demo/MainActivity.kt` `getMainComponentName()` to return `"ZixflowRNDemo"` if the CLI used a different package path.

## 3. Install dependencies

```bash
npm install
cd ios && bundle exec pod install && cd ..
```

Apply push/location native setup from [`native-snippets/README.md`](./native-snippets/README.md) before testing push on device.

### Android FCM (required for push on Android)

1. In [Firebase Console](https://console.firebase.google.com/) → **Project settings** → **Your apps**, add an Android app with package name `com.zixflow.demo` (must match `applicationId` in `android/app/build.gradle`).
2. Download the **client** config file named **`google-services.json`** (plural) and place it at:

   ```text
   android/app/google-services.json
   ```

   See [`android/app/google-services.json.example`](./android/app/google-services.json.example) for the expected shape (copy/rename after downloading the real file from Firebase).

3. Rebuild the app (`npm run android`). The Google Services Gradle plugin is already wired and applies automatically when this file exists.

> **Wrong file:** A Firebase **service account** JSON (`type: "service_account"`, includes a `private_key`) is **not** `google-services.json`. Use that only in the Zixflow dashboard / backend for sending pushes — never in the Android app. The client file has `project_info` and a `client` array with your package name.

Also configure FCM credentials in the Zixflow dashboard (**Settings → Developers / Push**).

**Push verify (after rebuild):**

1. Logcat should **not** show `Default FirebaseApp is not initialized`.
2. In the app: **Identify** → **Request push permission** → **Get registered token** (field should auto-fill; token should be non-empty).
3. Confirm the device/push token on the user profile in the Zixflow dashboard.

## 4. Run

```bash
npm start
npm run ios      # macOS + Xcode
npm run android  # emulator or device
```

## What you can try

| Button | SDK API |
|--------|---------|
| Identify | `Zixflow.identify({ userId, traits })` |
| Track | `Zixflow.track('button_clicked', props)` |
| Screen | `Zixflow.screen('DemoHomeScreen', props)` |
| Set profile attributes | `Zixflow.setProfileAttributes({...})` |
| Set device attributes | `Zixflow.setDeviceAttributes({...})` |
| Clear identify | `Zixflow.clearIdentify()` |
| Request push permission | `Zixflow.pushMessaging.showPromptForPushNotifications()` |
| Get registered token | `Zixflow.pushMessaging.getRegisteredDeviceToken()` |
| Register device token | `Zixflow.registerDeviceToken(token)` |
| Delete device token | `Zixflow.deleteDeviceToken()` |

## Verify

1. Set your API key in `src/config.ts`.
2. Run the app on a simulator or emulator.
3. Tap **Identify**, then **Track** and **Screen**.
4. Confirm events for `user-123` / `user@example.com` in the Zixflow dashboard.
5. For push: install `android/app/google-services.json`, rebuild, use a **physical device** when possible, then **Identify** → **Request push permission** → **Get registered token**.

## Push and location

- **Push** — Requires platform setup (APNs or FCM), dashboard credentials, and `identify()` before targeted sends. See `native-snippets/`.
- **Location** — Optional native module; enable Podfile subspec (iOS) and `zixflow_location_enabled=true` (Android). Your app must request OS location permission.

## Push action buttons

1. **Identify** the user, grant push permission, and confirm a registered device token.
2. In the Zixflow dashboard, send a test push with **two action buttons** (`action_buttons` JSON) and iOS category `ZX_2BTN`.
3. On a **physical device**, tap an action button.
4. Confirm **Opened** then **Push Notification Action Clicked** in campaign analytics.

### Platform notes

| Platform | What this demo does |
|----------|---------------------|
| **iOS** | `AppDelegate` (and APN/FCM snippets) register `ZX_2BTN` with `ACTION_0` / `ACTION_1`. Use `src/pushActions.ts` (`parseActionButtons`, `trackActionClick`) when action payloads reach JS. |
| **Android** | The RN bridge does **not** expose `setNotificationCallback` from JS (only `pushClickBehavior`). This demo wires it in native Kotlin after JS `initialize`: `PushActionButtonsInstaller` + `PushActionButtons` + `NotificationActionReceiver` under `android/app/.../com/zixflow/demo/`. Snippets for other apps: `native-snippets/android/`. |

## Push Test Matrix (gorush FCM/APNs cases)

Test cases: [`android-fcm-push-test-cases-v2.md`](../../android-fcm-push-test-cases-v2.md) (13 Android cases) · [`ios-push-test-cases-v2.md`](../../ios-push-test-cases-v2.md) (19 iOS cases) — direct gorush `/api/v1/push` payloads.

> **Native vs. Custom payload modes:** a Zixflow campaign can send in **Native** mode (display content in the `notification`/`aps.alert` blocks, `data` carries only tracking + routing keys — the OS renders it) or **Custom** mode (no `notification` block; the full content is in `data`, sent as a high-priority data message so this app renders it). High priority is also what lets `firebaseBackgroundMessageHandler` track `Delivered` while the device is **locked** on Android; on iOS a Notification Service Extension is required for the same. See the [payload wire format](../../event-module-docs/10-push-notification-endtoend.md#fcm-android-wire-format) and [Tracking Delivery When the Device Is Locked](../../event-module-docs/10-push-notification-endtoend.md#tracking-delivery-when-the-device-is-locked).

`src/pushHandlers.ts` (via `@react-native-firebase/messaging` + `notifee`) is JS-only on both platforms and has two distinct paths, switched purely by **app state** + **payload shape** — no toggle needed:

| Path | When it fires | Code involved | What you'll see |
|---|---|---|---|
| **Solely handled by FCM/APNs** | App backgrounded/killed + payload has a `notification` block | Neither `onMessage` nor `firebaseBackgroundMessageHandler` calls `showNotification` | System tray shows exactly what FCM/APNs sent, untouched by JS |
| **Custom handled, no UI** | Payload has **no** `notification` block and no `title`/`body` in `data` (pure silent/data-sync — Android Case 12, iOS Case 8 & 18) — any app state | `onMessage` / `firebaseBackgroundMessageHandler` (both fixed in `pushHandlers.ts`) | Nothing appears in the tray. Console logs `Silent/data-only push (no notification content) — processing data, showing no UI`; Delivered is still tracked |

Foreground delivery is a third, pre-existing case: `onMessage` always fires while the app is open (neither platform auto-shows a notification in foreground) — this demo then calls `notifee.displayNotification` itself (image, actions, sound, badge). That's the existing "custom UI" feature area and is unchanged here.

**Why the background handler also checks `message.notification`:** FCM/APNs already auto-display a `notification`-block push while backgrounded — `firebaseBackgroundMessageHandler` still runs (so the app can process the accompanying `data`), but it must **not** also call `showNotification`, or the user sees a duplicate.

### Running each case

0. Use the **Custom handling** switch on the home screen (persisted via `AsyncStorage`, read by both the foreground listener and `firebaseBackgroundMessageHandler`) to make `pushHandlers.ts` do nothing at all, regardless of app state — proves "solely handled by FCM/APNs" even in foreground.
1. Run the app, grab the token via **Get registered token** (also printed to console as `FCM token registered:`).
2. Send the corresponding payload from the docs above to your own gorush instance (never embed gorush/admin credentials in this app).
3. For notification-block cases: **background the app** before sending to observe the pure-FCM/APNs path.
4. For the silent/data-only cases: app state doesn't matter — watch the console for the silent-push log line instead of the tray.

> **iOS silent/background pushes (Case 8, 18):** `@react-native-firebase/messaging`'s background handler wires the native APNs `content-available` hook automatically — no extra native code is required in `ios/ZixflowRNDemo/AppDelegate.swift` for this repo's JS-only setup.

### Custom icon, sound, priority, `click_action`, `analytics_label`, `ttl_seconds` (Android)

`showZixflowNotification()` in `src/pushHandlers.ts` (the custom-handled/foreground path, via `notifee`) supports every one of these fields:

| Field | Behaviour |
|---|---|
| `icon` | Notifications always pass `smallIcon: 'ic_notification'` and the manifest declares `default_notification_icon` / `default_notification_color` meta-data — a status-bar icon that isn't a matching bundled drawable renders as a blank icon on the native path, so this app ships a ready-made one instead of relying on a downloaded name. |
| `sound` | `data.sound` is played from a matching file in `android/app/src/main/res/raw/` (bare name, no extension) — a bundled `notification_tone.wav` is included for testing (`"sound": "notification_tone"`). |
| `priority` | `data.priority == "normal"` routes the notification to a second, lower-importance channel (`zixflow_normal`, no heads-up banner) instead of the default `zixflow_default` channel. This is a demo convention to make the difference visible — the real FCM `android.priority` header only affects delivery timing and isn't readable by app code. |
| `click_action` | `data.click_action` (`"OPEN_SALE"` / `"OPEN_DASHBOARD"`) is resolved on tap, taking priority over `deeplink_url` when both are present. This is a custom convention — it's unrelated to FCM's own `android.notification.click_action`, which requires an exact matching `<intent-filter>` action string on the native path or the tap does nothing at all. |
| `analytics_label` | Logged via `console.log` for visibility during testing — the real `fcm_options.analytics_label` is Firebase Analytics-only and never reaches app code. |
| `ttl_seconds` | Self-cancels the notification N seconds after it's shown (`setTimeout` + `notifee.cancelNotification`) — a demo-only convenience, distinct from FCM's real `android.ttl` delivery-queue expiry (which has no client-visible effect on a normal online send). |

Send a payload with any combination of these fields in `data` (with the app in the foreground) to see them applied. iOS has no client-visible equivalent for `priority`/`ttl`/`click_action`/`analytics_label` — see the iOS sample's README for what's supported there.

### Template-based custom rendering (`template_id`)

When a customer creates a notification template in the Zixflow dashboard (Push Notifications → Templates), the template gets a unique **Template ID** (shown in the templates list) that's automatically included as `data.template_id` on every push sent from it. `showNotification()` in `src/pushHandlers.ts` checks `data.template_id` before falling back to the generic renderer above — send a push with `"template_id": "469935"` to see it render via the dedicated `showTemplateExampleNotification()` (its own `zixflow_template_example` channel) instead, built from every field a real dashboard template defines. See [Template-Based Custom Rendering](../../event-module-docs/10-push-notification-endtoend.md#template-based-custom-rendering-template_id) for the full pattern and per-platform code.



- Real API keys in `src/config.ts`
- `android/app/google-services.json` (and misnamed `google-service.json`)
- Firebase service-account / `*firebase-adminsdk*.json` files
- `GoogleService-Info.plist`
- Keystores, provisioning profiles, `.env` with real values

[`.gitignore`](./.gitignore) and parent [`../.gitignore`](../.gitignore) exclude these patterns.

## Troubleshooting

- **SDK not initialized** — Check `ZIXFLOW_API_KEY` in `src/config.ts`.
- **iOS build fails** — Open `ios/*.xcworkspace` in Xcode; run `pod install` after Podfile changes.
- **`Default FirebaseApp is not initialized`** — Add the Firebase **client** `android/app/google-services.json` (not a service-account JSON), then rebuild. Confirm the Google Services plugin applied (file must be named exactly `google-services.json`).
- **Push token empty / `device_token_not_found`** — Confirm `google-services.json` is present, rebuild, grant notification permission, tap **Identify**, wait a few seconds, then **Get registered token**.

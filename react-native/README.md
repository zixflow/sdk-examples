# Zixflow React Native SDK Example

Feature demo for [`zixflow-reactnative`](https://www.npmjs.com/package/zixflow-reactnative) covering core analytics and push token APIs.

Docs: [Quick Start](https://docs.zixflow.com/documentation/sdk/react-native/quick-start) · [Core Features](https://docs.zixflow.com/documentation/sdk/react-native/core-features) · [Installation](https://docs.zixflow.com/documentation/sdk/react-native/installation) · [Push](https://docs.zixflow.com/documentation/sdk/react-native/push-notifications) · [Location](https://docs.zixflow.com/documentation/sdk/react-native/location-tracking)

## What this folder contains

| Path | Purpose |
|------|---------|
| `App.tsx` | Demo UI and all `Zixflow.*` calls |
| `src/config.ts` | API key and `ZixflowConfig` |
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

Update `android/app/src/main/java/.../MainActivity.kt` `getMainComponentName()` to return `"ZixflowRNDemo"` if the CLI used a different package path.

## 3. Install dependencies

```bash
npm install
cd ios && bundle exec pod install && cd ..
```

Apply push/location native setup from [`native-snippets/README.md`](./native-snippets/README.md) before testing push on device.

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
5. For push: complete native setup, use a **physical device**, call **Identify**, then request permission and register the device token.

## Push and location

- **Push** — Requires platform setup (APNs or FCM), dashboard credentials, and `identify()` before targeted sends. See `native-snippets/`.
- **Location** — Optional native module; enable Podfile subspec (iOS) and `zixflow_location_enabled=true` (Android). Your app must request OS location permission.

## Secrets (do not commit)

- Real API keys in `src/config.ts`
- `google-services.json`, `GoogleService-Info.plist`
- Keystores, provisioning profiles, `.env` with real values

Parent [`.gitignore`](../.gitignore) already excludes these patterns.

## Troubleshooting

- **SDK not initialized** — Check `ZIXFLOW_API_KEY` in `src/config.ts`.
- **iOS build fails** — Open `ios/*.xcworkspace` in Xcode; run `pod install` after Podfile changes.
- **Push token empty** — Complete native push setup; simulators cannot receive APNs.

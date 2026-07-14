# Zixflow SDK Examples

Public, runnable feature demos for every Zixflow analytics SDK. Use these to verify events in your Zixflow dashboard and as a reference for customer integrations.

**Docs:** [SDK Integrations](https://docs.zixflow.com) · **Repo:** [github.com/zixflow/sdk-examples](https://github.com/zixflow/sdk-examples)

## Examples

| Folder | SDK package | Credential |
|--------|-------------|------------|
| [`javascript/`](./javascript) | `@zixflow/analytics-browser` (jsDelivr UMD) | Write key |
| [`react/`](./react) | `@zixflow/analytics-browser` (Vite + React) | Write key |
| [`nodejs/`](./nodejs) | `@zixflow/analytics-node` | Write key |
| [`react-native/`](./react-native) | `zixflow-reactnative` | API key |
| [`flutter/`](./flutter) | `zixflow` (pub.dev) | API key |
| [`ios/`](./ios) | `ZixflowDataPipelines` (CocoaPods) | API key |
| [`android/`](./android) | `com.zixflow.com.android:datapipelines` | API key |

Each folder is a self-contained project with its own README (install, run, verify).

## Quick start

1. Clone this repository.
2. Open the folder for your platform.
3. Copy the `.env.example` / config example file and add your key from **Zixflow → Settings → Developers → API Keys** (or Write Keys for JS/Node).
4. Follow that folder’s README to run the demo.
5. Trigger actions in the UI/CLI and confirm events in the Zixflow dashboard.

## Verification checklist

- [ ] **javascript** — edit `config.js` → open `index.html` → Identify / Track / Page → events appear
- [ ] **react** — `npm i && npm run dev` → Identify / Track / Page → events appear
- [ ] **nodejs** — `npm i && npm start` → script flushes → events appear
- [ ] **react-native / flutter / ios / android** — set API key → Identify / Track / Screen on simulator or emulator
- [ ] Push / location — physical device + your own Firebase/APNs files (never commit secrets)

## Credentials (public-repo safe)

This repo ships **placeholder** config only:

- `.env.example`, `Config.example`, `local.properties.example`
- Sample Firebase / APNs filenames documented in each README

Do **not** commit real write keys, API keys, `google-services.json`, `GoogleService-Info.plist`, keystores, or provisioning profiles.

## What each demo covers

Demos mirror the published docs for that SDK (core identify/track/page|screen, plus group/alias/reset/flush where documented, and optional push and location modules).

## License

MIT — see [LICENSE](./LICENSE).

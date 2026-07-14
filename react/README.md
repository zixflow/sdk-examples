# Zixflow React (Browser) SDK Example

Simple Vite + React + TypeScript demo for [`@zixflow/analytics-browser`](https://www.npmjs.com/package/@zixflow/analytics-browser). Covers core analytics and web push with action buttons.

Docs: [Quick Start](https://docs.zixflow.com/documentation/sdk/javascript/quick-start) · [Core Features](https://docs.zixflow.com/documentation/sdk/javascript/core-features) · [Web Push](https://docs.zixflow.com/documentation/sdk/javascript/web-push-notifications) · [Push Tracking](https://docs.zixflow.com/documentation/sdk/javascript/push-notification-tracking)

## Setup

```bash
cp .env.example .env
# Set VITE_ZIXFLOW_WRITE_KEY (required)

npm install
npm run dev
```

Open the printed local URL (default `http://localhost:5174`). Use HTTPS or localhost for service workers.

## What it shows

| Button | SDK API |
|--------|---------|
| Identify | `analytics.identify(...)` |
| Track | `analytics.track(...)` |
| Page | `analytics.page(...)` |
| Subscribe / Unsubscribe | `subscribeToPush(analytics)` / `unsubscribeFromPush(analytics)` |

Init enables the webPush plugin:

```ts
const [analytics] = await AnalyticsBrowser.load(
  { writeKey },
  {
    webPush: {
      enabled: true,
      swUrl: '/sw.js',
      autoSubscribe: false,
    },
  }
)
```

`public/sw.js` mirrors the JavaScript example worker: parses `action_buttons` into `ACTION_0` / `ACTION_1`, tracks Delivered / Opened / Action Clicked when the plugin posts `SDK_CONFIG`, and opens button or payload deeplinks.

## Verify

1. Click **Identify**, then **Track** / **Page**.
2. Confirm events in the Zixflow dashboard.
3. Click **Subscribe to push**, grant permission, then send a campaign push with `action_buttons`.
4. Click the notification body and each action button; confirm **Opened** / **Action Clicked** metrics.

Example `action_buttons` value:

```json
"[{\"name\":\"Shop Now\",\"deeplink\":\"https://example.com/sale\"},{\"name\":\"Remind Me\",\"deeplink\":\"\"}]"
```

## Notes

- The SDK loads once in `App.tsx` via `AnalyticsBrowser.load`.
- Service worker is served from Vite `public/sw.js` at `/sw.js`.
- For a vanilla (non-React) browser demo, see [`../javascript`](../javascript).

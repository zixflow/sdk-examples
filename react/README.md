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
| Screen | `analytics.screen(...)` |
| Group | `analytics.group(...)` |
| Alias | `analytics.alias(...)` |
| Reset | `analytics.reset()` |
| Subscribe / Unsubscribe | `subscribeToPush(analytics, options)` / `unsubscribeFromPush(analytics, options)` |

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

**`subscribeToPush`/`unsubscribeFromPush` don't inherit the `webPush` config passed to `load()`** — they're
standalone exported functions with their own `options` parameter. If you override `apiHost`/`protocol` for
`load()`, pass the same values to every `subscribeToPush`/`unsubscribeFromPush` call too (see
`webPushHostOptions` in `App.tsx`).

`public/sw.js` mirrors the JavaScript example worker: parses `action_buttons` into `ACTION_0` / `ACTION_1`, tracks Delivered / Opened / Action Clicked when the plugin posts `SDK_CONFIG`, and opens button or payload deeplinks.

### Dev workspace host override

This app's default `.env` key is scoped to the dev workspace, not the production `cdp.zixflow.com` host
(the same environment used by the Android/iOS sample apps) — confirmed via a `401` on the default host and
a `200` after pointing both the CDN/settings fetch and the Zixflow destination at `dev-events.zixflow.in`:

```ts
AnalyticsBrowser.load(
  { writeKey, cdnURL: 'https://dev-events.zixflow.in' },
  { integrations: { Zixflow: { apiHost: 'dev-events.zixflow.in/v1', protocol: 'https' } } }
)
```

If you're using a production-scoped write key, remove `cdnURL` and `integrations.Zixflow` entirely and the
defaults (`cdp.zixflow.com`) will work.

### Known limitations found while testing against the dev backend

- `analytics.group(...)` and `analytics.alias(...)` return `404` on the dev host tested here (identify/
  track/page/screen all return `200` via the identical dispatch path) — this looks like those routes
  aren't deployed on the dev/staging backend yet, not a client-side bug.
- `GET /v1/push/vapid-public-key` also returns `401` on the dev host even with a valid write key and
  granted notification permission — likely the same dev/staging gap. Both are worth confirming with
  whoever owns the backend before relying on them in a dev environment.

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

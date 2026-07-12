# Zixflow JavaScript (Browser) SDK Example

Feature demo for [`@zixflow/analytics-browser`](https://www.npmjs.com/package/@zixflow/analytics-browser) covering core analytics and web push.

Docs: [Quick Start](https://docs.zixflow.com/documentation/sdk/javascript/quick-start) · [Core Features](https://docs.zixflow.com/documentation/sdk/javascript/core-features) · [Web Push](https://docs.zixflow.com/documentation/sdk/javascript/web-push-notifications)

## Setup

```bash
cp .env.example .env
# Set VITE_ZIXFLOW_WRITE_KEY (required)

npm install
npm run dev
```

Open the printed local URL (default `http://localhost:5173`).

## What you can try

| Button | SDK API |
|--------|---------|
| Identify / Track / Page / Screen / Group / Alias / Reset | Core features |
| Ready / User / Set anonymous ID / Toggle debug | Browser helpers |
| Subscribe / Unsubscribe | `subscribeToPush` / `unsubscribeFromPush` |

## Verify

1. Click **Identify**, then **Track** / **Page**.
2. Confirm events in the Zixflow dashboard.
3. For web push: use HTTPS or localhost, grant permission, then Subscribe.

## Notes

- `initialPageview: true` sends a page call on load.
- Prefer the full service worker from `node_modules/@zixflow/analytics-browser` for automatic push tracking beacons; `public/sw.js` is a minimal starter from the docs.

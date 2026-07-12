# Zixflow React (Browser) SDK Example

Simple Vite + React + TypeScript demo for [`@zixflow/analytics-browser`](https://www.npmjs.com/package/@zixflow/analytics-browser).

Docs: [Quick Start](https://docs.zixflow.com/documentation/sdk/javascript/quick-start) · [Core Features](https://docs.zixflow.com/documentation/sdk/javascript/core-features)

## Setup

```bash
cp .env.example .env
# Set VITE_ZIXFLOW_WRITE_KEY (required)

npm install
npm run dev
```

Open the printed local URL (default `http://localhost:5174`).

## What it shows

| Button | SDK API |
|--------|---------|
| Identify | `analytics.identify(...)` |
| Track | `analytics.track(...)` |
| Page | `analytics.page(...)` |

Init matches Quick Start:

```ts
const [analytics] = await AnalyticsBrowser.load({ writeKey })
```

## Verify

1. Click **Identify**, then **Track** / **Page**.
2. Confirm events in the Zixflow dashboard.

## Notes

- The SDK loads once in `App.tsx` via `AnalyticsBrowser.load`.
- For a vanilla (non-React) browser demo, see [`../javascript`](../javascript).

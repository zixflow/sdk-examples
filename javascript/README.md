# Zixflow JavaScript (Browser) SDK Example

Plain HTML/CSS/JS feature demo for [`@zixflow/analytics-browser@1.1.5`](https://cdn.jsdelivr.net/npm/@zixflow/analytics-browser@1.1.5) via jsDelivr UMD (no npm, Vite, or build step). Covers core analytics and web push.

Docs: [Quick Start](https://docs.zixflow.com/documentation/sdk/javascript/quick-start) · [Core Features](https://docs.zixflow.com/documentation/sdk/javascript/core-features) · [Web Push](https://docs.zixflow.com/documentation/sdk/javascript/web-push-notifications) · [Installation](https://docs.zixflow.com/documentation/sdk/javascript/installation)

## Prerequisites

- A Zixflow **write key** from **Settings → Developers → Write Keys**
- Optional: Python 3 if you want web push (`./serve.sh`)

## Setup

1. Edit `config.js` and replace `YOUR_WRITE_KEY` with your write key.
2. Open `index.html` in your browser (double-click or File → Open).

Core identify / track / page works over `file://`. Web push does **not** — browsers block service workers on `file://`. For push:

```bash
cd sdk-examples/javascript
./serve.sh
```

Then open [http://localhost:8080](http://localhost:8080). Optional: `PORT=3000 ./serve.sh`

## What you can try

| Button | SDK API |
|--------|---------|
| Identify / Track / Page / Screen / Group / Alias / Reset | Core features |
| Ready / User / Set anonymous ID / Toggle debug | Browser helpers |
| Subscribe / Unsubscribe | `subscribeToPush(analytics)` / `unsubscribeFromPush(analytics)` |

## Verify

1. Click **Identify**, then **Track** / **Page**.
2. Confirm events in the Zixflow dashboard.
3. For web push: use `./serve.sh`, grant notification permission, then Subscribe.

## Notes

- Loads `https://cdn.jsdelivr.net/npm/@zixflow/analytics-browser@1.1.5/dist/umd/index.js`, then calls `AnalyticsBrowser.load` and `analytics.page()` on load.
- `cdn-path-fix.js` rewrites UMD lazy-chunk URLs from the broken `cdp.zixflow.com/analytics-next/bundles/` path to the jsDelivr UMD folder.
- Web push uses `sw.js` in this folder (minimal starter from the docs).
- For a React + npm demo, see [`../react`](../react).

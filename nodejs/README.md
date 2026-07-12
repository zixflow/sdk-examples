# Zixflow Node.js SDK Example

CLI demo for [`@zixflow/analytics-node`](https://www.npmjs.com/package/@zixflow/analytics-node).

Docs: [Quick Start](https://docs.zixflow.com/documentation/sdk/nodejs/quick-start) · [Core Features](https://docs.zixflow.com/documentation/sdk/nodejs/core-features) · [Node.js-Specific Features](https://docs.zixflow.com/documentation/sdk/nodejs/nodejs-specific-features)

## Setup

```bash
cp .env.example .env
# Set ZIXFLOW_WRITE_KEY

npm install
npm start
```

Requires **Node.js 18+** (`--env-file` support).

## What it sends

1. `identify`
2. `track` (`purchase_completed`)
3. `page` / `screen`
4. `group` / `alias`
5. `closeAndFlush()` (also wired for `SIGTERM` / `SIGINT`)

Listen for `error`, `drained`, and `http_request` emitters in the console.

## Verify

After the script exits successfully, confirm events in the Zixflow dashboard for `user@example.com`.

## Notes

- Every call includes `userId` (or `anonymousId`) — required by the Node SDK.
- There is no `reset()`; pass identity per call.
- Optional `ZIXFLOW_HOST` / `ZIXFLOW_PATH` override the default batch endpoint.

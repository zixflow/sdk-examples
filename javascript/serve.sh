#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
PORT="${PORT:-8080}"
echo "Serving Zixflow JS example at http://localhost:${PORT}"
echo "Edit config.js with your write key, then open the URL above."
exec python3 -m http.server "$PORT"

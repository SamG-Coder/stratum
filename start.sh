#!/usr/bin/env sh
set -eu
cd "$(dirname "$0")"
command -v node >/dev/null 2>&1 || { echo 'Node.js 20 or newer is required.'; exit 1; }
exec node server.mjs --open

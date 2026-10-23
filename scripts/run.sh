#!/bin/bash
# scripts/run.sh — build, stop the running copy and launch the app.
set -euo pipefail
cd "$(dirname "$0")/.."

APP=ClaudeUsageStatus
APP_PATH=.build/DerivedData/Build/Products/Release/$APP.app

scripts/build.sh

# Stop by process name only (-x). Never match the command line: the editor
# and claude running in this folder would match too.
pkill -x "$APP" 2>/dev/null || true
for _ in $(seq 1 20); do pgrep -xq "$APP" || break; sleep 0.25; done

open "$APP_PATH"
for _ in $(seq 1 20); do pgrep -xq "$APP" && break; sleep 0.25; done
pgrep -xq "$APP" || { echo "FAIL: process did not start"; exit 1; }
echo "OK: $APP running, pid $(pgrep -x "$APP")"

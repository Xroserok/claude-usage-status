#!/bin/bash
# scripts/verify-ui.sh — launch the app and check the status item and the
# dropdown through System Events (spec §3). Prints OK or FAIL <reason>.
#
# Needs Accessibility granted to the terminal that runs it (a human step in
# System Settings → Privacy & Security → Accessibility). The status item of
# a menu bar app lives in `menu bar 2` of its process; `menu bar 1` is the
# (empty) main menu.
set -u
cd "$(dirname "$0")/.."

APP=ClaudeUsageStatus
APP_PATH=.build/DerivedData/Build/Products/Release/$APP.app
[ -d "$APP_PATH" ] || { echo "FAIL: $APP_PATH missing, run scripts/build.sh"; exit 1; }

pkill -x "$APP" 2>/dev/null; sleep 0.5
open "$APP_PATH" || { echo "FAIL: open"; exit 1; }
for _ in $(seq 1 20); do pgrep -xq "$APP" && break; sleep 0.25; done
pgrep -xq "$APP" || { echo "FAIL: process not running"; exit 1; }

se() { osascript -e "tell application \"System Events\" to tell process \"$APP\" to $1" 2>&1; }

# Accessibility is a TCC grant, not a code bug: stop with a clear message.
PROBE=$(se 'get background only')
if grep -q 'not allowed assistive access' <<<"$PROBE"; then
  echo "FAIL: Accessibility not granted to this terminal (System Settings → Privacy & Security → Accessibility)"; exit 1
fi
[ "$PROBE" = "true" ] || { echo "FAIL: has a Dock icon (background only=$PROBE)"; exit 1; }

# Title: "31% · 47%" once data arrived; "…" while loading; "⚠︎" / "—" on errors.
# Wait up to 15 s for the first response.
TITLE=""
for _ in $(seq 1 30); do
  TITLE=$(se 'get title of menu bar item 1 of menu bar 2')
  [ "$TITLE" != "…" ] && [ -n "$TITLE" ] && break
  sleep 0.5
done
echo "title=$TITLE"
if [[ ! "$TITLE" =~ ^[0-9]{1,3}%\ ·\ [0-9]{1,3}%$ ]]; then
  case "$TITLE" in
    "⚠︎") echo "FAIL: title ⚠︎ (no token / 401). Sign in to Claude Code; check with usage-probe" ;;
    "—")  echo "FAIL: title — (no data, offline?). Check with usage-probe" ;;
    "…")  echo "FAIL: still loading after 15 s" ;;
    *)    echo "FAIL: title must be 'NN% · NN%', got '$TITLE'" ;;
  esac
  exit 1
fi

se 'click menu bar item 1 of menu bar 2' >/dev/null; sleep 0.5
ITEMS=$(se 'get name of every menu item of menu 1 of menu bar item 1 of menu bar 2')
osascript -e 'tell application "System Events" to key code 53' >/dev/null   # Esc
echo "items=$ITEMS"

for z in "Session" "Week (all models)" "Updated" "Refresh" "Launch at Login" "Quit"; do
  grep -q "$z" <<<"$ITEMS" || { echo "FAIL: missing menu item '$z'"; exit 1; }
done
# No token-like text anywhere in the menu.
grep -Eq 'sk-ant-oat01-[A-Za-z0-9_-]{20,}' <<<"$ITEMS" && { echo "FAIL: token visible in the menu"; exit 1; }

echo "OK"

#!/bin/bash
# scripts/verify-ui.sh — launch the app and check the status item and the
# popover through System Events (spec §3). Prints OK or FAIL <reason>.
#
# Needs Accessibility granted to the terminal that runs it (a human step in
# System Settings → Privacy & Security → Accessibility). The status item of
# a menu bar app lives in `menu bar 2` of its process; the popover opened by
# MenuBarExtra(.window) is `window 1`. Elements are found by accessibility
# identifier (spec §3.3), never by text, so the check is language-independent.
#
#   UI_LANG=ru scripts/verify-ui.sh   launches with -AppleLanguages "(ru)" and
#                                     also requires the Russian strings.
set -u
cd "$(dirname "$0")/.."

APP=YourLimit
APP_PATH=.build/DerivedData/Build/Products/Release/$APP.app
UI_LANG="${UI_LANG:-}"
[ -d "$APP_PATH" ] || { echo "FAIL: $APP_PATH missing, run scripts/build.sh"; exit 1; }

pkill -x "$APP" 2>/dev/null; sleep 0.5
if [ "$UI_LANG" = "ru" ]; then
  open "$APP_PATH" --args -AppleLanguages "(ru)" || { echo "FAIL: open"; exit 1; }
else
  open "$APP_PATH" || { echo "FAIL: open"; exit 1; }
fi
for _ in $(seq 1 20); do pgrep -xq "$APP" && break; sleep 0.25; done
pgrep -xq "$APP" || { echo "FAIL: process not running"; exit 1; }

se() { osascript -e "tell application \"System Events\" to tell process \"$APP\" to $1" 2>&1; }

# Accessibility is a TCC grant, not a code bug: stop with a clear message.
PROBE=$(se 'get background only')
if grep -q 'not allowed assistive access' <<<"$PROBE"; then
  echo "FAIL: Accessibility not granted to this terminal (System Settings → Privacy & Security → Accessibility)"; exit 1
fi
[ "$PROBE" = "true" ] || { echo "FAIL: has a Dock icon (background only=$PROBE)"; exit 1; }

# Status item: "31% · 47%" once data arrived; "…" while loading; "⚠︎" / "—" on
# errors. Wait up to 15 s for the first response. SwiftUI may expose the label
# as title or as description; accept either.
TITLE=""
for _ in $(seq 1 30); do
  TITLE=$(se 'get title of menu bar item 1 of menu bar 2')
  [[ "$TITLE" == *"error"* || -z "$TITLE" || "$TITLE" == "missing value" ]] && TITLE=$(se 'get description of menu bar item 1 of menu bar 2')
  [ "$TITLE" != "…" ] && [ -n "$TITLE" ] && break
  sleep 0.5
done
echo "title=$TITLE"
if [[ ! "$TITLE" =~ ^[0-9]{1,3}%\ ·\ [0-9]{1,3}%$ ]]; then
  case "$TITLE" in
    "⚠︎") echo "FAIL: title ⚠︎ (no token / 401 / Keychain denied). Check with usage-probe" ;;
    "—")  echo "FAIL: title — (no data, offline?). Check with usage-probe" ;;
    "…")  echo "FAIL: still loading after 15 s" ;;
    *)    echo "FAIL: title must be 'NN% · NN%', got '$TITLE'" ;;
  esac
  exit 1
fi

# Open the popover and collect the accessibility identifiers and the texts.
se 'click menu bar item 1 of menu bar 2' >/dev/null; sleep 0.8
IDS=$(osascript <<APPLESCRIPT 2>&1
tell application "System Events" to tell process "$APP"
  set out to ""
  repeat with e in (entire contents of window 1)
    try
      set out to out & (value of attribute "AXIdentifier" of e) & linefeed
    end try
  end repeat
  return out
end tell
APPLESCRIPT
)
TEXTS=$(se 'get value of every static text of window 1')
osascript -e 'tell application "System Events" to key code 53' >/dev/null   # Esc
echo "identifiers=$(tr '\n' ' ' <<<"$IDS")"
echo "texts=$TEXTS"

grep -q 'error' <<<"$IDS" && { echo "FAIL: popover window not found after click ($IDS)"; exit 1; }
for id in limit.session.percent limit.session.bar limit.session.reset \
          limit.weekly_all.percent limit.weekly_all.bar limit.weekly_all.reset \
          updated refresh launchAtLogin quit; do
  grep -qx "$id" <<<"$IDS" || { echo "FAIL: missing accessibility identifier '$id'"; exit 1; }
done
grep -Eq 'sk-ant-oat01-[A-Za-z0-9_-]{20,}' <<<"$TEXTS" && { echo "FAIL: token visible in the popover"; exit 1; }

if [ "$UI_LANG" = "ru" ]; then
  grep -q 'Сессия' <<<"$TEXTS" || { echo "FAIL: Russian strings not shown with -AppleLanguages (ru)"; exit 1; }
fi

echo "OK"

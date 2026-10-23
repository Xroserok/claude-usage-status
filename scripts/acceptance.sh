#!/bin/bash
# scripts/acceptance.sh — spec.md §7 acceptance criteria.
# Automatic: 1, 2, 4, 8, 9, 10. Manual (printed at the end): 3, 5, 6, 7.
set -u
cd "$(dirname "$0")/.."
ROOT=$PWD
APP=YourLimit
APP_PATH=.build/DerivedData/Build/Products/Release/$APP.app
BUNDLE_ID=com.xroserok.yourlimitbar
TOKEN_RE='sk-ant-oat01-[A-Za-z0-9_-]{20,}'
fail=0
ok() { echo "✔ $1"; }
ko() { echo "✘ $1"; fail=1; }

# 1 clean build + tests + lint
CLEAN="${TMPDIR:-/tmp}/cus-clean"
git worktree remove --force "$CLEAN" 2>/dev/null
if git worktree add -q "$CLEAN" HEAD && (cd "$CLEAN" && scripts/build.sh >/dev/null 2>&1); then
  ok "1 clean build from a fresh checkout"
else
  ko "1 clean build from a fresh checkout"
fi
git worktree remove --force "$CLEAN" 2>/dev/null
for PKG in Packages/*/; do
  (cd "$PKG" && swift test >/dev/null 2>&1) && ok "  swift test $(basename "$PKG")" || ko "  swift test $(basename "$PKG")"
done
if [ -f .swiftlint.yml ]; then
  mise x -- swiftlint --quiet --strict >/dev/null 2>&1 && ok "  swiftlint clean" || ko "  swiftlint warnings"
fi
STRAY=$(mdfind "kMDItemFSName == '$APP.app'" 2>/dev/null | grep -v "^$ROOT/.build/" | wc -l | tr -d ' ')
[ "$STRAY" = "0" ] && ok "  no stray $APP.app copies" || ko "  $STRAY stray $APP.app copies outside .build"

# 2 launch, title, no Dock · 4 popover blocks · 10 Russian strings
if OUT=$(scripts/verify-ui.sh); then
  ok "2 launches, 'NN% · NN%' title, no Dock icon"
  ok "4 popover has session, weekly and updated elements"
else
  ko "2/4 verify-ui: $(tail -1 <<<"$OUT")"
fi
if OUT=$(UI_LANG=ru scripts/verify-ui.sh); then
  ok "10 Russian popover with -AppleLanguages (ru)"
else
  ko "10 verify-ui (ru): $(tail -1 <<<"$OUT")"
fi
echo "   compare the title with /usage in Claude Code (manual)"

# 8 token leaks: our preferences, app support, unified log
LEAK=0
for P in "$HOME/Library/Preferences/$BUNDLE_ID.plist" "$HOME/Library/Application Support/$APP"; do
  [ -e "$P" ] && grep -rEq "$TOKEN_RE" "$P" 2>/dev/null && LEAK=1
done
log show --last 15m --predicate "subsystem == \"$BUNDLE_ID\"" 2>/dev/null | grep -Eq "$TOKEN_RE" && LEAK=1
grep -rEq "$TOKEN_RE" --exclude-dir=.git --exclude-dir=.build --exclude-dir=_local . && LEAK=1
[ "$LEAK" = "0" ] && ok "8 no token in prefs, app support, log or repo" || ko "8 token found (see grep above)"

# 9 Quit
osascript -e "tell application \"System Events\" to tell process \"$APP\" to click menu bar item 1 of menu bar 2" >/dev/null 2>&1
sleep 0.3
osascript -e "tell application \"System Events\" to tell process \"$APP\" to click menu item \"Quit\" of menu 1 of menu bar item 1 of menu bar 2" >/dev/null 2>&1
sleep 1
pgrep -xq "$APP" && ko "9 still running after Quit" || ok "9 Quit terminates the process"

echo
echo "Manual: 3 numbers change within 60 s of Claude Code work · 5 Offline then self-recovery ·"
echo "        6 ⚠︎ + 'Sign in to Claude Code' on a missing token, recovery after sign-in · 7 Launch at Login persists"
exit $fail

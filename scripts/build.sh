#!/bin/bash
# scripts/build.sh — build ClaudeUsageStatus.app from the terminal.
#
# Output: .build/DerivedData/Build/Products/Release/ClaudeUsageStatus.app
# The bundle stays where Xcode put it: exactly one copy of the app on disk
# (CLAUDE.md "Hard rules"). Signing is ad hoc and done by xcodebuild itself
# (CODE_SIGN_IDENTITY = "-" in Project.swift); this script only verifies it.
set -euo pipefail
cd "$(dirname "$0")/.."

APP=ClaudeUsageStatus
DERIVED=.build/DerivedData
APP_PATH="$DERIVED/Build/Products/Release/$APP.app"

[ -d "$APP.xcworkspace" ] || mise x -- tuist generate --no-open >/dev/null

xcodebuild -workspace "$APP.xcworkspace" -scheme "$APP" -configuration Release \
  -derivedDataPath "$DERIVED" build 2>&1 | mise x -- xcsift

[ -x "$APP_PATH/Contents/MacOS/$APP" ] || { echo "FAIL: no binary in $APP_PATH (app target has no sources?)"; exit 1; }

codesign --verify --strict "$APP_PATH" 2>/dev/null || { echo "FAIL: signature does not verify"; exit 1; }
codesign -dv "$APP_PATH" 2>&1 | grep -q 'Signature=adhoc' || { echo "FAIL: not ad-hoc signed"; exit 1; }
if codesign -d --entitlements - "$APP_PATH" 2>/dev/null | grep -q '<key>'; then
  echo "FAIL: entitlements present (spec §4.4: none)"; exit 1
fi
/usr/libexec/PlistBuddy -c 'Print :LSUIElement' "$APP_PATH/Contents/Info.plist" 2>/dev/null | grep -q true \
  || { echo "FAIL: LSUIElement is not true"; exit 1; }

echo "OK: $APP_PATH"

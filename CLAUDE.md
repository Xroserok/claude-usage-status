# CLAUDE.md
Full specification: `spec.md` (read before any change). Current iteration plan: `PLAN.md` (appears in lesson 1).
Cross-session notes: `progress.md` (read silently at session start, update on "recap").

## Commands
cd Packages/<Name> && swift test                 # unit tests of one package (UsageDomain | UsageData | UsagePresentation); seconds, no Xcode
for p in Packages/*; do (cd $p && swift test); done   # all packages
swift run --package-path Tools/usage-probe usage-probe   # data layer check: Keychain → endpoint → parsed snapshot (flags come in lesson 1)
mise x -- tuist generate --no-open               # regenerate the Xcode project from Project.swift (never edit the .xcodeproj)
xcodebuild -workspace YourLimit.xcworkspace -scheme YourLimit -configuration Debug build 2>&1 | mise x -- xcsift
pkill -x YourLimit                       # stop the app by process name (never pkill -f: it matches the editor/claude in this folder)
(cd Packages/UsagePresentation && xcodebuild -scheme UsagePresentation -destination 'generic/platform=iOS' build 2>&1 | mise x -- xcsift)   # packages stay iOS/watchOS-buildable (also platform=watchOS)
mise x -- swiftlint                              # lint
scripts/build.sh                                 # Release build → .build/DerivedData/Build/Products/Release/YourLimit.app, checks ad-hoc signature, no entitlements, LSUIElement
scripts/run.sh                                   # build.sh + pkill -x + open; the only way to launch the app (never `open` a second copy)
scripts/verify-ui.sh                             # status item title + popover elements by accessibility identifier via System Events (Accessibility is granted to Terminal); UI_LANG=ru checks the Russian strings; prints OK or FAIL <reason>
scripts/acceptance.sh                            # spec §7 criteria 1, 2, 4, 8, 9, 10 automatically; 3, 5, 6, 7 are listed for a human
/verify                                          # skill: swift test + build.sh + verify-ui.sh, quote the output; use after any UI change

## Hard rules
- The OAuth token is sent only to `https://api.anthropic.com`. Never log it, never put it in an error message,
  never write it to UserDefaults, a file, a fixture or a test name. `grep -rE "sk-ant-oat01-[A-Za-z0-9_-]{20,}" .` must stay empty.
- Read the Keychain item `Claude Code-credentials` only. Never write, update or delete it, never touch `mcpOAuth`,
  never refresh the token. Account name comes from the current user, never hardcoded.
- On 401 / expired token the app shows "Sign in to Claude Code" and keeps polling. No sign-in flow of our own.
- Read the Keychain before every request: the access token lives ~2.5 h. Do not cache it in memory between requests.
- No third-party packages. The macOS app: no App Sandbox, no `.entitlements`, ad-hoc signing only (`codesign -s -`).
- No `sudo`, `launchctl`, `defaults write`, `tccutil`, `security add-/delete-generic-password` from a session.
  A hook blocks them; if one seems necessary, stop and ask.
- Exactly one `YourLimit.app` on disk (the build output); several copies break SMAppService and TCC.
- Only `limits[]` plus the `five_hour` / `seven_day` fallback are read from the response (spec §2.2).
  Unknown fields are ignored, never a decode failure.

## Scope
v1 is spec §1: session % and weekly % in the menu bar; a popover (`MenuBarExtra` `.window`) with a progress bar
per limit coloured by threshold (80 % / 95 %), reset times, Updated line, Refresh, Launch at Login, Quit; English
and Russian. Everything in spec §8 (menu bar colour/icon, notifications, breakdown, settings window, iOS/watchOS)
is out until discussed.
Propose expansions in one sentence and wait; never implement them "while here".
`usage-probe`, tests and `scripts/` are verification infrastructure, not product features.

## Conventions
- Layers: `UsagePresentation → UsageDomain ← UsageData`; the app target is the composition root (`AppCoordinator`).
  Presentation never imports Data. New code goes into the matching package, not into `Apps/`.
- Packages are platform-neutral: no `AppKit`, `UIKit`, `WidgetKit`, `ServiceManagement` imports and no `#if os(...)`
  inside `Packages/`; platform code lives in `Apps/<platform>`. Domain models are `Codable` so a widget or
  complication can read a cached snapshot. The Keychain item exists on the Mac only: other platforms will need
  their own `CredentialsProviding` (spec §8), never a copy of the Mac token.
- Swift 6 language mode in packages; the app target has `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, packages do not.
  Everything public in the packages is `Sendable`.
- Logging through `os.Logger(subsystem: "com.xroserok.yourlimitbar")`, categories `network`, `credentials`, `ui`.
  No `print` in the app. Log messages never include response bodies or headers.
- Tests: Swift Testing, fixtures under `Tests/<Target>Tests/Fixtures`, network via a `URLProtocol` stub, Keychain via
  the in-memory `CredentialsProviding`. Tests never touch the real Keychain or the network.
- Everything committed is in English; no AI attribution lines in commits. UI strings only through the String
  Catalog `Apps/macOS/Resources/Localizable.xcstrings` (en + ru, both filled in the same change); packages return
  values, not sentences. Every popover element carries the accessibility identifier from spec §3.3.
- "Done" means quoted output of `swift test`, `xcsift` or a script, not a sentence.

IMPORTANT: When compacting, preserve the list of modified files and the exact commands above.

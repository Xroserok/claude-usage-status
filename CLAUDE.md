# CLAUDE.md
Full specification: `spec.md` (read before any change). Current iteration plan: `PLAN.md` (appears in lesson 1).
Cross-session notes: `progress.md` (read silently at session start, update on "recap").

## Commands
cd Packages/<Name> && swift test                 # unit tests of one package (UsageDomain | UsageData | UsagePresentation); seconds, no Xcode
for p in Packages/*; do (cd $p && swift test); done   # all packages
swift run --package-path Tools/usage-probe usage-probe   # data layer check: Keychain → endpoint → parsed snapshot (flags come in lesson 1)
mise x -- tuist generate --no-open               # regenerate the Xcode project from Project.swift (never edit the .xcodeproj)
xcodebuild -workspace ClaudeUsageStatus.xcworkspace -scheme ClaudeUsageStatus -configuration Debug build 2>&1 | mise x -- xcsift
pkill -x ClaudeUsageStatus                       # stop the app by process name (never pkill -f: it matches the editor/claude in this folder)
mise x -- swiftlint                              # lint
scripts/build.sh, scripts/run.sh, scripts/verify-ui.sh, scripts/acceptance.sh   # added in lesson 0.5

## Hard rules
- The OAuth token is sent only to `https://api.anthropic.com`. Never log it, never put it in an error message,
  never write it to UserDefaults, a file, a fixture or a test name. `grep -rE "sk-ant-oat01-[A-Za-z0-9_-]{20,}" .` must stay empty.
- Read the Keychain item `Claude Code-credentials` only. Never write, update or delete it, never touch `mcpOAuth`,
  never refresh the token. Account name comes from the current user, never hardcoded.
- On 401 / expired token the app shows "Sign in to Claude Code" and keeps polling. No sign-in flow of our own.
- Read the Keychain before every request: the access token lives ~2.5 h. Do not cache it in memory between requests.
- No third-party packages. No App Sandbox, no `.entitlements`, ad-hoc signing only (`codesign -s -`).
- No `sudo`, `launchctl`, `defaults write`, `tccutil`, `security add-/delete-generic-password` from a session.
  A hook blocks them; if one seems necessary, stop and ask.
- Exactly one `ClaudeUsageStatus.app` on disk (the build output); several copies break SMAppService and TCC.
- Only `limits[]` plus the `five_hour` / `seven_day` fallback are read from the response (spec §2.2).
  Unknown fields are ignored, never a decode failure.

## Scope
v1 is spec §1: session % and weekly % in the menu bar, a dropdown with reset times, Launch at Login, Quit.
Everything in spec §8 (colours, notifications, breakdown, settings window, iOS/watchOS) is out until discussed.
Propose expansions in one sentence and wait; never implement them "while here".
`usage-probe`, tests and `scripts/` are verification infrastructure, not product features.

## Conventions
- Layers: `UsagePresentation → UsageDomain ← UsageData`; the app target is the composition root (`AppCoordinator`).
  Presentation never imports Data. New code goes into the matching package, not into `Apps/`.
- Swift 6 language mode in packages; the app target has `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, packages do not.
  Everything public in the packages is `Sendable`.
- Logging through `os.Logger(subsystem: "com.xroserok.ClaudeUsageStatus")`, categories `network`, `credentials`, `ui`.
  No `print` in the app. Log messages never include response bodies or headers.
- Tests: Swift Testing, fixtures under `Tests/<Target>Tests/Fixtures`, network via a `URLProtocol` stub, Keychain via
  the in-memory `CredentialsProviding`. Tests never touch the real Keychain or the network.
- Everything committed is in English, UI strings in English, no AI attribution lines in commits.
- "Done" means quoted output of `swift test`, `xcsift` or a script, not a sentence.

IMPORTANT: When compacting, preserve the list of modified files and the exact commands above.

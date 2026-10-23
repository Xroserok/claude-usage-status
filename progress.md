# Progress

Cross-session memory. Read silently at session start; update on "recap".

## Status (2026-10-23)

Lesson 0 (harness) complete, spec §6 questions answered (2026-10-23), repository renamed to
`Xroserok/yourlimit`, app target `YourLimit`. No app code yet. Next: lesson 1, `PLAN.md` from
`spec.md` in plan mode. The local folder is still `claude_usage_status`; rename it to `yourlimit`
outside a Claude Code session (the folder name keys Claude Code's per-project memory).

## Done

- 0.1 Tools pinned with mise: Tuist 4.212.0, SwiftLint 0.65.1, lefthook 2.2.2, xcsift 1.7.0. jq and
  `swift format` come with macOS / Xcode.
- 0.2 Skeleton: local packages `UsageDomain`, `UsageData`, `UsagePresentation` (Swift 6, macOS 14 /
  iOS 17 / watchOS 10), `Tools/usage-probe` placeholder, Tuist `Project.swift` for the macOS app
  target with an explicit Info.plist (no `NSMainStoryboardFile`). All packages pass `swift test`
  and build for iOS and watchOS.
- 0.3 `CLAUDE.md`: commands, hard rules, scope, conventions, compaction note.
- 0.4 Hooks: `guard-bash.sh`, `guard-files.sh`, `format.sh`, `stop-gate.sh` (swift test of the
  packages, ~6 s). 25 simulated tool calls pass.
- 0.5 Oracles: `scripts/build.sh`, `run.sh`, `verify-ui.sh`, `acceptance.sh`; skill `/verify`
  (human-invoked only); `reviewer` agent.
- 0.6 `.swiftlint.yml`, `lefthook.yml`, GitHub Actions CI, README, this file.

## Decisions

- MVVM-C with a coordinator per platform; view models live in `UsagePresentation` and know
  nothing about the platform (future iOS widget and watchOS complication).
- The built app stays in `.build/DerivedData/Build/Products/Release/`; one copy on disk.
- Name YourLimit (no "Claude" in app, bundle or repo), bundle ID `com.xroserok.yourlimitbar`.
- `MenuBarExtra` `.window`: popover with progress bars coloured by local thresholds 80 % / 95 %.
- English + Russian from v1 through a String Catalog; UI checks go by accessibility identifiers.
- Keychain "Deny" is its own state with Retry; Launch at Login off by default.

## Known issues / open

- Hooks match some rules by substring (`pkill -f`, `launchctl`): a commit message containing them
  is blocked; reword the message rather than weakening the rule.
- `verify-ui.sh` reads the status item through `menu bar 2` and the popover through `window 1` +
  `AXIdentifier`; written blind for SwiftUI `MenuBarExtra(.window)`, to be confirmed at the first
  UI step of lesson 1 and adjusted if the attributes differ.

# Progress

Cross-session memory. Read silently at session start; update on "recap".

## Status (2026-10-23)

Lesson 0 (harness) complete. No app code yet. Next: lesson 1, `PLAN.md` from `spec.md` in plan mode.

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
- Bundle ID `com.xroserok.ClaudeUsageStatus` (spec §6 still lists it as a question).

## Known issues / open

- Hooks match some rules by substring (`pkill -f`, `launchctl`): a commit message containing them
  is blocked; reword the message rather than weakening the rule.
- The `menu bar 2` / `title` path in `verify-ui.sh` is written for `NSStatusItem`; confirm it also
  holds for SwiftUI `MenuBarExtra` at lesson 1 and adjust the script if the attribute differs.
- Spec §6 open questions (app name vs trademark, `.menu` vs `.window`) are unanswered.

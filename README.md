# YourLimit

A macOS menu bar app that shows how much of your Claude subscription limits you have used:
the 5-hour session and the weekly window, as two percentages next to the clock. A click opens
a popover with a progress bar per limit, coloured at 80 % and 95 %, and the reset times.
English and Russian.

```
31% · 47%
```

Status: **in development** (harness and skeleton ready, app code next). See [`spec.md`](spec.md)
for the full specification and [`progress.md`](progress.md) for where things stand.

## How it works

Claude Code stores an OAuth token in the macOS Keychain after you sign in. The app reads that
token and calls the same usage endpoint the `/usage` command in Claude Code uses. Nothing else:
no account of its own, no third-party dependencies, no telemetry. The token is sent to
`api.anthropic.com` only and is never written anywhere.

The endpoint is undocumented and may change; the app degrades to `⚠︎` / `—` in the menu bar
instead of crashing.

## Requirements

- macOS 14 or later, Apple silicon or Intel
- Claude Code installed and signed in (Pro or Max subscription)
- To build: Xcode 16+, [mise](https://mise.jdx.dev) (`mise install` fetches Tuist, SwiftLint, lefthook, xcsift)

## Build and run

```sh
mise install
scripts/run.sh            # generate the Xcode project, build, sign ad hoc, launch
scripts/verify-ui.sh      # check the status item and the popover through System Events
scripts/acceptance.sh     # acceptance criteria from spec §7
```

## Project layout

```
Packages/UsageDomain         models and protocols (Foundation only)
Packages/UsageData           URLSession client, Keychain reader
Packages/UsagePresentation   view models and formatting (platform-free)
Apps/macOS                   menu bar app: SwiftUI MenuBarExtra popover + coordinator, String Catalog
Tools/usage-probe            CLI that exercises the data layer without the app
scripts/                     build, run and verification scripts
.claude/                     Claude Code hooks, skills and agents used to develop this repo
```

Architecture: MVVM-C with a layered split, each layer a local Swift package built with Swift 6
strict concurrency. The packages also compile for iOS and watchOS for a future widget and
complication.

## Development harness

The repository is developed with Claude Code and carries its guard rails: `CLAUDE.md` holds the
rules, `.claude/hooks` enforce them (no privilege escalation, no Keychain writes, no third-party
packages, no token in any file, tests must be green before a turn ends), and `scripts/` are the
oracles that turn "it works" into a quoted `OK`.

## License

MIT

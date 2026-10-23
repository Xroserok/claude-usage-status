# YourLimit — Specification

A macOS menu bar app that permanently shows how much of your Claude subscription
limits you have used: the current 5-hour session and the weekly window.

- **Status:** harness ready, no app code yet
- **Date:** 2026-10-21, decisions of §6 added 2026-10-23
- **Target machine:** macOS 27.0 (build 26A428), Xcode 27.1, Swift 6.4
- **User account:** Max subscription (`rateLimitTier = default_claude_max_5x`)
- **Purpose:** personal tool and portfolio project (public repository)

---

## 1. Goal

A resident menu bar app that shows two numbers without any extra action:
the percentage used of the 5-hour session and of the weekly limit. On click it
opens a popover with the details: a progress bar per limit, coloured by
threshold, when each window resets, and the separate per-model limits.

This is what `/usage` in Claude Code shows, but always visible and without
opening a terminal. The interface is localised in English and Russian.

Explicitly **out of scope** for v1: notifications, charts and history,
breakdown by product (Claude Code / Chats / Cowork), extra usage and money,
a settings window, multiple accounts, API-key support (subscription only),
any colour or icon in the menu bar itself. All of it lives in the backlog
(§8), not in v1.

---

## 2. Where the data comes from

There is no public API for subscription limits. Claude Code fetches them for
`/usage` from an undocumented endpoint, and we do the same.

### 2.1. Endpoint

```
GET https://api.anthropic.com/api/oauth/usage
Authorization: Bearer <accessToken>
anthropic-beta: oauth-2025-04-20
```

Verified on the target machine on 2026-10-21: HTTP 200, JSON. Full response
(only the `null` service fields with code names are trimmed):

```json
{
  "five_hour": { "utilization": 31.0, "resets_at": "2026-10-21T12:00:00.129522+00:00",
                 "limit_dollars": null, "used_dollars": null, "remaining_dollars": null,
                 "locked_reason": null },
  "seven_day": { "utilization": 47.0, "resets_at": "2026-10-21T15:00:00.129539+00:00", "...": null },
  "seven_day_opus": null, "seven_day_sonnet": null, "seven_day_oauth_apps": null,
  "iguana_necktie": { "utilization": 0.0, "resets_at": "2026-11-05T07:59:00+00:00",
                      "limit_dollars": 250, "used_dollars": 0.0, "remaining_dollars": 250.0 },
  "extra_usage": { "is_enabled": false, "monthly_limit": 0, "used_credits": 0.0, "currency": "EUR", "...": "..." },
  "limits": [
    { "kind": "session",       "group": "session", "percent": 31, "severity": "normal",
      "resets_at": "2026-10-21T12:00:00.129522+00:00", "scope": null, "is_active": false },
    { "kind": "weekly_all",    "group": "weekly",  "percent": 47, "severity": "normal",
      "resets_at": "2026-10-21T15:00:00.129539+00:00", "scope": null, "is_active": false },
    { "kind": "weekly_scoped", "group": "weekly",  "percent": 56, "severity": "normal",
      "resets_at": "2026-10-21T15:00:00.129678+00:00",
      "scope": { "model": { "id": null, "display_name": "Fable" }, "surface": null }, "is_active": true }
  ],
  "spend": { "...": "..." },
  "seven_day_breakdown": {
    "as_of": "2026-10-21T08:07:38.164410+00:00",
    "window_started_at": "2026-10-14T15:00:00.129539+00:00",
    "rows": [ { "key": "claude_code", "display_name": "Claude Code", "percent": 27 },
              { "key": "chat", "display_name": "Chats", "percent": 12 },
              { "key": "cowork", "display_name": "Cowork", "percent": 58 },
              { "key": "other", "display_name": "Other", "percent": 3 } ]
  },
  "weekly_scoped_shares": [ { "limit_index": 2, "used_percent_of_weekly": 28, "allowance_percent_of_weekly": 50 } ]
}
```

### 2.2. What we use from the response

The source of truth for v1 is the **`limits`** array. The server already
normalises it, and it carries everything the menu bar and the popover need:

| Field | Type | Usage |
|---|---|---|
| `kind` | string | `session` → menu bar (first number); `weekly_all` → menu bar (second number); `weekly_scoped` → separate rows in the menu (per model) |
| `percent` | integer 0–100 | shown as is |
| `resets_at` | ISO 8601 with fractional seconds and offset | "resets in 3h 52m" / "at 15:00" |
| `severity` | string, only `normal` observed | parsed and kept; v1 colours bars by local thresholds (§3.2) because the other values are unknown |
| `scope.model.display_name` | string or absent | label for `weekly_scoped` ("Fable") |
| `is_active` | bool | unused in v1 |

`five_hour` / `seven_day` are the fallback source if `limits` is missing or
empty: `utilization` → percent, `resets_at` → reset.

Everything else (`extra_usage`, `spend`, `seven_day_breakdown`, code-named
fields such as `iguana_necktie`) is **ignored** in v1. Decodable models declare
only the keys we need; unknown keys and unexpected `null`s must not break
parsing.

### 2.3. Token

The token lives in the macOS Keychain; Claude Code stores it there on login:

| Attribute | Value |
|---|---|
| Class | generic password (`kSecClassGenericPassword`) |
| Service (`svce`) | `Claude Code-credentials` |
| Account (`acct`) | the macOS user name — **never hardcode**, look up by service only |
| Keychain | `~/Library/Keychains/login.keychain-db` |

The value is JSON. The part we need is the `claudeAiOauth` object; the rest
(for example `mcpOAuth.*` with MCP server tokens) must be neither read nor kept.

```
claudeAiOauth.accessToken             string — sent in Authorization
claudeAiOauth.refreshToken            string — NOT used
claudeAiOauth.expiresAt               int, unix time in milliseconds
claudeAiOauth.refreshTokenExpiresAt   int, unix time in milliseconds
claudeAiOauth.scopes                  array of strings
claudeAiOauth.subscriptionType        string, "max" for this user
claudeAiOauth.rateLimitTier           string, "default_claude_max_5x"
```

Important observations:

- **The access token is short-lived** — at the time of the check `expiresAt`
  was about 2.5 hours ahead. Claude Code refreshes it itself and overwrites the
  Keychain item. Therefore the token **must not be cached in memory** for long:
  re-read the Keychain before every request.
- **We never refresh.** Refreshing ourselves could desynchronise the Keychain
  from Claude Code (it does not expect anyone else to rotate its refresh token).
  When `expiresAt` is in the past or the server returns HTTP 401, show the
  "sign in to Claude Code" state and wait for the item to be updated.
- On first access macOS asks for permission to read the item
  ("YourLimit wants to use your confidential information"). The user
  picks "Always Allow". With ad-hoc signing the app identity changes on every
  rebuild and the prompt repeats — a known inconvenience of dev builds, see §5.

### 2.4. Request policy

- Poll on a timer every **60 seconds** while the app runs.
- Additionally on menu open and on wake from sleep
  (`NSWorkspace.didWakeNotification`), but never more than one request per
  10 seconds.
- Network timeout 15 seconds. On error show the last known values with the
  time of the last successful update; the next attempt is on the timer, no
  exponential retries in v1.
- Check `expiresAt` before the request: if the token has already expired, skip
  the request and go straight to the "sign in required" state.
- Do not spoof the `User-Agent` as Claude Code; send an honest
  `YourLimit/<version>`.

### 2.5. Privacy

- The token is sent **only** to `https://api.anthropic.com`. The host is fixed
  in code and not configurable.
- The token is never logged, never written to UserDefaults or files, never
  included in error descriptions. Logs carry only the HTTP status and the
  error type.
- No telemetry and no third-party network requests.

---

## 3. What to show

### 3.1. Menu bar

Two percentages separated by a middle dot: `31% · 47%`.
First is the session (5h), second is the week (all models). Monospaced digits
so the width does not jitter. No icon and no colour in the menu bar in v1.

States shown instead of numbers:

| State | Menu bar |
|---|---|
| No data yet (first launch) | `…` |
| No token / expired / 401 | `⚠︎` |
| Keychain access denied by the user | `⚠︎` |
| Network down, stale data available | the numbers as they are (details in the popover) |
| Network down, no data ever | `—` |

### 3.2. Popover

`MenuBarExtra` with the `.window` style: a click on the status item opens a
SwiftUI popover, a click outside or Esc closes it. Fixed width, height from
content.

```
Session                              31%
████████████░░░░░░░░░░░░░░░░░░░░░░░░░░
resets in 3h 52m

Week (all models)                    47%
██████████████████░░░░░░░░░░░░░░░░░░░░
resets Tue 15:00

Week · Fable                         56%
█████████████████████░░░░░░░░░░░░░░░░░
resets Tue 15:00
────────────────────────────────────────
Updated 14:08
────────────────────────────────────────
Refresh ⌘R        Launch at Login ☐        Quit ⌘Q
```

- One block per limit from `limits[]`: title, percentage, bar, reset line.
  One `weekly_scoped` block per model present in the response; none if absent.
- Bar colour by local thresholds, the same for every limit:
  below 80 % the accent colour, 80–94 % orange, 95 % and above red. The
  thresholds are constants in `UsagePresentation` and covered by unit tests;
  `severity` from the response is not used for colour in v1 (§2.2).
- Reset as "in N h M min" when less than 24 hours away, otherwise weekday and
  time in the local time zone, through Foundation formatters.
- "Updated" is the time of the last **successful** response. On error a line
  with the reason follows it: `Offline`, `Sign in to Claude Code`,
  `Keychain access denied` (with a Retry button that reads the Keychain
  again and so re-triggers the system dialog), `HTTP 500`.
- Buttons: Refresh (⌘R), Launch at Login toggle, Quit (⌘Q). The shortcuts
  work while the popover is open.

### 3.3. Localisation

English and Russian from v1. All user-facing strings live in one String
Catalog, `Apps/macOS/Resources/Localizable.xcstrings`; the language follows
the system. `UsagePresentation` exposes values (`Int`, `Duration`, `Date`,
threshold level), never finished sentences; the app target turns them into
localised text, and formatting tests pass an explicit `Locale`.

Every element of the popover and the status item carries a stable
accessibility identifier, which is what `scripts/verify-ui.sh` reads, so the
check does not depend on the language:

| Identifier | Element |
|---|---|
| `statusItem` | menu bar text |
| `limit.<kind>.title`, `.percent`, `.bar`, `.reset` | one block per limit; `<kind>` is `session`, `weekly_all` or `weekly_scoped.<model>` |
| `updated`, `error` | status lines |
| `refresh`, `launchAtLogin`, `quit`, `retry` | controls |

Russian strings of the popover:

| English | Russian |
|---|---|
| Session | Сессия |
| Week (all models) | Неделя (все модели) |
| Week · Fable | Неделя · Fable |
| resets in 3h 52m | сброс через 3 ч 52 мин |
| resets Tue 15:00 | сброс вт 15:00 |
| Updated 14:08 | Обновлено 14:08 |
| Offline | Нет сети |
| Sign in to Claude Code | Войдите в Claude Code |
| Keychain access denied | Нет доступа к Связке ключей |
| Retry | Повторить |
| Refresh | Обновить |
| Launch at Login | Запускать при входе |
| Quit | Выйти |

### 3.4. App behaviour

- No Dock icon, no main window (`LSUIElement = true`).
- Launch at login via `SMAppService.mainApp` (macOS 13+), **off** by default.
  If registration fails (typical for ad-hoc signing) — show the error in the
  popover, never crash.
- Reading the Keychain item of another app shows a system dialog on first
  access; with ad-hoc signing "Always Allow" is forgotten after every rebuild.
  "Deny" (`errSecAuthFailed` / `errSecUserCanceled`) is a separate state
  (§3.1, §3.2), not "no token".
- Leaves nothing behind on logout or `Quit`.

---

## 4. Architecture

### 4.1. Project layout

The project is generated by **Tuist** (as in `xros_bill_splitter`): the
macOS/iOS job market expects a regular Xcode project, and Tuist is the most
common way to describe it as code and keep it modular. The `.xcodeproj` itself
is not committed. From the terminal it builds with `tuist generate` +
`xcodebuild`, which lets Claude Code build and test without the GUI.

All logic lives in **local Swift packages**, one per layer. They build and
test with plain `swift test` in seconds, without Xcode, which is what the
harness stop-gate runs. The app target is a thin platform shell.

```
Project.swift                      Tuist: the app target, links the packages
Tuist.swift
.swiftlint.yml
Packages/
  UsageDomain/                     models + protocols, Foundation only
    Sources/UsageDomain/           UsageSnapshot, UsageLimit, UsageError,
                                   UsageRepository, CredentialsProviding
    Tests/UsageDomainTests/
  UsageData/                       implementations of the domain protocols
    Sources/UsageData/             UsageClient (URLSession), KeychainCredentialsStore,
                                   DTOs for the JSON in §2.1 + mapping
    Tests/UsageDataTests/          200 / 401 / 500 / timeout via a URLProtocol stub,
      Fixtures/usage_2026-10-21.json   Keychain JSON parsing, expired token
  UsagePresentation/               view models + formatting, no navigation
    Sources/UsagePresentation/     UsageStore (@Observable), UsageFormatter, Threshold
    Tests/UsagePresentationTests/  "31% · 47%", reset values, threshold levels, state transitions
Apps/
  macOS/                           app target YourLimit
    Sources/                       @main + MenuBarExtra(.window), PopoverView, LimitRow,
                                   AppCoordinator, LaunchAtLogin (SMAppService)
    Resources/                     Assets.xcassets, Localizable.xcstrings (en, ru)
Tools/
  usage-probe/                     verification CLI (depends on UsageData)
scripts/
  build.sh                         tuist generate + xcodebuild + ad-hoc signing
  run.sh                           build and relaunch the app
spec.md  CLAUDE.md  progress.md  README.md
```

Module names are prefixed (`UsageData`, not `Data`) because `Data` would
shadow `Foundation.Data` in every file that imports it.

Package dependency graph (arrows = "depends on"):

```
UsagePresentation ──▶ UsageDomain ◀── UsageData
        ▲                                ▲
        └──────── Apps/macOS ────────────┘        (composition root)
                  Tools/usage-probe ─────┘
```

`UsagePresentation` never imports `UsageData`: the app target creates the
concrete `UsageClient` and `KeychainCredentialsStore` and hands them to the
store through the domain protocols. Packages declare macOS 14, iOS 17 and
watchOS 10 so the same code can later back an iOS widget or a watchOS
complication (§8); only `Apps/macOS` exists in v1.

Tuist targets: `YourLimit` (app, macOS). Unit tests run through the
packages (`swift test`); no UI tests in v1.

### 4.2. Pattern: MVVM-C with layers

Decided on 2026-10-22: **MVVM + Coordinator** on the app side plus a layered
split (Presentation → Domain → Data). TCA and "pure" MV were considered and
rejected: for this app the value is a clean, testable core, not the number
of abstractions. Clean Architecture use cases are not introduced until a
second consumer of the domain needs them.

Why the Coordinator already in v1: the view models must not know whether
they live in a macOS menu, an iOS widget or a watchOS complication.
Navigation and dependency wiring are platform-specific, so each app target
gets its own coordinator while `UsagePresentation` stays shared. On macOS
the coordinator is small: it builds the object graph, owns the refresh
triggers (timer, menu open, wake) and later opens the settings window.

```
Apps/macOS
  AppCoordinator                 composition root, refresh triggers, windows
        ↓ creates & owns
  View (SwiftUI, MenuBarExtra)   PopoverView — renders state only
        ↓ observes
UsagePresentation
  ViewModel (@Observable)        UsageStore — screen state, formatting
        ↓ calls through protocols
UsageDomain                      UsageSnapshot, UsageLimit, UsageError,
                                 UsageRepository, CredentialsProviding
        ↑ implemented by
UsageData                        UsageClient → URLSession,
                                 KeychainCredentialsStore → Security
```

- `UsageDomain` and `UsageData` do not import SwiftUI/AppKit and know
  nothing about timers.
- The View never touches `UsageData` directly, only `UsageStore`.
- `UsageClient` takes a `URLSession` (or a loader protocol) and a
  `CredentialsProviding` through its initialiser — for substitution in tests.
- `CredentialsProviding` has two implementations: Keychain and in-memory for
  tests.
- All public package types are `Sendable`; everything builds with Swift 6
  strict concurrency. The app target sets `SWIFT_DEFAULT_ACTOR_ISOLATION =
  MainActor`; the packages do not.

### 4.3. Platform and tooling

| What | Decision |
|---|---|
| Minimum macOS | 14 (Sonoma): `MenuBarExtra` + Observation (`@Observable`) |
| Swift | 6, strict concurrency |
| UI | SwiftUI `MenuBarExtra` with the `.window` style (popover with progress bars) |
| Localisation | String Catalog, English base + Russian; accessibility identifiers for UI checks |
| Keychain | `SecItemCopyMatching` directly, no third-party wrappers |
| Networking | `URLSession`, `async/await` |
| Dependencies | no third-party packages in v1 |
| Linter | SwiftLint, config ported from `xros_bill_splitter` |
| Tests | Swift Testing (`import Testing`) inside each package, fixture with the real JSON |
| CI | GitHub Actions on `macos-latest`: `swift test` per package, `tuist generate` + `xcodebuild build`, `swiftlint` |

### 4.4. Build and signing

For personal use: ad-hoc signing (`codesign -s -`), App Sandbox **off**
(in the sandbox reading another app's Keychain item works only with a prompt
anyway, and ad-hoc + sandbox adds entitlement trouble; not needed in v1).
Notarisation and Developer ID are out of v1: there is no Apple Developer
account.

---

## 5. Limits and risks

- **The endpoint is unofficial.** Anthropic may change the format or remove it
  without notice. Mitigation: parse leniently, keep the fixture, and on an
  unknown format show `—` plus the error in the menu rather than crash.
- **Dependency on Claude Code.** Without Claude Code installed and signed in
  the app is useless — it cannot sign in by itself. This is deliberate: our
  own OAuth flow would mean storing a client_id and rotating the refresh
  token, which is both harder and riskier.
- **The token is full account access.** Any leak into logs or a third-party
  host is unacceptable; see §2.5. The same reason rules out third-party
  networking libraries.
- **Ad-hoc signing** breaks "Always Allow" in the Keychain on every rebuild and
  may break `SMAppService`. For daily use it is enough to rebuild rarely; public
  releases need a Developer ID.
- **Subscription only.** API keys (`sk-ant-…`) and organisations billed per
  token are not served by this endpoint.

---

## 6. Decisions (2026-10-23)

Answers to the questions that were open in the first version of this spec.

1. UI language: **English and Russian** from v1 (§3.3).
2. Name: **YourLimit**; the word "Claude" stays out of the app name, bundle and
   repository (trademark). Repository `Xroserok/yourlimit`. The three packages
   keep their domain names (`UsageDomain`, `UsageData`, `UsagePresentation`).
3. Bundle ID: **`com.xroserok.yourlimitbar`**; also the `os.Logger` subsystem.
4. `MenuBarExtra` style: **`.window`**, because v1 shows progress bars with
   threshold colours (§3.2).
5. Keychain "Deny" is its own state with a Retry button (§3.4); it is not
   reported as "Sign in to Claude Code".
6. Launch at Login is off by default.

---

## 7. Acceptance criteria for v1

1. `scripts/build.sh` from a clean clone builds `YourLimit.app` with no
   errors; `xcodebuild test` is green; SwiftLint reports no warnings.
2. The app launches, the menu bar shows two percentages matching the output of
   `/usage` in Claude Code; there is no Dock icon.
3. Within 60 seconds of active work in Claude Code the numbers change without
   restarting the app.
4. The popover shows the session, the week, per-model blocks and the update
   time; the reset is computed correctly (check against `resets_at`); bar
   colours switch at 80 % and 95 % (unit tests on the threshold function).
5. With the network off the popover shows "Offline", the numbers stay as they
   were, and after the network is back they update by themselves.
6. With the Keychain item removed (or the token expired) the menu bar shows
   `⚠︎` and the popover says "Sign in to Claude Code"; after `claude` → sign in
   everything recovers without restarting the app. "Deny" in the Keychain
   dialog shows "Keychain access denied" and Retry re-opens the dialog.
7. The launch-at-login checkbox toggles and persists across restarts.
8. The token appears nowhere in logs, UserDefaults or files (grep over
   `~/Library` after a working session).
9. "Quit" terminates the process completely.
10. Launched with `-AppleLanguages "(ru)"` the popover is in Russian; the
    identifiers from §3.3 are present in both languages (`scripts/verify-ui.sh`).

---

## 8. Backlog (after v1)

- Colour or icon in the menu bar itself; colour by `severity` once its values are known.
- System notifications at thresholds and on window reset.
- Weekly breakdown by product (`seven_day_breakdown`).
- Extra usage and `spend` (money) once enabled.
- Settings window: polling interval, thresholds, menu bar format (opened by
  the existing `AppCoordinator`).
- iOS companion app with a home-screen widget and a watchOS complication,
  reusing the three packages; each platform gets its own app target and
  coordinator. Clean Architecture use cases only if the domain grows beyond
  "fetch a snapshot".
- Notarised DMG, Homebrew cask, GitHub Releases on tag.
- Codex / other providers in the same menu bar item (as competitors do).

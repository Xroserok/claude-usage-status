# PLAN.md — YourLimit v1 (lesson 1)

Scope is spec §1 exactly. Each step ends with its oracle: the command and what its output must
show. A step is done only when the oracle output is quoted. Steps are small enough for one
commit each; the stop-gate (`swift test` of all packages) runs at the end of every turn.

Conventions that apply to every step: Swift 6 strict concurrency, everything public `Sendable`,
no AppKit/SwiftUI/`#if os` in `Packages/`, UI strings only through the String Catalog, every
popover element carries its spec §3.3 identifier, the token never appears in code, fixtures,
logs or test names (`grep -rE "sk-ant-oat01-[A-Za-z0-9_-]{20,}" .` stays empty).

## Decisions taken while planning (2026-10-23)

1. Keychain "Deny" pauses Keychain reads: the 60 s timer keeps ticking but skips the read until
   Retry is pressed or the app restarts. 401 / expired / network errors keep polling as spec §2.4.
2. Clock format follows the system locale through Foundation `FormatStyle` (en_US shows
   "Tue 3:00 PM"); tests pass `Locale(identifier: "en_GB")` and `"ru_RU"` explicitly.
3. Unknown `kind` in `limits[]` is parsed (no decode failure), hidden from the popover and logged
   as the kind string only (`network` category).
4. `scripts/acceptance.sh` criterion 9 is fixed to click the `quit` button of `window 1`
   (`.window` style has no menu items). Agreed with the owner; harness, not product.

## Implementation order

### 1. Fixtures (UsageData tests)
- `Packages/UsageData/Tests/UsageDataTests/Fixtures/usage_2026-10-21.json`: the response from
  spec §2.1 with the `null` service fields restored, no token anywhere.
- `Fixtures/usage_no_limits.json`: same but without `limits` (fallback case).
- `Fixtures/credentials.json`: the Keychain value shape from spec §2.3 with a fake token
  `"test-access-token"` (does not match the token regex) and an `mcpOAuth` object that must be ignored.
- Oracle: `cd Packages/UsageData && swift test` → `Test run with N test(s) passed` (smoke test
  still green; fixtures load via `Bundle.module`), and
  `grep -rE "sk-ant-oat01-[A-Za-z0-9_-]{20,}" .` → no output.

### 2. UsageDomain models and protocols
- `UsageLimit` (`kind: LimitKind`, `percent: Int`, `resetsAt: Date`, `severity: String`,
  `modelName: String?`); `LimitKind` = `.session`, `.weeklyAll`, `.weeklyScoped`, `.unknown(String)`.
- `UsageSnapshot` (`limits: [UsageLimit]`, `fetchedAt: Date`) with `session` / `weeklyAll` /
  `weeklyScoped` accessors.
- `Credentials` (`accessToken: String`, `expiresAt: Date`) with `isExpired(now:)`;
  `CustomStringConvertible` redacts the token.
- `UsageError`: `.noCredentials`, `.credentialsDenied`, `.tokenExpired`, `.unauthorized`,
  `.offline`, `.timeout`, `.http(Int)`, `.malformed`. No associated strings, so nothing can carry a token.
- Protocols: `CredentialsProviding` (`func credentials() async throws -> Credentials`),
  `UsageRepository` (`func fetch() async throws -> UsageSnapshot`). All `Sendable`, models `Codable`.
- Tests: `Codable` round-trip of a snapshot, `LimitKind` raw mapping incl. unknown,
  `isExpired` at the boundary, `description` of `Credentials` contains no token.
- Oracle: `cd Packages/UsageDomain && swift test` → passed; and
  `(cd Packages/UsageDomain && xcodebuild -scheme UsageDomain -destination 'generic/platform=watchOS' build 2>&1 | mise x -- xcsift)` → `Build succeeded`.

### 3. UsageData DTOs and mapping
- `UsageResponseDTO` decodes only `limits[]` (`kind`, `percent`, `severity`, `resets_at`,
  `scope.model.display_name`, `scope.model.id`) and `five_hour` / `seven_day`
  (`utilization`, `resets_at`). Every field optional; a limit missing `percent` or `resets_at` is dropped.
- `resets_at` parsed with `Date.ISO8601FormatStyle(includingFractionalSeconds: true)` and a
  fallback without fraction; 6-digit fractions must parse.
- `SnapshotMapper`: `limits[]` → `[UsageLimit]`; if `limits` is missing or empty, build `session`
  and `weekly_all` from `five_hour` / `seven_day` (`utilization` rounded to `Int`); unknown kinds
  kept as `.unknown(raw)`; `percent` clamped to 0…100 for the bar but kept raw in the model.
- Tests (fixtures of step 1): three limits with the right kinds, "Fable" label, dates to the
  microsecond; fallback file gives two limits; JSON with extra keys / `null`s / unknown kind decodes;
  garbage JSON → `.malformed`.
- Oracle: `cd Packages/UsageData && swift test` → passed, test names list the four cases.

### 4. UsageData KeychainCredentialsStore
- Query: `kSecClassGenericPassword`, `kSecAttrService = "Claude Code-credentials"`, no account,
  `kSecMatchLimitOne`, `kSecReturnData`. Read on every call, nothing cached.
- `CredentialsParser.parse(_ data: Data) throws -> Credentials` decodes only
  `claudeAiOauth.accessToken` and `claudeAiOauth.expiresAt` (ms → `Date`); `refreshToken` and
  `mcpOAuth` are never read into a model.
- `OSStatus` mapping: `errSecItemNotFound` → `.noCredentials`; `errSecAuthFailed`,
  `errSecUserCanceled`, `errSecInteractionNotAllowed` → `.credentialsDenied`; anything else →
  `.noCredentials` logged with the status code (`credentials` category).
- The `SecItemCopyMatching` call runs off the main actor (it blocks while the system dialog is up).
- Tests cover the parser (fixture `credentials.json`, missing `claudeAiOauth`, non-JSON) and the
  status mapping through an injected `(CFDictionary) -> (OSStatus, Data?)` function; the real
  Keychain is never touched.
- Oracle: `cd Packages/UsageData && swift test` → passed; `grep -rn "mcpOAuth\|refreshToken" Packages/UsageData/Sources` → no output.

### 5. UsageData UsageClient + usage-probe
- `UsageClient(session: URLSession, credentials: CredentialsProviding, userAgent: String)`.
  Host literal `https://api.anthropic.com/api/oauth/usage`; headers `Authorization: Bearer`,
  `anthropic-beta: oauth-2025-04-20`, `User-Agent`. Timeout 15 s via the session configuration.
- `fetch()`: read credentials → if expired throw `.tokenExpired` without a request → request →
  401 → `.unauthorized`; 5xx/4xx → `.http(code)`; `URLError.notConnectedToInternet` etc. →
  `.offline`; `.timedOut` → `.timeout`; decode errors → `.malformed`. Logs status and error type only.
- Tests with a `URLProtocol` stub: 200 fixture → snapshot; 401; 500; timeout; malformed; expired
  token makes zero requests; two `fetch()` calls read credentials twice (counter on the in-memory
  provider); the stub asserts host and headers and that the body is never logged (no `print`).
- `usage-probe`: real run prints one line per limit (`session 31% resets 2026-10-21T12:00:00Z`)
  and the token length only; `--simulate 401|offline|malformed` wires the same stub as the tests.
- Oracle: `cd Packages/UsageData && swift test` → passed;
  `swift run --package-path Tools/usage-probe usage-probe` → `session NN% …` and `weekly_all NN% …` lines;
  `… usage-probe --simulate 401` → `error: unauthorized`; `--simulate offline` → `error: offline`;
  `--simulate malformed` → `error: malformed`.

### 6. UsagePresentation: thresholds, formatting values, UsageStore
- `Threshold`: constants `warning = 80`, `critical = 95`; `level(for percent:) -> ThresholdLevel`
  (`.normal`, `.warning`, `.critical`). Tests at 79/80/94/95/100.
- `MenuBarTitle.make(state:) -> String`: `"31% · 47%"` (session first, weekly_all second, no
  spaces beyond the dot), `"…"` before any data, `"⚠︎"` for `.noCredentials` / `.credentialsDenied` /
  `.tokenExpired` / `.unauthorized` even with stale data, `"—"` for any other error with no data,
  stale numbers otherwise. Missing `weekly_all` → `"31% · —"`.
- `ResetDisplay.make(resetsAt:now:) -> .relative(hours:minutes:) | .absolute(Date)`: relative
  under 24 h, 0 hours omitted at the app layer, past dates clamp to `.relative(0, 0)`.
- `UsageStore` (`@MainActor @Observable final class`): `snapshot`, `updatedAt`, `error`,
  `isLoading`, `keychainPaused`; `refresh(trigger:)` with the 10 s throttle (injected clock);
  `retryKeychain()` clears the pause. Transitions: success replaces snapshot and clears error;
  failure keeps snapshot and sets error; `.credentialsDenied` sets `keychainPaused`; while paused,
  timer refreshes are no-ops and manual Retry works.
- Tests use the in-memory `CredentialsProviding` and a fake `UsageRepository`; formatting tests
  pass explicit `Locale` where a value depends on it (none should: this package returns values).
- Oracle: `cd Packages/UsagePresentation && swift test` → passed;
  `(cd Packages/UsagePresentation && xcodebuild -scheme UsagePresentation -destination 'generic/platform=iOS' build 2>&1 | mise x -- xcsift)` → `Build succeeded`, same for watchOS.

### 7. App shell: status item only
- `Apps/macOS/Sources/YourLimitApp.swift` (`@main`, `MenuBarExtra(.window)`), `AppCoordinator`
  (builds `KeychainCredentialsStore` → `UsageClient` → `UsageStore`, 60 s timer, refresh on
  popover open and on `NSWorkspace.didWakeNotification`), label `Text(title).monospacedDigit()`
  with identifier `statusItem`. Popover body is a placeholder `Text("…")` for this step.
- Logger subsystem `com.xroserok.yourlimitbar`, categories `network`, `credentials`, `ui`.
- Oracle: `scripts/build.sh` → `OK: .build/DerivedData/Build/Products/Release/YourLimit.app`;
  `scripts/run.sh` → `OK: YourLimit running, pid N`; then
  `osascript -e 'tell application "System Events" to tell process "YourLimit" to get title of menu bar item 1 of menu bar 2'`
  → `NN% · NN%` (confirms the `menu bar 2` assumption of `verify-ui.sh`; adjust the script only if
  the attribute path differs, and say so).

### 8. Popover: limit blocks, Updated, buttons
- `PopoverView` + `LimitRow`: title, percent, `ProgressView` tinted by `ThresholdLevel`
  (accent / orange / red), reset line; one row per `session`, `weekly_all`, each `weekly_scoped`;
  divider, `Updated HH:mm`, divider, Refresh (⌘R), Launch at Login toggle (placeholder bound to a
  local state this step), Quit (⌘Q). Fixed width 300 pt. Identifiers from spec §3.3;
  `weekly_scoped.<model>` uses `display_name`, else `model.id`, else the index.
- Esc closes the popover (if `.window` does not do it natively, `onExitCommand`).
- Oracle: `scripts/verify-ui.sh` → `OK` with `identifiers=` containing `limit.session.title …
  limit.weekly_all.reset updated refresh launchAtLogin quit`; English texts in `texts=`.

### 9. Localisation (en + ru) and formatting in the app layer
- `Apps/macOS/Resources/Localizable.xcstrings` with every string of spec §3.3, both languages in
  the same change; `Project.swift` gets `resources: ["Apps/macOS/Resources/**"]` and
  `CFBundleLocalizations` is left to Xcode (String Catalog declares `en`, `ru`).
- `LocalizedText` helpers in the app: `"Week · %@"`, `"resets in %lld h %lld min"`,
  `"resets %@"` (weekday + time via `Date.FormatStyle().weekday(.abbreviated).hour().minute()`),
  `"Updated %@"`.
- Oracle: `mise x -- tuist generate --no-open` then `scripts/verify-ui.sh` → `OK`;
  `UI_LANG=ru scripts/verify-ui.sh` → `OK` and `texts=` contains `Сессия`, `Неделя (все модели)`, `Обновлено`.

### 10. Error states in the popover
- `error` line under Updated: `Offline` (`.offline`, `.timeout`), `Sign in to Claude Code`
  (`.noCredentials`, `.tokenExpired`, `.unauthorized`), `Keychain access denied` + `retry` button
  (`.credentialsDenied`), `HTTP NNN` (`.http`), `Unexpected response` (`.malformed`; new string
  not in spec §3.3, en + ru: `Неожиданный ответ`). Status item follows step 6 rules.
- Oracle: `cd Packages/UsagePresentation && swift test` → passed (state → status/error mapping);
  manual, quoted in progress.md: Wi-Fi off → popover shows `Offline`, numbers unchanged; Wi-Fi on →
  numbers refresh within 60 s (spec §7.5). Token case per §7.6 is verified with
  `usage-probe --simulate 401` for the data layer and by a human for the UI.

### 11. Launch at Login
- `LaunchAtLogin` (app target) over `SMAppService.mainApp`: `isEnabled` from `.status == .enabled`
  on every popover open; `toggle()` calls `register()` / `unregister()`; errors surface as the
  `error` line (`Launch at Login failed`, en + ru), never crash. No UserDefaults.
- Oracle: `scripts/verify-ui.sh` → `OK` (identifier `launchAtLogin` present); manual §7.7: toggle
  on, quit, relaunch → still on; note in progress.md whether ad-hoc signing let `register()` succeed.

### 12. Shortcuts and Quit
- ⌘R → `store.refresh(trigger: .manual)`, ⌘Q → `NSApplication.shared.terminate`, both as
  `.keyboardShortcut` on the buttons; if the `.window` panel does not receive key events, fall back
  to an `NSEvent.addLocalMonitorForEvents` in the coordinator and say so in progress.md.
- Oracle: `scripts/verify-ui.sh` → `OK` (Esc path already exercised); after the step 13 fix,
  `scripts/acceptance.sh` prints `✔ 9 Quit terminates the process`.

### 13. Harness fix: acceptance.sh criterion 9
- Replace the `menu item "Quit" of menu 1` click with `click button 1 of window 1 whose value of
  attribute "AXIdentifier" is "quit"` (System Events syntax to be confirmed against step 8 output).
- Oracle: `scripts/acceptance.sh` → `✔ 9 Quit terminates the process`.

### 14. Lint, CI and wrap-up
- `mise x -- swiftlint --strict` clean, `swift format lint --strict --recursive Packages Apps Tools`
  clean, README status line updated, `progress.md` recap with the manual results of §7.3, 5, 6, 7.
- Oracle: `scripts/acceptance.sh` → every automatic line `✔`, exit 0; `git grep -E "sk-ant-oat01-[A-Za-z0-9_-]{20,}"` → empty;
  CI green on `main`.

## Risks

### Undocumented endpoint
- Format drift: `limits[]` may vanish, `kind` strings may change, `percent` may become a float.
  Mitigation: lenient DTOs (step 3), fallback to `five_hour` / `seven_day`, unknown kinds hidden,
  fixture pinned to 2026-10-21, `—` + `Unexpected response` instead of a crash.
- `anthropic-beta: oauth-2025-04-20` may be retired → 4xx; shown as `HTTP NNN`, stale numbers kept.
- Rate limiting (429) is not in the spec; treated as `.http(429)` with stale data. One request per
  minute plus throttled manual refreshes stays far below what Claude Code itself does.
- The endpoint may differ per subscription tier; only `default_claude_max_5x` is verified.
- Polling an unofficial endpoint could in theory be disallowed by Anthropic; the honest
  `User-Agent` makes the app identifiable, which is the chosen stance (spec §2.4).

### Keychain read
- `SecItemCopyMatching` blocks the calling thread while the "wants to use your confidential
  information" dialog is open; the read must stay off the main actor or the status item freezes.
- "Deny" is not persisted by macOS: every read re-prompts. Hence decision 1 (pause until Retry).
- Keychain locked after sleep/screen lock can return `errSecInteractionNotAllowed`; mapped to
  `.credentialsDenied`, which pauses polling until Retry. Watch for this in daily use; if it shows
  up, propose a separate state in a later iteration (not v1).
- Claude Code may change the item shape (keys, ms → s for `expiresAt`) or move credentials
  elsewhere; the parser tolerates missing keys and reports `.noCredentials`.
- Two Claude Code installs (e.g. npm + native) could leave two items with the same service;
  `kSecMatchLimitOne` picks the first. Not handled further in v1.
- `expiresAt` is compared with the local clock; a skewed clock skips valid requests.

### Ad-hoc signing
- The code-signing identity changes on every rebuild, so TCC/Keychain forget "Always Allow": each
  `scripts/run.sh` re-prompts. Accepted (spec §5). `verify-ui.sh` therefore needs a human to click
  "Always Allow" on the first run after a rebuild, or the title stays `⚠︎`.
- `SMAppService.register()` may fail or silently not persist for an ad-hoc app; surfaced as an
  error line, criterion §7.7 may stay red on this machine — document, do not work around.
- `LSUIElement` + `open --args -AppleLanguages` is fine, but the Release build must be the only
  `YourLimit.app` on disk or TCC prompts go to the wrong copy (`acceptance.sh` checks `mdfind`).
- `CODE_SIGN_IDENTITY = "-"` with `CODE_SIGN_STYLE = Manual` must survive `tuist generate`; the
  build script verifies `Signature=adhoc` and no entitlements, so a regression is caught.

### SwiftUI `MenuBarExtra(.window)` specifics (verified at steps 7, 8, 12)
- Status item label may ignore `.monospacedDigit()`; fallback: `Text` with `.font(.system(.body, design: .monospaced))`.
- The popover panel may not receive ⌘R / ⌘Q; see step 12 fallback.
- `verify-ui.sh` paths (`menu bar 2`, `window 1`, `AXIdentifier`) were written blind; step 7 confirms them.

## Ambiguities in the spec (and the assumption taken)

1. §3.1 table has no row for HTTP 5xx / malformed without data → assume `—` (same as "network down, no data").
2. §3.1: 401 with stale numbers → `⚠︎` wins over stale numbers (the account is signed out).
3. §2.4 "never more than one request per 10 seconds" → applies to Refresh ⌘R too; a throttled
   refresh is silently coalesced, no UI feedback.
4. §3.2 "in N h M min" with N = 0 → show minutes only ("resets in 52 min"); `resets_at` in the
   past → "resets in 0 min" until the next poll.
5. §3.2 `weekly_scoped` without `display_name` → use `model.id`, else index; title falls back to
   "Week · model" (en) / "Неделя · модель" (ru).
6. §3.3 identifier `limit.weekly_scoped.<model>` with a name containing spaces → spaces kept
   as-is (identifiers are opaque strings).
7. §7.1 says `xcodebuild test` must be green, but §4.1 puts all tests in packages run by
   `swift test`; `acceptance.sh` already follows §4.1. Assume `swift test`.
8. §2.2 `percent` "integer 0–100" → values above 100 are shown as received, bar clamped.
9. §3.2 Esc closes the popover: not guaranteed by `.window` style; handled in step 8.
10. §2.4 refresh "on menu open": the `.window` style has no open callback; use `onAppear` of
    the popover body, which fires on every open.
11. §3.4 "Leaves nothing behind on logout or Quit": no UserDefaults are written at all in v1
    (Launch at Login state lives in `SMAppService`), so the Preferences plist never exists.

## Tempting, explicitly not planned (spec §8 or beyond)

Colour / icon / severity in the menu bar; notifications at thresholds or on reset; product
breakdown (`seven_day_breakdown`); extra usage and `spend`; `is_active` marker on the active
limit; showing `expiresAt` or a "token expires in" line; an "Open Claude Code" / "run claude login"
button; exponential backoff or jittered polling; caching the last snapshot to disk for a future
widget; a settings window (interval, thresholds, menu bar format); choosing which two numbers go
to the menu bar; hiding `weekly_scoped` rows; a launch argument to simulate errors inside the app;
global hotkey; Sparkle / auto-update, DMG, Homebrew cask, notarisation; Intel-specific testing;
animations; 12 h / 24 h override; sound; multiple accounts; API-key support.

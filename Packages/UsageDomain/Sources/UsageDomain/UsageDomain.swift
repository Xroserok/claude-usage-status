// UsageDomain — the innermost layer.
//
// Owns the models (`UsageSnapshot`, `UsageLimit`, `UsageError`) and the
// protocols the outer layers implement (`UsageRepository`,
// `CredentialsProviding`). Depends on Foundation only: no networking, no
// Keychain, no SwiftUI, no timers. Everything public is `Sendable`.

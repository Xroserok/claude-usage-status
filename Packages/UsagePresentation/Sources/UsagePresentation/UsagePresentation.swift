// UsagePresentation — platform-independent view models and formatting.
//
// `UsageStore` (@Observable screen state, refresh policy), `UsageFormatter`
// ("31% · 47%", "resets in 2h 10m"). Talks to the data layer only through
// UsageDomain protocols, so the same store serves the macOS menu bar, an iOS
// widget or a watchOS complication. Navigation and dependency wiring live in
// the app targets (coordinators), not here.

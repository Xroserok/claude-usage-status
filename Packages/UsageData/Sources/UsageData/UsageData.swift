// UsageData — implementations of the UsageDomain protocols.
//
// `UsageClient` (URLSession → https://api.anthropic.com/api/oauth/usage),
// `KeychainCredentialsStore` (SecItemCopyMatching), DTOs for the JSON in
// spec §2.1 and their mapping to domain models. Depends on UsageDomain,
// Foundation and Security. No SwiftUI, no AppKit.

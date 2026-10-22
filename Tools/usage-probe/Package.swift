// swift-tools-version: 6.0
import PackageDescription

// Verification CLI: reads the token from the Keychain, calls the usage
// endpoint and prints the parsed snapshot. Used by the harness scripts and
// by Claude Code to check the data layer without launching the app.
let package = Package(
    name: "usage-probe",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(path: "../../Packages/UsageDomain"),
        .package(path: "../../Packages/UsageData"),
    ],
    targets: [
        .executableTarget(
            name: "usage-probe",
            dependencies: [
                .product(name: "UsageDomain", package: "UsageDomain"),
                .product(name: "UsageData", package: "UsageData"),
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)

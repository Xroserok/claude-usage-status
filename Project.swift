import ProjectDescription

// The Xcode project is generated with `tuist generate` and is not committed.
// The app target is a thin shell: entry point, MenuBarExtra, the macOS
// coordinator and LaunchAtLogin. All logic lives in the local packages.
let project = Project(
    name: "ClaudeUsageStatus",
    organizationName: "Xroserok",
    packages: [
        .local(path: "Packages/UsageDomain"),
        .local(path: "Packages/UsageData"),
        .local(path: "Packages/UsagePresentation"),
    ],
    settings: .settings(base: [
        "SWIFT_VERSION": "6.0",
        "SWIFT_STRICT_CONCURRENCY": "complete",
    ]),
    targets: [
        .target(
            name: "ClaudeUsageStatus",
            destinations: .macOS,
            product: .app,
            bundleId: "com.xroserok.ClaudeUsageStatus",
            deploymentTargets: .macOS("14.0"),
            // Explicit plist: Tuist's macOS default adds NSMainStoryboardFile,
            // which a SwiftUI @main app does not have.
            infoPlist: .dictionary([
                "CFBundleDevelopmentRegion": "en",
                "CFBundleExecutable": "$(EXECUTABLE_NAME)",
                "CFBundleIdentifier": "$(PRODUCT_BUNDLE_IDENTIFIER)",
                "CFBundleInfoDictionaryVersion": "6.0",
                "CFBundleName": "$(PRODUCT_NAME)",
                "CFBundlePackageType": "APPL",
                "CFBundleShortVersionString": "0.1.0",
                "CFBundleVersion": "1",
                "LSMinimumSystemVersion": "$(MACOSX_DEPLOYMENT_TARGET)",
                "LSUIElement": true,
                "NSPrincipalClass": "NSApplication",
            ]),
            sources: ["Apps/macOS/Sources/**"],
            dependencies: [
                .package(product: "UsageDomain"),
                .package(product: "UsageData"),
                .package(product: "UsagePresentation"),
            ],
            settings: .settings(base: [
                // UI code is main-actor by default; the packages are not.
                "SWIFT_DEFAULT_ACTOR_ISOLATION": "MainActor",
                // Ad-hoc signing, see spec §4.4.
                "CODE_SIGN_IDENTITY": "-",
                "CODE_SIGN_STYLE": "Manual",
            ])
        ),
    ]
)

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
            infoPlist: .extendingDefault(with: [
                "LSUIElement": true,
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

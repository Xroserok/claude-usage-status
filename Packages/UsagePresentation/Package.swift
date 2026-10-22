// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "UsagePresentation",
    platforms: [.macOS(.v14), .iOS(.v17), .watchOS(.v10)],
    products: [
        .library(name: "UsagePresentation", targets: ["UsagePresentation"]),
    ],
    dependencies: [
        .package(path: "../UsageDomain"),
    ],
    targets: [
        .target(
            name: "UsagePresentation",
            dependencies: [.product(name: "UsageDomain", package: "UsageDomain")]
        ),
        .testTarget(name: "UsagePresentationTests", dependencies: ["UsagePresentation"]),
    ],
    swiftLanguageModes: [.v6]
)

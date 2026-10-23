// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "UsageData",
    platforms: [.macOS(.v14), .iOS(.v17), .watchOS(.v10)],
    products: [
        .library(name: "UsageData", targets: ["UsageData"])
    ],
    dependencies: [
        .package(path: "../UsageDomain")
    ],
    targets: [
        .target(
            name: "UsageData",
            dependencies: [.product(name: "UsageDomain", package: "UsageDomain")]
        ),
        .testTarget(
            name: "UsageDataTests",
            dependencies: ["UsageData"],
            resources: [.copy("Fixtures")]
        ),
    ],
    swiftLanguageModes: [.v6]
)

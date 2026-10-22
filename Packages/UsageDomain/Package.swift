// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "UsageDomain",
    platforms: [.macOS(.v14), .iOS(.v17), .watchOS(.v10)],
    products: [
        .library(name: "UsageDomain", targets: ["UsageDomain"]),
    ],
    targets: [
        .target(name: "UsageDomain"),
        .testTarget(name: "UsageDomainTests", dependencies: ["UsageDomain"]),
    ],
    swiftLanguageModes: [.v6]
)

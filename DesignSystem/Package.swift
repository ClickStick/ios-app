// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "DesignSystem",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "DesignSystem",
            targets: ["DesignSystem"]
        )
    ],
    targets: [
        .target(
            name: "DesignSystem",
            resources: [.process("Resources")]
        )
    ],
    swiftLanguageModes: [.v6]
)

// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "ClaudeUsage",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v13),
    ],
    products: [
        .executable(name: "ClaudeUsage", targets: ["ClaudeUsage"]),
    ],
    targets: [
        .executableTarget(
            name: "ClaudeUsage",
            resources: [
                .process("Resources"),
            ]
        ),
        .testTarget(
            name: "ClaudeUsageTests",
            dependencies: ["ClaudeUsage"],
            resources: [
                .process("Fixtures"),
            ]
        ),
    ]
)

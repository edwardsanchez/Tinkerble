// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "Tinkerble",
    platforms: [
        .iOS("26.0"),
        .macOS("26.0"),
    ],
    products: [
        .library(name: "Tinkerble", targets: ["Tinkerble"]),
        .library(name: "TinkerbleCompanionCore", targets: ["TinkerbleCompanionCore"]),
        .executable(name: "TinkerbleCompanion", targets: ["TinkerbleCompanion"]),
    ],
    dependencies: [
        .package(url: "https://github.com/rsocket/rsocket-swift.git", branch: "main"),
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.32.1"),
        .package(url: "https://github.com/apple/swift-nio-extras.git", from: "1.8.0"),
    ],
    targets: [
        .target(
            name: "Tinkerble",
            dependencies: [
                .product(name: "RSocketCore", package: "rsocket-swift"),
                .product(name: "RSocketTCPTransport", package: "rsocket-swift"),
                .product(name: "RSocketTSChannel", package: "rsocket-swift"),
                .product(name: "NIOCore", package: "swift-nio"),
            ]
        ),
        .target(
            name: "TinkerbleCompanionCore",
            dependencies: [
                "Tinkerble",
                .product(name: "RSocketCore", package: "rsocket-swift"),
                .product(name: "NIOCore", package: "swift-nio"),
                .product(name: "NIOExtras", package: "swift-nio-extras"),
                .product(name: "NIOPosix", package: "swift-nio"),
            ]
        ),
        .executableTarget(
            name: "TinkerbleCompanion",
            dependencies: ["TinkerbleCompanionCore"]
        ),
        .testTarget(
            name: "TinkerbleTests",
            dependencies: [
                "Tinkerble",
                "TinkerbleCompanionCore",
            ]
        ),
    ]
)

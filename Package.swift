// swift-tools-version: 5.9

import PackageDescription
import CompilerPluginSupport

let package = Package(
    name: "Tinkerble",
    platforms: [
        .iOS("26.0"),
        .macOS("26.0"),
    ],
    products: [
        .library(name: "Tinkerble", targets: ["Tinkerble"]),
        .library(name: "TinkerbleCompanionCore", targets: ["TinkerbleCompanionCore"]),
        .library(name: "TinkerbleCompanionUI", targets: ["TinkerbleCompanionUI"]),
        .executable(name: "TinkerbleCompanion", targets: ["TinkerbleCompanion"]),
        .executable(name: "tinkerble", targets: ["TinkerbleCLI"]),
    ],
    dependencies: [
        .package(url: "https://github.com/edwardsanchez/rsocket-swift.git", branch: "tinkerble-xcode26-main"),
        .package(url: "https://github.com/swiftlang/swift-syntax.git", from: "604.0.0-latest"),
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.32.1"),
        .package(url: "https://github.com/apple/swift-nio-extras.git", from: "1.8.0"),
    ],
    targets: [
        .target(
            name: "Tinkerble",
            dependencies: [
                "TinkerbleMacros",
                .product(name: "RSocketCore", package: "rsocket-swift"),
                .product(name: "RSocketTCPTransport", package: "rsocket-swift"),
                .product(name: "RSocketTSChannel", package: "rsocket-swift"),
                .product(name: "NIOCore", package: "swift-nio"),
            ]
        ),
        .macro(
            name: "TinkerbleMacros",
            dependencies: [
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
                .product(name: "SwiftDiagnostics", package: "swift-syntax"),
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
        .target(
            name: "TinkerbleCompanionUI",
            dependencies: [
                "Tinkerble",
                "TinkerbleCompanionCore",
            ],
            resources: [.process("Resources")]
        ),
        .executableTarget(
            name: "TinkerbleCompanion",
            dependencies: [
                "TinkerbleCompanionCore",
                "TinkerbleCompanionUI",
            ],
            resources: [.process("Resources")]
        ),
        .target(name: "TinkerbleInstallerCore"),
        .executableTarget(
            name: "TinkerbleCLI",
            dependencies: ["TinkerbleInstallerCore"]
        ),
        .testTarget(
            name: "TinkerbleTests",
            dependencies: [
                "Tinkerble",
                "TinkerbleMacros",
                "TinkerbleCompanionCore",
                "TinkerbleCompanionUI",
                .product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax"),
            ]
        ),
        .testTarget(
            name: "TinkerbleInstallerCoreTests",
            dependencies: ["TinkerbleInstallerCore"]
        ),
    ]
)

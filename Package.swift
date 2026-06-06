// swift-tools-version: 5.9

import CompilerPluginSupport
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
        .library(name: "TinkerbleCompanionUI", targets: ["TinkerbleCompanionUI"]),
        .executable(name: "TinkerbleCompanion", targets: ["TinkerbleCompanion"]),
    ],
    dependencies: [
        .package(url: "https://github.com/rsocket/rsocket-swift.git", branch: "main"),
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.32.1"),
        .package(url: "https://github.com/apple/swift-nio-extras.git", from: "1.8.0"),
        .package(url: "https://github.com/swiftlang/swift-syntax.git", from: "603.0.0"),
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
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
                .product(name: "SwiftDiagnostics", package: "swift-syntax"),
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftSyntaxBuilder", package: "swift-syntax"),
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
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
        .testTarget(
            name: "TinkerbleTests",
            dependencies: [
                "Tinkerble",
                "TinkerbleCompanionCore",
                "TinkerbleCompanionUI",
            ]
        ),
        .testTarget(
            name: "TinkerbleMacroTests",
            dependencies: [
                "Tinkerble",
                "TinkerbleMacros",
                .product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax"),
            ]
        ),
    ]
)

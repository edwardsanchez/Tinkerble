// swift-tools-version: 5.9

import PackageDescription
import CompilerPluginSupport

let package = Package(
    name: "Tinkerble",
    platforms: [
        .iOS("26.0"),
        .macOS("26.0")
    ],
    products: [
        .library(name: "Tinkerble", targets: ["Tinkerble"]),
        .library(name: "TinkerbleCompanionCore", targets: ["TinkerbleCompanionCore"]),
        .library(name: "TinkerbleCompanionUI", targets: ["TinkerbleCompanionUI"]),
        .executable(name: "TinkerbleCompanion", targets: ["TinkerbleCompanion"]),
        .executable(name: "tinkerble", targets: ["TinkerbleCLI"])
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-syntax.git", from: "604.0.0-latest")
    ],
    targets: [
        .target(
            name: "Tinkerble",
            dependencies: [
                "TinkerbleMacros"
            ]
        ),
        .macro(
            name: "TinkerbleMacros",
            dependencies: [
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
                .product(name: "SwiftDiagnostics", package: "swift-syntax")
            ]
        ),
        .target(
            name: "TinkerbleCompanionCore",
            dependencies: [
                "Tinkerble"
            ]
        ),
        .target(
            name: "TinkerbleCompanionUI",
            dependencies: [
                "Tinkerble",
                "TinkerbleCompanionCore"
            ],
            resources: [.process("Resources")]
        ),
        .executableTarget(
            name: "TinkerbleCompanion",
            dependencies: [
                "TinkerbleCompanionCore",
                "TinkerbleCompanionUI"
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
                .product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax")
            ]
        ),
        .testTarget(
            name: "TinkerbleInstallerCoreTests",
            dependencies: ["TinkerbleInstallerCore"]
        )
    ]
)

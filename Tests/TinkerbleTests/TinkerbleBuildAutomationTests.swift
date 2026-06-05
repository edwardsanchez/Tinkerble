import XCTest

final class TinkerbleBuildAutomationTests: XCTestCase {
    func testDemoSchemeBuildActionEnsuresCompanionRunsInDebugBuilds() throws {
        let scheme = try readText(
            "Tinkerble Demo/Tinkerble Demo.xcodeproj/xcshareddata/xcschemes/Tinkerble Demo.xcscheme"
        )

        XCTAssertTrue(scheme.contains("Patch package checkouts"))
        XCTAssertTrue(scheme.contains("Scripts/patch-rsocket-checkouts.sh"))
        XCTAssertTrue(scheme.contains("Scripts/ensure-macos-companion-running.sh"))
        XCTAssertTrue(scheme.contains("CONFIGURATION:-${BUILD_STYLE:-Debug}"))
        XCTAssertTrue(scheme.contains("== &quot;Debug&quot;"))
        XCTAssertTrue(scheme.contains("Tinkerble Demo.app"))
    }

    func testEnsureCompanionScriptIsExecutableAndVerifiesLaunch() throws {
        let scriptPath = repoRoot.appendingPathComponent("Scripts/ensure-macos-companion-running.sh").path
        let script = try String(contentsOfFile: scriptPath, encoding: .utf8)

        XCTAssertTrue(FileManager.default.isExecutableFile(atPath: scriptPath))
        XCTAssertTrue(script.contains("Scripts/package-macos-companion.sh"))
        XCTAssertTrue(script.contains("open \"$APP_BUNDLE\""))
        XCTAssertTrue(script.contains("pgrep -x \"$PROCESS_NAME\""))
        XCTAssertTrue(script.contains("lsof -Pan -p \"$pid\" -iTCP:\"$PORT\" -sTCP:LISTEN"))
        XCTAssertTrue(script.contains("TINKERBLE_COMPANION_AUTOLAUNCH"))
    }

    func testPackageScriptAcceptsXcodeConfigurationNames() throws {
        let script = try readText("Scripts/package-macos-companion.sh")

        XCTAssertTrue(script.contains("Debug|debug"))
        XCTAssertTrue(script.contains("Release|release"))
        XCTAssertTrue(script.contains("CONFIGURATION=debug"))
        XCTAssertTrue(script.contains("CONFIGURATION=release"))
    }

    func testPackageScriptScrubsXcodePlatformEnvironmentBeforeSwiftPMBuilds() throws {
        let script = try readText("Scripts/package-macos-companion.sh")

        XCTAssertTrue(script.contains("swift_package()"))
        XCTAssertTrue(script.contains("-u SDKROOT"))
        XCTAssertTrue(script.contains("-u PLATFORM_NAME"))
        XCTAssertTrue(script.contains("-u SWIFT_TARGET_TRIPLE"))
        XCTAssertTrue(script.contains("swift_package build"))
    }

    func testManualLaunchScriptUsesAutomaticCompanionPath() throws {
        let script = try readText("Scripts/launch-macos-companion.sh")

        XCTAssertTrue(script.contains("Scripts/ensure-macos-companion-running.sh"))
        XCTAssertTrue(script.contains("--restart"))
        XCTAssertFalse(script.contains("open -n"))
    }

    func testRSocketPatchKeepsRequestExamplesInXcodeSourceList() throws {
        let script = try readText("Scripts/patch-rsocket-checkouts.sh")

        XCTAssertTrue(script.contains("disable_rsocket_examples"))
        XCTAssertTrue(script.contains("Keep the file present and harmless instead of renaming it."))
        XCTAssertFalse(script.contains("mv \"$RSOCKET_EXAMPLES\""))
    }

    private func readText(_ relativePath: String) throws -> String {
        try String(
            contentsOf: repoRoot.appendingPathComponent(relativePath),
            encoding: .utf8
        )
    }

    private var repoRoot: URL {
        var url = URL(fileURLWithPath: #filePath)
        url.deleteLastPathComponent()
        url.deleteLastPathComponent()
        url.deleteLastPathComponent()
        return url
    }
}

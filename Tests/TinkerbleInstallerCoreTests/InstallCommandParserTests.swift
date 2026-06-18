import XCTest
@testable import TinkerbleInstallerCore

final class InstallCommandParserTests: XCTestCase {
    func testParsesExplicitProjectAndTarget() throws {
        let options = try InstallCommandParser.parse([
            "--project", "MyApp.xcodeproj",
            "--target", "MyApp"
        ])

        XCTAssertEqual(options.projectPath, "MyApp.xcodeproj")
        XCTAssertNil(options.workspacePath)
        XCTAssertEqual(options.targetNames, ["MyApp"])
        XCTAssertFalse(options.isDryRun)
    }

    func testParsesRepeatableTargetsAndDryRun() throws {
        let options = try InstallCommandParser.parse([
            "--workspace", "MyApp.xcworkspace",
            "--target", "MyApp",
            "--target", "DemoApp",
            "--scheme", "MyApp",
            "--scheme", "DemoApp",
            "--dry-run"
        ])

        XCTAssertEqual(options.workspacePath, "MyApp.xcworkspace")
        XCTAssertEqual(options.targetNames, ["MyApp", "DemoApp"])
        XCTAssertEqual(options.schemeNames, ["MyApp", "DemoApp"])
        XCTAssertTrue(options.isDryRun)
    }

    func testRejectsMissingOptionValue() {
        XCTAssertThrowsError(try InstallCommandParser.parse(["--project"])) { error in
            XCTAssertEqual(error as? TinkerbleInstallError, .invalidArguments("Missing value for --project."))
        }
    }

    func testParsesProjectAndWorkspaceTogetherForWorkspaceContext() throws {
        let options = try InstallCommandParser.parse(["--project", "A.xcodeproj", "--workspace", "A.xcworkspace"])

        XCTAssertEqual(options.projectPath, "A.xcodeproj")
        XCTAssertEqual(options.workspacePath, "A.xcworkspace")
    }

    func testParsesInteractiveMultiSelection() throws {
        let selected = try MultiSelectionParser.parse("1, 3-4, 3", choices: ["App", "Widget", "Demo", "Admin"])

        XCTAssertEqual(selected, ["App", "Demo", "Admin"])
    }
}

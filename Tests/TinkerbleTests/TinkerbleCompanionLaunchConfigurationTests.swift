import Foundation
import TinkerbleCompanionCore
import XCTest

final class TinkerbleCompanionLaunchConfigurationTests: XCTestCase {
    func testParsesSourceProjectArgumentsAndPreviewMode() {
        let configuration = TinkerbleCompanionLaunchConfiguration(
            arguments: [
                "TinkerbleCompanion",
                "--all-components",
                "--project-root",
                "/tmp/Example Project",
                "--project-id",
                "app.example.project"
            ]
        )

        XCTAssertEqual(configuration.mode, .allComponents)
        XCTAssertEqual(configuration.projectRoot?.path, "/tmp/Example Project")
        XCTAssertEqual(configuration.projectID, "app.example.project")
    }

    func testRejectsMissingEmptyAndOptionLikeValues() {
        let configuration = TinkerbleCompanionLaunchConfiguration(
            arguments: [
                "TinkerbleCompanion",
                "--project-root",
                "--project-id",
                "   "
            ]
        )

        XCTAssertEqual(configuration.mode, .companion)
        XCTAssertNil(configuration.projectRoot)
        XCTAssertNil(configuration.projectID)
    }
}

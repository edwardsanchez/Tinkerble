import XCTest
@testable import TinkerbleCompanionCore

final class TinkerbleCompanionEmptyStateTests: XCTestCase {
    func testWingsPDFIsImportedAsCompanionResource() throws {
        let resource = repoRoot.appending(path: "Sources/TinkerbleCompanion/Resources/wings.pdf")
        let previewResource = repoRoot.appending(path: "Sources/TinkerbleCompanionUI/Resources/wings.pdf")

        XCTAssertTrue(FileManager.default.fileExists(atPath: resource.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: previewResource.path))
        XCTAssertEqual(resource.pathExtension, "pdf")
        XCTAssertEqual(previewResource.pathExtension, "pdf")
    }

    func testEmptyStateImageSizingMatchesWindowLayout() {
        XCTAssertEqual(TinkerbleCompanionEmptyStateLayout.imageResourceName, "wings")
        XCTAssertEqual(TinkerbleCompanionEmptyStateLayout.imageResourceExtension, "pdf")
        XCTAssertEqual(TinkerbleCompanionEmptyStateLayout.imageWidth, 100)
        XCTAssertEqual(
            TinkerbleCompanionEmptyStateLayout.contentHeight,
            TinkerbleCompanionWindowLayout.minimumHeight
                - TinkerbleCompanionWindowLayout.titleBarHeight
                - TinkerbleCompanionWindowLayout.inspectorTopPadding
                - TinkerbleCompanionWindowLayout.inspectorBottomPadding
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

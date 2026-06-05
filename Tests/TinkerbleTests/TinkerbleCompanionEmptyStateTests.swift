import XCTest
@testable import TinkerbleCompanionCore

final class TinkerbleCompanionEmptyStateTests: XCTestCase {
    func testWingsPDFIsImportedAsCompanionResource() throws {
        let resource = repoRoot.appending(path: "Sources/TinkerbleCompanion/Resources/wings.pdf")
        let package = try readText("Package.swift")

        XCTAssertTrue(FileManager.default.fileExists(atPath: resource.path))
        XCTAssertEqual(resource.pathExtension, "pdf")
        XCTAssertTrue(package.contains("resources: [.process(\"Resources\")]"))
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

    func testCompanionEmptyStateUsesScalableCenteredImageInsteadOfText() throws {
        let companionApp = try readText("Sources/TinkerbleCompanion/CompanionApp.swift")
        let placeholderView = try readText("Sources/TinkerbleCompanion/EmptyTweakPlaceholderView.swift")
        let resource = try readText("Sources/TinkerbleCompanion/TinkerbleCompanionEmptyStateResource.swift")

        XCTAssertTrue(companionApp.contains("EmptyTweakPlaceholderView()"))
        XCTAssertFalse(companionApp.contains("Waiting for registered values"))
        XCTAssertTrue(resource.contains("Bundle.main.url("))
        XCTAssertTrue(resource.contains("Bundle.module.url("))
        XCTAssertTrue(placeholderView.contains("NSImage(contentsOf: imageURL)"))
        XCTAssertTrue(placeholderView.contains(".scaledToFit()"))
        XCTAssertTrue(placeholderView.contains(".offset(y: -TinkerbleCompanionWindowLayout.titleBarHeight)"))
        XCTAssertTrue(placeholderView.contains("alignment: .center"))
        XCTAssertFalse(placeholderView.contains(".frame(height:"))
    }

    func testCompanionPackagingCopiesAndVerifiesWingsResource() throws {
        let packageScript = try readText("Scripts/package-macos-companion.sh")
        let verifyScript = try readText("Scripts/verify-macos-companion-package.sh")

        XCTAssertTrue(packageScript.contains("Tinkerble_TinkerbleCompanion.bundle"))
        XCTAssertTrue(packageScript.contains("ditto \"$RESOURCE_BUNDLE\" \"$RESOURCES_DIR\""))
        XCTAssertTrue(verifyScript.contains("[[ -f \"$RESOURCES_DIR/wings.pdf\" ]]"))
    }

    private func readText(_ relativePath: String) throws -> String {
        try String(contentsOf: repoRoot.appending(path: relativePath), encoding: .utf8)
    }

    private var repoRoot: URL {
        var url = URL(fileURLWithPath: #filePath)
        url.deleteLastPathComponent()
        url.deleteLastPathComponent()
        url.deleteLastPathComponent()
        return url
    }
}

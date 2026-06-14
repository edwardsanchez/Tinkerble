import XCTest
@testable import TinkerbleCompanionCore

final class TinkerbleCompanionEmptyStateTests: XCTestCase {
    func testWingsPDFIsImportedAsCompanionResource() throws {
        let resource = repoRoot.appending(path: "Sources/TinkerbleCompanion/Resources/wings.pdf")
        let previewResource = repoRoot.appending(path: "Sources/TinkerbleCompanionUI/Resources/wings.pdf")
        let package = try readText("Package.swift")

        XCTAssertTrue(FileManager.default.fileExists(atPath: resource.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: previewResource.path))
        XCTAssertEqual(resource.pathExtension, "pdf")
        XCTAssertEqual(previewResource.pathExtension, "pdf")
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
        let tweakInspectorView = try readText("Sources/TinkerbleCompanionUI/TweakInspectorView.swift")
        let placeholderView = try readText("Sources/TinkerbleCompanionUI/EmptyTweakPlaceholderView.swift")
        let resource = try readText("Sources/TinkerbleCompanionUI/TinkerbleCompanionEmptyStateResource.swift")

        XCTAssertTrue(tweakInspectorView.contains("EmptyTweakPlaceholderView()"))
        XCTAssertFalse(tweakInspectorView.contains("Waiting for registered values"))
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

        XCTAssertTrue(packageScript.contains("Tinkerble_TinkerbleCompanion*.bundle"))
        XCTAssertTrue(packageScript.contains("for resource_bundle in \"${RESOURCE_BUNDLES[@]}\""))
        XCTAssertTrue(verifyScript.contains("Tinkerble_TinkerbleCompanion.bundle/Contents/Resources/wings.pdf"))
        XCTAssertTrue(verifyScript.contains("Tinkerble_TinkerbleCompanionUI.bundle/Contents/Resources/wings.pdf"))
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

import XCTest
@testable import Tinkerble
@testable import TinkerbleCompanionUI

final class TweakInspectorContentTests: XCTestCase {
    func testCategoryHeaderTopPaddingIsZeroForFirstGroup() {
        let firstGroup = TinkerbleTweakGroup(category: "Layout", tweaks: [])
        let secondGroup = TinkerbleTweakGroup(category: "Text", tweaks: [])

        XCTAssertEqual(
            TweakInspectorContent.categoryHeaderTopPadding(for: firstGroup, in: [firstGroup, secondGroup]),
            0
        )
    }

    func testCategoryHeaderTopPaddingIsFifteenForNonFirstGroup() {
        let firstGroup = TinkerbleTweakGroup(category: "Layout", tweaks: [])
        let secondGroup = TinkerbleTweakGroup(category: "Text", tweaks: [])

        XCTAssertEqual(
            TweakInspectorContent.categoryHeaderTopPadding(for: secondGroup, in: [firstGroup, secondGroup]),
            15
        )
    }

    func testNumberFieldDragUsesLiveDisplayedValueAndStatefulPreviews() throws {
        let source = try readText("Sources/TinkerbleCompanionUI/TweakInspectorView.swift")

        XCTAssertTrue(source.contains("@State private var displayedValue: Double?"))
        XCTAssertTrue(source.contains("let startValue = dragStartValue ?? currentValue"))
        XCTAssertTrue(source.contains("commitValue(\n                    TinkerbleNumericInteraction.draggedValue("))
        XCTAssertTrue(source.contains("return currentValue.formatted("))
        XCTAssertTrue(source.contains("@Previewable @State var rangedValue = 0.65"))
        XCTAssertTrue(source.contains("updateValue: { rangedValue = $0 }"))
    }

    func testInspectorRoutesDatesToDatePickerAndShowsAngleUnitLabels() throws {
        let source = try readText("Sources/TinkerbleCompanionUI/TweakInspectorView.swift")

        XCTAssertTrue(source.contains("case .date:\n            dateControl"))
        XCTAssertTrue(source.contains("DatePicker(\"\", selection: dateBinding, displayedComponents: displayedDatePickerComponents)"))
        XCTAssertTrue(source.contains("case .dateAndTime:\n            return [.date, .hourAndMinute]"))
        XCTAssertTrue(source.contains("Text(angleUnit.displayName)"))
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

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
        XCTAssertTrue(source.contains("refreshEditingText: true"))
        XCTAssertTrue(source.contains("editingText = textValue(for: value)"))
        XCTAssertTrue(source.contains("return textValue(for: currentValue)"))
        XCTAssertTrue(source.contains("@Previewable @State var rangedValue = 0.65"))
        XCTAssertTrue(source.contains("updateValue: { rangedValue = $0 }"))
    }

    func testInspectorRoutesDatesToDatePickerAndKeepsDegreeSymbolInsideField() throws {
        let source = try readText("Sources/TinkerbleCompanionUI/TweakInspectorView.swift")

        XCTAssertTrue(source.contains("case .date:\n            dateControl"))
        XCTAssertTrue(source.contains("DatePicker(\"\", selection: dateBinding, displayedComponents: displayedDatePickerComponents)"))
        XCTAssertTrue(source.contains("case .dateAndTime:\n            return [.date, .hourAndMinute]"))
        XCTAssertTrue(source.contains("return \"\\(number)º\""))
        XCTAssertFalse(source.contains("Text(angleUnit.displayName)"))
    }

    func testDegreeFieldParserAcceptsValuesWithAndWithoutDegreeSymbols() {
        let configuration = TinkerbleNumericControl(decimalPlaces: 0, angleUnit: .degrees)

        XCTAssertEqual(TinkerbleNumberFieldView.number(from: "45", configuration: configuration), 45)
        XCTAssertEqual(TinkerbleNumberFieldView.number(from: "45º", configuration: configuration), 45)
        XCTAssertEqual(TinkerbleNumberFieldView.number(from: "45°", configuration: configuration), 45)
    }

    func testRadianFieldParserDoesNotStripDegreeSymbols() {
        let configuration = TinkerbleNumericControl(decimalPlaces: 2, angleUnit: .radians)

        XCTAssertEqual(TinkerbleNumberFieldView.number(from: "1.57", configuration: configuration), 1.57)
        XCTAssertNil(TinkerbleNumberFieldView.number(from: "1.57º", configuration: configuration))
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

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
        XCTAssertTrue(source.contains("Image(systemName: \"chevron.left.chevron.right\")"))
        XCTAssertFalse(source.contains("Button(\"Adjust value\", systemImage: \"chevron.left.chevron.right\")"))
        XCTAssertTrue(source.contains("let startValue = dragStartValue ?? currentValue"))
        XCTAssertTrue(source.contains("commitValue(\n                    TinkerbleNumericInteraction.draggedValue("))
        XCTAssertTrue(source.contains("modifiers: .current"))
        XCTAssertTrue(source.contains("refreshEditingText: true"))
        XCTAssertTrue(source.contains(".id(textFieldRefreshID)"))
        XCTAssertTrue(source.contains("editingText = textValue(for: value)"))
        XCTAssertTrue(source.contains("return textValue(for: currentValue)"))
        XCTAssertTrue(source.contains("@Previewable @State var rangedValue = 0.65"))
        XCTAssertTrue(source.contains("updateValue: { rangedValue = $0 }"))
    }

    func testInspectorRoutesDatesToDatePickerAndKeepsDegreeSymbolInsideField() throws {
        let source = try readText("Sources/TinkerbleCompanionUI/TweakInspectorView.swift")

        XCTAssertTrue(source.contains("case .date:\n            dateControl"))
        XCTAssertTrue(source.contains("TinkerbleDatePickerView(selection: dateBinding, components: dateControlComponents)"))
        XCTAssertTrue(source.contains("return .dateAndTime"))
        XCTAssertTrue(source.contains("return \"\\(number)º\""))
        XCTAssertFalse(source.contains("Text(angleUnit.displayName)"))
    }

    func testDatePickerConfiguresAppKitElementsAndCalendarOverlay() {
        #if os(macOS)
        XCTAssertEqual(
            TinkerbleDatePickerView.appKitConfiguration(for: .date),
            TinkerbleDatePickerAppKitConfiguration(
                elements: .yearMonthDay,
                presentsCalendarOverlay: true,
                appearance: NSAppearance(named: .darkAqua)
            )
        )
        XCTAssertEqual(
            TinkerbleDatePickerView.appKitConfiguration(for: .dateAndTime),
            TinkerbleDatePickerAppKitConfiguration(
                elements: [.yearMonthDay, .hourMinute],
                presentsCalendarOverlay: true,
                appearance: NSAppearance(named: .darkAqua)
            )
        )
        XCTAssertEqual(
            TinkerbleDatePickerView.appKitConfiguration(for: .time),
            TinkerbleDatePickerAppKitConfiguration(
                elements: .hourMinute,
                presentsCalendarOverlay: false,
                appearance: NSAppearance(named: .darkAqua)
            )
        )
        #endif
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

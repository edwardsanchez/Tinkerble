import XCTest
@testable import Tinkerble
@testable import TinkerbleCompanionUI

final class TweakInspectorContentTests: XCTestCase {
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
}

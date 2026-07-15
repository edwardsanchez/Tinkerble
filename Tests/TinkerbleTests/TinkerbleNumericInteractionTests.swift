import XCTest
@testable import Tinkerble
@testable import TinkerbleCompanionCore

final class TinkerbleNumericInteractionTests: XCTestCase {
    func testArrowKeysIncrementAndDecrementByOne() {
        let configuration = TinkerbleNumericControl(decimalPlaces: 2)

        XCTAssertEqual(
            TinkerbleNumericInteraction.adjustedValue(
                from: 5,
                direction: .increment,
                modifiers: [],
                configuration: configuration
            ),
            6
        )
        XCTAssertEqual(
            TinkerbleNumericInteraction.adjustedValue(
                from: 5,
                direction: .decrement,
                modifiers: [],
                configuration: configuration
            ),
            4
        )
    }

    func testShiftArrowKeysAdjustByTen() {
        let configuration = TinkerbleNumericControl(decimalPlaces: 2)

        XCTAssertEqual(
            TinkerbleNumericInteraction.adjustedValue(
                from: 5,
                direction: .increment,
                modifiers: .shift,
                configuration: configuration
            ),
            15
        )
        XCTAssertEqual(
            TinkerbleNumericInteraction.adjustedValue(
                from: 5,
                direction: .decrement,
                modifiers: .shift,
                configuration: configuration
            ),
            -5
        )
    }

    func testOptionArrowKeysAdjustDecimalFieldsByOneDecimalPlace() {
        let configuration = TinkerbleNumericControl(decimalPlaces: 2)

        XCTAssertEqual(
            TinkerbleNumericInteraction.adjustedValue(
                from: 5,
                direction: .increment,
                modifiers: .option,
                configuration: configuration
            ),
            5.1,
            accuracy: 0.0001
        )
        XCTAssertEqual(
            TinkerbleNumericInteraction.adjustedValue(
                from: 5,
                direction: .decrement,
                modifiers: .option,
                configuration: configuration
            ),
            4.9,
            accuracy: 0.0001
        )
    }

    func testRepeatedOptionArrowKeysNormalizeToDisplayedPrecision() {
        let configuration = TinkerbleNumericControl(decimalPlaces: 2)
        var value = 0.0

        for _ in 0..<3 {
            value = TinkerbleNumericInteraction.adjustedValue(
                from: value,
                direction: .increment,
                modifiers: .option,
                configuration: configuration
            )
        }

        XCTAssertEqual(value, 0.3)
    }

    func testOptionArrowKeysDoNothingForIntegerFields() {
        let configuration = TinkerbleNumericControl(decimalPlaces: 0)

        XCTAssertEqual(
            TinkerbleNumericInteraction.adjustedValue(
                from: 5,
                direction: .increment,
                modifiers: .option,
                configuration: configuration
            ),
            5
        )
    }

    func testArrowKeysClampToRange() {
        let configuration = TinkerbleNumericControl(minimum: 0, maximum: 10, decimalPlaces: 0)

        XCTAssertEqual(
            TinkerbleNumericInteraction.adjustedValue(
                from: 5,
                direction: .increment,
                modifiers: .shift,
                configuration: configuration
            ),
            10
        )
        XCTAssertEqual(
            TinkerbleNumericInteraction.adjustedValue(
                from: 5,
                direction: .decrement,
                modifiers: .shift,
                configuration: configuration
            ),
            0
        )
    }

    func testRangedDragMapsOneHundredPixelsToFullRange() {
        let configuration = TinkerbleNumericControl(minimum: 0, maximum: 100, decimalPlaces: 0)

        XCTAssertEqual(
            TinkerbleNumericInteraction.draggedValue(
                from: 50,
                horizontalTranslation: 25,
                configuration: configuration
            ),
            75
        )
        XCTAssertEqual(
            TinkerbleNumericInteraction.draggedValue(
                from: 50,
                horizontalTranslation: -25,
                configuration: configuration
            ),
            25
        )
    }

    func testShiftRangedDragAdjustsByTenPerPoint() {
        let configuration = TinkerbleNumericControl(minimum: 0, maximum: 100, decimalPlaces: 0)

        XCTAssertEqual(
            TinkerbleNumericInteraction.draggedValue(
                from: 50,
                horizontalTranslation: 2,
                modifiers: .shift,
                configuration: configuration
            ),
            70
        )
        XCTAssertEqual(
            TinkerbleNumericInteraction.draggedValue(
                from: 50,
                horizontalTranslation: -2,
                modifiers: .shift,
                configuration: configuration
            ),
            30
        )
    }

    func testOptionRangedDragAdjustsDecimalFieldsByOneDecimalPlacePerPoint() {
        let configuration = TinkerbleNumericControl(minimum: 0, maximum: 100, decimalPlaces: 2)

        XCTAssertEqual(
            TinkerbleNumericInteraction.draggedValue(
                from: 50,
                horizontalTranslation: 2,
                modifiers: .option,
                configuration: configuration
            ),
            50.2,
            accuracy: 0.0001
        )
        XCTAssertEqual(
            TinkerbleNumericInteraction.draggedValue(
                from: 50,
                horizontalTranslation: -2,
                modifiers: .option,
                configuration: configuration
            ),
            49.8,
            accuracy: 0.0001
        )
    }

    func testDragAndTextInputNormalizeToDisplayedPrecision() {
        let configuration = TinkerbleNumericControl(minimum: 0, maximum: 1, decimalPlaces: 2)

        XCTAssertEqual(
            TinkerbleNumericInteraction.draggedValue(
                from: 0.2,
                horizontalTranslation: 10,
                configuration: configuration
            ),
            0.3
        )
        XCTAssertEqual(
            TinkerbleNumericInteraction.adjustedTextValue(
                0.300_000_000_000_000_04,
                configuration: configuration
            ),
            0.3
        )
        XCTAssertEqual(
            TinkerbleNumericInteraction.normalizedValue(1.015, decimalPlaces: 2),
            1.02
        )
    }

    func testOptionRangedDragDoesNothingForIntegerFields() {
        let configuration = TinkerbleNumericControl(minimum: 0, maximum: 100, decimalPlaces: 0)

        XCTAssertEqual(
            TinkerbleNumericInteraction.draggedValue(
                from: 50,
                horizontalTranslation: 2,
                modifiers: .option,
                configuration: configuration
            ),
            50
        )
    }

    func testRangedDragClampsAtFiftyPixelsEitherDirection() {
        let configuration = TinkerbleNumericControl(minimum: 0, maximum: 100, decimalPlaces: 0)

        XCTAssertEqual(
            TinkerbleNumericInteraction.draggedValue(
                from: 50,
                horizontalTranslation: 100,
                configuration: configuration
            ),
            100
        )
        XCTAssertEqual(
            TinkerbleNumericInteraction.draggedValue(
                from: 50,
                horizontalTranslation: -100,
                configuration: configuration
            ),
            0
        )
    }
}

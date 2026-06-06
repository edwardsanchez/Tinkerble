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

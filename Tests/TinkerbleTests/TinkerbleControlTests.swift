import XCTest
@testable import Tinkerble

final class TinkerbleControlTests: XCTestCase {
    func testDecimalSliderDefaultsToTwoPlacesForUnitRange() {
        let control = TinkerbleControl<Double>.slider(0...1)

        guard case let .slider(configuration) = control.descriptor else {
            return XCTFail("Expected slider configuration")
        }

        XCTAssertEqual(configuration.minimum, 0)
        XCTAssertEqual(configuration.maximum, 1)
        XCTAssertEqual(configuration.decimalPlaces, 2)
        XCTAssertEqual(configuration.step, 0.01)
    }

    func testDecimalSliderDefaultsToZeroPlacesForLargeIntegerLikeRange() {
        let control = TinkerbleControl<Double>.slider(0...100)

        guard case let .slider(configuration) = control.descriptor else {
            return XCTFail("Expected slider configuration")
        }

        XCTAssertEqual(configuration.decimalPlaces, 0)
        XCTAssertEqual(configuration.step, 1)
    }

    func testIntegerSliderDoesNotExposeDecimalPlaces() {
        let control = TinkerbleControl<Int>.slider(5...400)

        guard case let .slider(configuration) = control.descriptor else {
            return XCTFail("Expected slider configuration")
        }

        XCTAssertEqual(configuration.minimum, 5)
        XCTAssertEqual(configuration.maximum, 400)
        XCTAssertEqual(configuration.decimalPlaces, 0)
    }

    func testIntegerStepperDoesNotExposeDecimalPlaces() {
        let control = TinkerbleControl<Int>.stepper(step: 2)

        guard case let .stepper(configuration) = control.descriptor else {
            return XCTFail("Expected stepper configuration")
        }

        XCTAssertEqual(configuration.step, 2)
        XCTAssertEqual(configuration.decimalPlaces, 0)
    }
}

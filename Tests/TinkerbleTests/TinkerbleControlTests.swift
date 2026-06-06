import XCTest
@testable import Tinkerble

final class TinkerbleControlTests: XCTestCase {
    func testStringControlsExposeFieldAreaAndAutomaticStyles() {
        XCTAssertEqual(
            TinkerbleControl<String>.field.descriptor,
            .text(.init(style: .field))
        )
        XCTAssertEqual(
            TinkerbleControl<String>.area.descriptor,
            .text(.init(style: .area))
        )
        XCTAssertEqual(
            TinkerbleControl<String>.text(.automatic).descriptor,
            .text(.init(style: .automatic))
        )
    }

    func testDefaultStringControlRemainsAutomaticControl() {
        XCTAssertEqual(TinkerbleControl<String>.automatic.descriptor, .automatic)
    }

    func testAutomaticTextControlUsesAreaPastTwentyFiveCharacters() {
        let control = TinkerbleTextControl(style: .automatic)

        XCTAssertEqual(control.resolvedStyle(for: String(repeating: "a", count: 25)), .field)
        XCTAssertEqual(control.resolvedStyle(for: String(repeating: "a", count: 26)), .area)
    }

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

    func testIntegerPlainDoesNotExposeDecimalPlaces() {
        let control = TinkerbleControl<Int>.plain(step: 2)

        guard case let .plain(configuration) = control.descriptor else {
            return XCTFail("Expected plain configuration")
        }

        XCTAssertEqual(configuration.step, 2)
        XCTAssertEqual(configuration.decimalPlaces, 0)
    }

    func testDecimalPlainDefaultsToTwoPlaces() {
        let control = TinkerbleControl<Double>.plain

        guard case let .plain(configuration) = control.descriptor else {
            return XCTFail("Expected plain configuration")
        }

        XCTAssertEqual(configuration.step, 1)
        XCTAssertEqual(configuration.decimalPlaces, 2)
    }

    @MainActor
    func testAutomaticNumericRegistrationResolvesToPlainControl() {
        Tinkerble.shared.resetForTesting()
        addTeardownBlock { @MainActor in
            Tinkerble.shared.resetForTesting()
        }

        Tinkerble.shared.register(
            id: "Count",
            category: nil,
            name: "Count",
            value: 3,
            control: .automatic,
            applyRemoteValue: { _ in }
        )

        XCTAssertEqual(
            Tinkerble.shared.registeredTweaks.first?.control,
            TinkerbleControl<Int>.plain.descriptor
        )
    }
}

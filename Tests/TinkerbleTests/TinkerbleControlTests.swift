import XCTest
import SwiftUI
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

    func testAnglePlainDefaultsToDegreesWithoutDecimalPlaces() {
        let control = TinkerbleControl<Angle>.plain

        guard case let .plain(configuration) = control.descriptor else {
            return XCTFail("Expected plain configuration")
        }

        XCTAssertEqual(configuration.angleUnit, .degrees)
        XCTAssertEqual(configuration.step, 1)
        XCTAssertEqual(configuration.decimalPlaces, 0)
    }

    func testAngleSliderUsesSelectedDegreeUnitAndRange() {
        let control = TinkerbleControl<Angle>.slider(.degrees(-45)...(.degrees(45)), unit: .degrees)

        guard case let .slider(configuration) = control.descriptor else {
            return XCTFail("Expected slider configuration")
        }

        XCTAssertEqual(configuration.angleUnit, .degrees)
        XCTAssertEqual(configuration.minimum, -45)
        XCTAssertEqual(configuration.maximum, 45)
        XCTAssertEqual(configuration.step, 1)
        XCTAssertEqual(configuration.decimalPlaces, 0)
    }

    func testAngleSliderCanDisplayRadians() {
        let control = TinkerbleControl<Angle>.slider(
            .radians(0)...(.radians(.pi)),
            unit: .radians,
            step: .radians(0.1),
            decimalPlaces: 3
        )

        guard case let .slider(configuration) = control.descriptor else {
            return XCTFail("Expected slider configuration")
        }

        XCTAssertEqual(configuration.angleUnit, .radians)
        XCTAssertEqual(configuration.minimum, 0)
        XCTAssertEqual(configuration.maximum ?? 0, Double.pi, accuracy: 0.0001)
        XCTAssertEqual(configuration.step, 0.1)
        XCTAssertEqual(configuration.decimalPlaces, 3)
    }

    func testAngleUnitConvertsBetweenDisplayValuesAndStoredRadians() {
        XCTAssertEqual(TinkerbleAngleUnit.degrees.displayValue(fromStoredRadians: Double.pi), 180, accuracy: 0.0001)
        XCTAssertEqual(TinkerbleAngleUnit.degrees.storedRadians(fromDisplayValue: 180), Double.pi, accuracy: 0.0001)
        XCTAssertEqual(TinkerbleAngleUnit.radians.displayValue(fromStoredRadians: Double.pi), Double.pi, accuracy: 0.0001)
        XCTAssertEqual(TinkerbleAngleUnit.radians.storedRadians(fromDisplayValue: Double.pi), Double.pi, accuracy: 0.0001)
    }

    func testDateControlsExposeDateTimeAndDateAndTimeComponents() {
        XCTAssertEqual(
            TinkerbleControl<Date>.date.descriptor,
            .date(.init(components: .date))
        )
        XCTAssertEqual(
            TinkerbleControl<Date>.dateAndTime.descriptor,
            .date(.init(components: .dateAndTime))
        )
        XCTAssertEqual(
            TinkerbleControl<Date>.time.descriptor,
            .date(.init(components: .time))
        )
        XCTAssertEqual(
            TinkerbleControl<Date>.datePicker(.time).descriptor,
            .date(.init(components: .time))
        )
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

    @MainActor
    func testAutomaticAngleAndDateRegistrationsResolveToMatchingControls() {
        Tinkerble.shared.resetForTesting()
        addTeardownBlock { @MainActor in
            Tinkerble.shared.resetForTesting()
        }

        Tinkerble.shared.register(
            id: "Rotation",
            category: nil,
            name: "Rotation",
            value: Angle.degrees(45),
            control: .automatic,
            applyRemoteValue: { _ in }
        )
        Tinkerble.shared.register(
            id: "Start",
            category: nil,
            name: "Start",
            value: Date(timeIntervalSinceReferenceDate: 804_729_600),
            control: .automatic,
            applyRemoteValue: { _ in }
        )

        XCTAssertEqual(
            Tinkerble.shared.registeredTweaks.first(where: { $0.id == "Rotation" })?.control,
            TinkerbleControl<Angle>.plain.descriptor
        )
        XCTAssertEqual(
            Tinkerble.shared.registeredTweaks.first(where: { $0.id == "Start" })?.control,
            TinkerbleControl<Date>.dateAndTime.descriptor
        )
    }
}

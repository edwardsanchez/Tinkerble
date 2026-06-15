import XCTest
import SwiftUI
@testable import Tinkerble
@testable import TinkerbleCompanionCore

final class TinkerbleComponentPreviewFixtureTests: XCTestCase {
    func testPreviewFixtureIncludesEveryCompanionComponent() {
        let tweaks = TinkerbleComponentPreviewFixture.tweaks

        XCTAssertEqual(
            tweaks.map(\.id),
            [
                "Text/String Field",
                "Text/String Area",
                "Text/Automatic Text Field",
                "Text/Automatic Text Area",
                "Values/Bool Toggle",
                "Values/Color Picker",
                "Numbers/Number Field",
                "Numbers/Number Slider",
                "Numbers/Decimal Range Slider",
                "Numbers/Angle Degrees Field",
                "Numbers/Angle Radians Slider",
                "Dates/Date Picker",
                "Dates/Date And Time Picker",
                "Dates/Time Picker",
                "Values/Enum Picker",
            ]
        )

        XCTAssertEqual(
            Set(tweaks.map(\.valueKind)),
            [.string, .bool, .color, .number, .date, .enumeration]
        )
        XCTAssertTrue(tweaks.contains { $0.control == .text(.init(style: .field)) })
        XCTAssertTrue(tweaks.contains { $0.control == .text(.init(style: .area)) })
        XCTAssertTrue(tweaks.contains { $0.control == .automatic && $0.valueKind == .bool })
        XCTAssertTrue(tweaks.contains { $0.control == .automatic && $0.valueKind == .color })
        XCTAssertTrue(tweaks.contains { $0.control == .plain(.init(decimalPlaces: 0)) && $0.valueKind == .number })
        XCTAssertTrue(tweaks.contains { $0.control == .slider(.init(minimum: 0, maximum: 1, step: 0.01, decimalPlaces: 2)) })
        XCTAssertTrue(tweaks.contains { $0.control == .slider(.init(minimum: 0, maximum: 20, step: 0.01, decimalPlaces: 2)) })
        XCTAssertTrue(tweaks.contains { $0.control == .plain(.init(step: 1, decimalPlaces: 0, angleUnit: .degrees)) })
        XCTAssertTrue(tweaks.contains { $0.control == .slider(.init(minimum: 0, maximum: .pi, step: 0.01, decimalPlaces: 2, angleUnit: .radians)) })
        XCTAssertTrue(tweaks.contains { $0.control == TinkerbleControl<Date>.date.descriptor })
        XCTAssertTrue(tweaks.contains { $0.control == TinkerbleControl<Date>.dateAndTime.descriptor })
        XCTAssertTrue(tweaks.contains { $0.control == TinkerbleControl<Date>.time.descriptor })
        XCTAssertTrue(tweaks.contains { $0.valueKind == .enumeration && $0.enumOptions.count == 3 })
    }

    func testAutomaticTextFixturesPreviewFieldAndAreaResolutions() {
        let resolvedAutomaticStyles = TinkerbleComponentPreviewFixture.tweaks.compactMap { tweak -> TinkerbleTextControlStyle? in
            guard case let .text(configuration) = tweak.control,
                  configuration.style == .automatic,
                  case let .string(value) = tweak.value else {
                return nil
            }
            return configuration.resolvedStyle(for: value)
        }

        XCTAssertEqual(Set(resolvedAutomaticStyles), [.field, .area])
    }

    func testPreviewFixtureIncludesZeroToTwentyDecimalSlider() throws {
        let tweak = try XCTUnwrap(
            TinkerbleComponentPreviewFixture.tweaks.first { $0.id == "Numbers/Decimal Range Slider" }
        )

        XCTAssertEqual(tweak.category, "Numbers")
        XCTAssertEqual(tweak.name, "Decimal Range Slider")
        XCTAssertEqual(tweak.value, .number(12.5))
        XCTAssertEqual(tweak.valueKind, .number)
        XCTAssertEqual(tweak.control, .slider(.init(minimum: 0, maximum: 20, step: 0.01, decimalPlaces: 2)))
    }

    func testPreviewFixtureBuildsScrollableGroups() {
        let groups = TinkerbleComponentPreviewFixture.groups

        XCTAssertEqual(groups.map(\.category), ["Dates", "Numbers", "Text", "Values"])
        XCTAssertEqual(groups.flatMap(\.tweaks).count, TinkerbleComponentPreviewFixture.tweaks.count)
    }

}

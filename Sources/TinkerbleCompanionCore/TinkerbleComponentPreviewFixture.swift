import Foundation
import SwiftUI
import Tinkerble

public enum TinkerbleComponentPreviewFixture {
    public static var tweaks: [TinkerbleTweak] {
        [
            TinkerbleTweak(
                id: "Text/String Field",
                category: "Text",
                name: "String Field",
                value: .string("Hello Tinkerble"),
                valueKind: .string,
                control: .text(.init(style: .field))
            ),
            TinkerbleTweak(
                id: "Text/String Area",
                category: "Text",
                name: "String Area",
                value: .string("A longer editable note that renders in the multiline text area control."),
                valueKind: .string,
                control: .text(.init(style: .area))
            ),
            TinkerbleTweak(
                id: "Text/Automatic Text Field",
                category: "Text",
                name: "Automatic Text Field",
                value: .string("Short copy"),
                valueKind: .string,
                control: .text(.init(style: .automatic))
            ),
            TinkerbleTweak(
                id: "Text/Automatic Text Area",
                category: "Text",
                name: "Automatic Text Area",
                value: .string("Automatic text controls switch to the larger editor when the value is long enough."),
                valueKind: .string,
                control: .text(.init(style: .automatic))
            ),
            TinkerbleTweak(
                id: "Values/Bool Toggle",
                category: "Values",
                name: "Bool Toggle",
                value: .bool(true),
                valueKind: .bool,
                control: .automatic
            ),
            TinkerbleTweak(
                id: "Values/Color Picker",
                category: "Values",
                name: "Color Picker",
                value: .color(.init(red: 0.96, green: 0.72, blue: 0.24)),
                valueKind: .color,
                control: .automatic
            ),
            TinkerbleTweak(
                id: "Numbers/Number Field",
                category: "Numbers",
                name: "Number Field",
                value: .number(42),
                valueKind: .number,
                control: .plain(.init(decimalPlaces: 0))
            ),
            TinkerbleTweak(
                id: "Numbers/Number Slider",
                category: "Numbers",
                name: "Number Slider",
                value: .number(0.65),
                valueKind: .number,
                control: .slider(.init(minimum: 0, maximum: 1, step: 0.01, decimalPlaces: 2))
            ),
            TinkerbleTweak(
                id: "Numbers/Decimal Range Slider",
                category: "Numbers",
                name: "Decimal Range Slider",
                value: .number(12.5),
                valueKind: .number,
                control: .slider(.init(minimum: 0, maximum: 20, step: 0.01, decimalPlaces: 2))
            ),
            TinkerbleTweak(
                id: "Numbers/Angle Degrees Field",
                category: "Numbers",
                name: "Angle Degrees Field",
                value: .number(Angle.degrees(45).radians),
                valueKind: .number,
                control: .plain(.init(step: 1, decimalPlaces: 0, angleUnit: .degrees))
            ),
            TinkerbleTweak(
                id: "Numbers/Angle Radians Slider",
                category: "Numbers",
                name: "Angle Radians Slider",
                value: .number(Angle.radians(1.57).radians),
                valueKind: .number,
                control: .slider(.init(minimum: 0, maximum: .pi, step: 0.01, decimalPlaces: 2, angleUnit: .radians))
            ),
            TinkerbleTweak(
                id: "Dates/Date Picker",
                category: "Dates",
                name: "Date Picker",
                value: .date(Date(timeIntervalSinceReferenceDate: 804_729_600)),
                valueKind: .date,
                control: .date(.init(components: .date))
            ),
            TinkerbleTweak(
                id: "Dates/Date And Time Picker",
                category: "Dates",
                name: "Date And Time Picker",
                value: .date(Date(timeIntervalSinceReferenceDate: 804_729_600)),
                valueKind: .date,
                control: .date(.init(components: .dateAndTime))
            ),
            TinkerbleTweak(
                id: "Dates/Time Picker",
                category: "Dates",
                name: "Time Picker",
                value: .date(Date(timeIntervalSinceReferenceDate: 804_729_600)),
                valueKind: .date,
                control: .date(.init(components: .time))
            ),
            TinkerbleTweak(
                id: "Values/Enum Picker",
                category: "Values",
                name: "Enum Picker",
                value: .enumCase("balanced"),
                valueKind: .enumeration,
                control: .automatic,
                enumOptions: [
                    .init(id: "compact", displayName: "Compact"),
                    .init(id: "balanced", displayName: "Balanced"),
                    .init(id: "expanded", displayName: "Expanded"),
                ]
            ),
        ]
    }

    public static var groups: [TinkerbleTweakGroup] {
        TinkerbleTweakGrouping.groupedTweaks(from: tweaks)
    }
}

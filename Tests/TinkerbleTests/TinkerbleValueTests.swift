import XCTest
import SwiftUI
@testable import Tinkerble

private enum DemoMode: String, CaseIterable, TinkerbleEnum {
    case compact
    case expanded
}

final class TinkerbleValueTests: XCTestCase {
    func testStringBoolAndNumbersRoundTripThroughValueRepresentation() {
        XCTAssertEqual(String.fromTinkerbleValue("Hello".tinkerbleValue), "Hello")
        XCTAssertEqual(Bool.fromTinkerbleValue(true.tinkerbleValue), true)
        XCTAssertEqual(Int.fromTinkerbleValue(12.tinkerbleValue), 12)
        XCTAssertEqual(Double.fromTinkerbleValue(0.75.tinkerbleValue), 0.75)
    }

    func testAngleRoundTripsThroughCanonicalRadianNumberRepresentation() {
        let angle = Angle.degrees(90)

        XCTAssertEqual(angle.tinkerbleValue, .number(Double.pi / 2))
        XCTAssertEqual(Angle.fromTinkerbleValue(angle.tinkerbleValue)?.degrees ?? 0, 90, accuracy: 0.0001)
    }

    func testDateRoundTripsThroughDateValueRepresentation() {
        let date = Date(timeIntervalSinceReferenceDate: 804_729_600)

        XCTAssertEqual(date.tinkerbleValue, .date(date))
        XCTAssertEqual(Date.fromTinkerbleValue(date.tinkerbleValue), date)
        XCTAssertEqual(date.tinkerbleValue.kind, .date)
    }

    func testActionValueUsesActionKind() {
        XCTAssertEqual(TinkerbleValue.action.kind, .action)
    }

    func testBasicRawRepresentableEnumsExposePickerOptions() {
        XCTAssertEqual(DemoMode.compact.tinkerbleValue, .enumCase("compact"))
        XCTAssertEqual(DemoMode.fromTinkerbleValue(.enumCase("expanded")), .expanded)
        XCTAssertEqual(
            DemoMode.tinkerbleEnumOptions,
            [
                TinkerbleEnumOption(id: "compact", displayName: "Compact"),
                TinkerbleEnumOption(id: "expanded", displayName: "Expanded"),
            ]
        )
    }

    func testRSocketPayloadCodecRoundTripsMessages() throws {
        let codec = TinkerbleRSocketPayloadCodec()
        let tweak = TinkerbleTweak(
            id: "Layout/Opacity",
            screen: "Fan Deck",
            category: "Layout",
            name: "Opacity",
            value: .number(0.5),
            valueKind: .number,
            control: TinkerbleControl<Double>.slider(0...1).descriptor
        )

        let payload = try codec.payload(for: .register(tweak))
        let decoded = try codec.message(from: payload)

        XCTAssertEqual(decoded, .register(tweak))
    }

    func testRSocketPayloadCodecRoundTripsHelloProjectIdentity() throws {
        let codec = TinkerbleRSocketPayloadCodec()
        let project = TinkerbleProjectIdentity(id: "app.test", displayName: "Test App")

        let payload = try codec.payload(for: .hello(role: .iOSApp, version: "0.1.0", project: project))
        let decoded = try codec.message(from: payload)

        XCTAssertEqual(decoded, .hello(role: .iOSApp, version: "0.1.0", project: project))
    }

    func testTweakDefaultsMissingScreenToDefaultDuringDecoding() throws {
        let encoded = try JSONEncoder().encode(
            TinkerbleTweak(
                id: "Layout/Opacity",
                category: "Layout",
                name: "Opacity",
                value: .number(0.5),
                valueKind: .number,
                control: .automatic
            )
        )
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        json.removeValue(forKey: "screen")
        let data = try JSONSerialization.data(withJSONObject: json)

        let tweak = try JSONDecoder().decode(TinkerbleTweak.self, from: data)

        XCTAssertEqual(tweak.screen, TinkerbleTweak.defaultScreenName)
    }

    func testTweakIDKeepsDefaultScreenIDsCompatibleAndPrefixesNamedScreens() {
        XCTAssertEqual(
            TinkerbleTweak.makeID(category: "Layout", name: "Opacity"),
            "Layout/Opacity"
        )
        XCTAssertEqual(
            TinkerbleTweak.makeID(screen: "Fan Deck", category: "Layout", name: "Opacity"),
            "Fan Deck/Layout/Opacity"
        )
        XCTAssertEqual(
            TinkerbleTweak.makeID(screen: "  ", category: nil, name: "Title"),
            "Title"
        )
    }

    func testRSocketPayloadCodecRoundTripsUnregisterMessages() throws {
        let codec = TinkerbleRSocketPayloadCodec()

        let payload = try codec.payload(for: .unregister(id: "Lifetime State/Message"))
        let decoded = try codec.message(from: payload)

        XCTAssertEqual(decoded, .unregister(id: "Lifetime State/Message"))
    }

    func testRSocketPayloadCodecRoundTripsTriggerMessages() throws {
        let codec = TinkerbleRSocketPayloadCodec()

        let payload = try codec.payload(for: .trigger(id: "Fan Deck/Animation/Toggle Fan"))
        let decoded = try codec.message(from: payload)

        XCTAssertEqual(decoded, .trigger(id: "Fan Deck/Animation/Toggle Fan"))
    }

    func testRSocketPayloadCodecRoundTripsTextControlDescriptors() throws {
        let codec = TinkerbleRSocketPayloadCodec()
        let tweak = TinkerbleTweak(
            id: "Copy/Message",
            category: "Copy",
            name: "Message",
            value: .string("Longer message"),
            valueKind: .string,
            control: TinkerbleControl<String>.text(.automatic).descriptor
        )

        let payload = try codec.payload(for: .register(tweak))
        let decoded = try codec.message(from: payload)

        XCTAssertEqual(decoded, .register(tweak))
    }

    func testRSocketPayloadCodecRoundTripsAngleAndDateControlDescriptors() throws {
        let codec = TinkerbleRSocketPayloadCodec()
        let tweaks = [
            TinkerbleTweak(
                id: "Layout/Rotation",
                category: "Layout",
                name: "Rotation",
                value: Angle.degrees(45).tinkerbleValue,
                valueKind: .number,
                control: TinkerbleControl<Angle>.slider(.degrees(0)...(.degrees(360))).descriptor
            ),
            TinkerbleTweak(
                id: "Schedule/Start",
                category: "Schedule",
                name: "Start",
                value: Date(timeIntervalSinceReferenceDate: 804_729_600).tinkerbleValue,
                valueKind: .date,
                control: TinkerbleControl<Date>.datePicker(.dateAndTime).descriptor
            ),
        ]

        let payload = try codec.payload(for: .snapshot(tweaks))
        let decoded = try codec.message(from: payload)

        XCTAssertEqual(decoded, .snapshot(tweaks))
    }
}

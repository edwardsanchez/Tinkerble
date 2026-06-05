import XCTest
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

    func testRSocketPayloadCodecRoundTripsUnregisterMessages() throws {
        let codec = TinkerbleRSocketPayloadCodec()

        let payload = try codec.payload(for: .unregister(id: "Lifetime State/Message"))
        let decoded = try codec.message(from: payload)

        XCTAssertEqual(decoded, .unregister(id: "Lifetime State/Message"))
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
}

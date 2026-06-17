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
                TinkerbleEnumOption(id: "expanded", displayName: "Expanded")
            ]
        )
    }

    func testSocketMessageCodecRoundTripsMessages() throws {
        let codec = TinkerbleSocketMessageCodec()
        let tweak = TinkerbleTweak(
            id: "Layout/Opacity",
            screen: "Fan Deck",
            category: "Layout",
            name: "Opacity",
            value: .number(0.5),
            valueKind: .number,
            control: TinkerbleControl<Double>.slider(0...1).descriptor
        )

        let data = try codec.data(for: .register(tweak))
        let decoded = try codec.message(from: data)

        XCTAssertEqual(decoded, .register(tweak))
    }

    func testSocketMessageCodecRoundTripsHelloProjectIdentity() throws {
        let codec = TinkerbleSocketMessageCodec()
        let project = TinkerbleProjectIdentity(id: "app.test", displayName: "Test App")

        let data = try codec.data(for: .hello(role: .iOSApp, version: "0.1.0", project: project))
        let decoded = try codec.message(from: data)

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

    func testSocketMessageCodecRoundTripsUnregisterMessages() throws {
        let codec = TinkerbleSocketMessageCodec()

        let data = try codec.data(for: .unregister(id: "Lifetime State/Message"))
        let decoded = try codec.message(from: data)

        XCTAssertEqual(decoded, .unregister(id: "Lifetime State/Message"))
    }

    func testSocketMessageCodecRoundTripsTriggerMessages() throws {
        let codec = TinkerbleSocketMessageCodec()

        let data = try codec.data(for: .trigger(id: "Fan Deck/Animation/Toggle Fan"))
        let decoded = try codec.message(from: data)

        XCTAssertEqual(decoded, .trigger(id: "Fan Deck/Animation/Toggle Fan"))
    }

    func testSocketMessageCodecRoundTripsTextControlDescriptors() throws {
        let codec = TinkerbleSocketMessageCodec()
        let tweak = TinkerbleTweak(
            id: "Copy/Message",
            category: "Copy",
            name: "Message",
            value: .string("Longer message"),
            valueKind: .string,
            control: TinkerbleControl<String>.text(.automatic).descriptor
        )

        let data = try codec.data(for: .register(tweak))
        let decoded = try codec.message(from: data)

        XCTAssertEqual(decoded, .register(tweak))
    }

    func testSocketMessageCodecRoundTripsAngleAndDateControlDescriptors() throws {
        let codec = TinkerbleSocketMessageCodec()
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
            )
        ]

        let data = try codec.data(for: .snapshot(tweaks))
        let decoded = try codec.message(from: data)

        XCTAssertEqual(decoded, .snapshot(tweaks))
    }

    func testSocketMessageCodecDecodesMultipleLengthPrefixedFramesFromBuffer() throws {
        let codec = TinkerbleSocketMessageCodec()
        let logEntry = TinkerbleLogEntry(name: "First", value: "Ready")
        var buffer = Data()
        buffer.append(try codec.frame(for: .log(logEntry)))
        buffer.append(try codec.frame(for: .trigger(id: "Actions/Refresh")))

        let messages = try codec.messages(fromBufferedData: &buffer)

        XCTAssertEqual(messages, [.log(logEntry), .trigger(id: "Actions/Refresh")])
        XCTAssertTrue(buffer.isEmpty)
    }

    func testSocketMessageCodecKeepsPartialFrameBuffered() throws {
        let codec = TinkerbleSocketMessageCodec()
        let logEntry = TinkerbleLogEntry(name: "Partial", value: "Buffered")
        let frame = try codec.frame(for: .log(logEntry))
        var buffer = Data(frame.prefix(frame.count - 2))

        XCTAssertEqual(try codec.messages(fromBufferedData: &buffer), [])

        buffer.append(frame.suffix(2))

        XCTAssertEqual(try codec.messages(fromBufferedData: &buffer), [.log(logEntry)])
        XCTAssertTrue(buffer.isEmpty)
    }

    func testSocketMessageCodecRoundTripsColorLogValues() throws {
        let codec = TinkerbleSocketMessageCodec()
        let logEntry = TinkerbleLogEntry(
            screen: "Logs Demo",
            category: "Color",
            name: "Resolved Color",
            value: TinkerbleLogValue.color(TinkerbleColor(red: 1, green: 0.5, blue: 0, alpha: 0.25))
        )

        let data = try codec.data(for: .log(logEntry))
        let decoded = try codec.message(from: data)

        XCTAssertEqual(decoded, .log(logEntry))
    }

    func testSocketMessageCodecRoundTripsComponentLogValues() throws {
        let codec = TinkerbleSocketMessageCodec()
        let logEntry = TinkerbleLogEntry(
            screen: "Logs Demo",
            category: "Motion",
            name: "Velocity",
            value: CGVector(dx: -12.5, dy: 3)
        )

        let data = try codec.data(for: .log(logEntry))
        let decoded = try codec.message(from: data)

        XCTAssertEqual(decoded, .log(logEntry))
    }

    func testSocketMessageCodecRoundTripsLogDecimalPlaces() throws {
        let codec = TinkerbleSocketMessageCodec()
        let logEntry = TinkerbleLogEntry(name: "Velocity", value: 12.999, decimalPlaces: 2)

        let data = try codec.data(for: .log(logEntry))
        let decoded = try codec.message(from: data)

        XCTAssertEqual(decoded, .log(logEntry))
    }

    func testSocketMessageCodecRejectsOversizedInboundFrame() {
        let codec = TinkerbleSocketMessageCodec()
        var oversizedLength = UInt32(TinkerbleSocketMessageCodec.maximumPayloadSize + 1).bigEndian
        var buffer = Data()
        withUnsafeBytes(of: &oversizedLength) { bytes in
            buffer.append(contentsOf: bytes)
        }

        XCTAssertThrowsError(try codec.messages(fromBufferedData: &buffer)) { error in
            XCTAssertEqual(
                error as? TinkerbleSocketMessageCodecError,
                .payloadTooLarge(TinkerbleSocketMessageCodec.maximumPayloadSize + 1)
            )
        }
    }

    func testSocketMessageCodecRejectsOversizedOutboundFrame() {
        let codec = TinkerbleSocketMessageCodec()
        let message = String(repeating: "x", count: TinkerbleSocketMessageCodec.maximumPayloadSize + 1)

        let entry = TinkerbleLogEntry(name: "Oversized", value: message)

        XCTAssertThrowsError(try codec.frame(for: .log(entry))) { error in
            guard case .payloadTooLarge = error as? TinkerbleSocketMessageCodecError else {
                XCTFail("Expected oversized payload error, got \(error)")
                return
            }
        }
    }
}

import SwiftUI
import XCTest
@testable import Tinkerble

#if canImport(AppKit)
import AppKit
#endif

@MainActor
final class TinkerbleLogAPITests: XCTestCase {
    func testTinkerLogValueSendsStructuredLogEntry() async {
        let transport = LogRecordingTransport()
        Tinkerble.shared.resetForTesting(transport: transport)
        defer {
            Tinkerble.shared.resetForTesting()
        }

        TinkerLog.value(name: "Visible Cards", value: 7, screen: "Cards", category: "Deck")

        let sentEntry = await waitUntil {
            transport.sentMessages.compactMap(\.loggedEntry).first
        }

        XCTAssertEqual(sentEntry?.screen, "Cards")
        XCTAssertEqual(sentEntry?.category, "Deck")
        XCTAssertEqual(sentEntry?.name, "Visible Cards")
        XCTAssertEqual(sentEntry?.value, .int(7))
    }

    func testTinkerLogValueSendsDecimalPlaceOverride() async {
        let transport = LogRecordingTransport()
        Tinkerble.shared.resetForTesting(transport: transport)
        defer {
            Tinkerble.shared.resetForTesting()
        }

        TinkerLog.value(name: "Velocity", value: 12.999, decimalPlaces: 2)

        let sentEntry = await waitUntil {
            transport.sentMessages.compactMap(\.loggedEntry).first
        }

        XCTAssertEqual(sentEntry?.decimalPlaces, 2)
        XCTAssertEqual(sentEntry?.displayValue, "12.99")
    }

    func testTinkerbleSharedLogDefaultsMissingCategory() {
        let transport = LogRecordingTransport()
        Tinkerble.shared.resetForTesting(transport: transport)
        defer {
            Tinkerble.shared.resetForTesting()
        }

        Tinkerble.shared.log(name: "FPS", value: 58.5)

        let entry = transport.sentMessages.compactMap(\.loggedEntry).first

        XCTAssertEqual(entry?.screen, TinkerbleTweak.defaultScreenName)
        XCTAssertEqual(entry?.category, TinkerbleLogEntry.defaultCategoryName)
        XCTAssertEqual(entry?.name, "FPS")
        XCTAssertEqual(entry?.value, .double(58.5))
    }

    func testDoubleLogValueDisplaysTruncatedDefaultDecimalPlace() {
        let entry = TinkerbleLogEntry(name: "FPS", value: 58.29)

        XCTAssertEqual(entry.displayValue, "58.2")
    }

    func testDoubleLogValuePadsDefaultDecimalPlace() {
        let entry = TinkerbleLogEntry(name: "FPS", value: 58.0)

        XCTAssertEqual(entry.displayValue, "58.0")
    }

    func testDoubleLogValueUsesDecimalPlaceOverride() {
        let noDecimals = TinkerbleLogEntry(name: "FPS", value: 58.9, decimalPlaces: 0)
        let twoDecimals = TinkerbleLogEntry(name: "FPS", value: 58.999, decimalPlaces: 2)

        XCTAssertEqual(noDecimals.displayValue, "58")
        XCTAssertEqual(twoDecimals.displayValue, "58.99")
    }

    func testTinkerbleSharedLogSendsDecimalPlaceOverride() {
        let transport = LogRecordingTransport()
        Tinkerble.shared.resetForTesting(transport: transport)
        defer {
            Tinkerble.shared.resetForTesting()
        }

        Tinkerble.shared.log(name: "FPS", value: 58.999, decimalPlaces: 2)

        let entry = transport.sentMessages.compactMap(\.loggedEntry).first

        XCTAssertEqual(entry?.decimalPlaces, 2)
        XCTAssertEqual(entry?.displayValue, "58.99")
    }

    func testTinkerbleSharedLogAcceptsCoreGraphicsCompoundValues() {
        let transport = LogRecordingTransport()
        Tinkerble.shared.resetForTesting(transport: transport)
        defer {
            Tinkerble.shared.resetForTesting()
        }

        Tinkerble.shared.log(name: "Position", value: CGPoint(x: 12.5, y: 48))
        Tinkerble.shared.log(name: "Size", value: CGSize(width: 320, height: 240.25))
        Tinkerble.shared.log(name: "Frame", value: CGRect(x: 1, y: 2, width: 3, height: 4))
        Tinkerble.shared.log(name: "Vector", value: CGVector(dx: -6.5, dy: 7))
        Tinkerble.shared.log(name: "Transform", value: CGAffineTransform(a: 1, b: 2, c: 3, d: 4, tx: 5, ty: 6))

        let sentValues = transport.sentMessages.compactMap(\.loggedEntry).map(\.value)

        XCTAssertEqual(sentValues, [
            .components([
                .init(label: "x", value: 12.5),
                .init(label: "y", value: 48)
            ]),
            .components([
                .init(label: "width", value: 320),
                .init(label: "height", value: 240.25)
            ]),
            .components([
                .init(label: "x", value: 1),
                .init(label: "y", value: 2),
                .init(label: "width", value: 3),
                .init(label: "height", value: 4)
            ]),
            .components([
                .init(label: "dx", value: -6.5),
                .init(label: "dy", value: 7)
            ]),
            .components([
                .init(label: "a", value: 1),
                .init(label: "b", value: 2),
                .init(label: "c", value: 3),
                .init(label: "d", value: 4),
                .init(label: "tx", value: 5),
                .init(label: "ty", value: 6)
            ])
        ])
    }

    func testTinkerbleSharedLogAppliesDecimalPlaceOverrideToCompoundValues() {
        let transport = LogRecordingTransport()
        Tinkerble.shared.resetForTesting(transport: transport)
        defer {
            Tinkerble.shared.resetForTesting()
        }

        Tinkerble.shared.log(name: "Position", value: CGPoint(x: 12.9, y: 48.1), decimalPlaces: 0)

        let entry = transport.sentMessages.compactMap(\.loggedEntry).first

        XCTAssertEqual(entry?.value, .components([
            .init(label: "x", value: 12.9),
            .init(label: "y", value: 48.1)
        ]))
        XCTAssertEqual(entry?.displayValue, "x 12, y 48")
    }

    func testCompoundLogValueDisplaysLabelsWithoutColonsAndKeepsNegativeSign() {
        let entry = TinkerbleLogEntry(name: "Velocity", value: CGVector(dx: -6.5, dy: 7))

        XCTAssertEqual(entry.displayValue, "dx -6.5, dy 7.0")
    }

    func testTinkerbleSharedLogAcceptsSwiftUIColorValues() throws {
        let transport = LogRecordingTransport()
        Tinkerble.shared.resetForTesting(transport: transport)
        defer {
            Tinkerble.shared.resetForTesting()
        }

        Tinkerble.shared.log(
            name: "Resolved Color",
            value: Color(red: 0.25, green: 0.5, blue: 0.75, opacity: 0.8)
        )

        let entry = try XCTUnwrap(transport.sentMessages.compactMap(\.loggedEntry).first)
        guard case let .color(color) = entry.value else {
            return XCTFail("Expected color log value.")
        }

        XCTAssertEqual(color.red, 0.25, accuracy: 0.001)
        XCTAssertEqual(color.green, 0.5, accuracy: 0.001)
        XCTAssertEqual(color.blue, 0.75, accuracy: 0.001)
        XCTAssertEqual(color.alpha, 0.8, accuracy: 0.001)
    }

    func testColorLogValueDisplaysRGBAInSingleValue() {
        let value = TinkerbleLogValue.color(
            TinkerbleColor(red: 1, green: 0.5, blue: 0, alpha: 0.25)
        )

        XCTAssertEqual(value.displayValue, "R 255 G 128 B 000 A 0.25")
    }

    #if canImport(AppKit)
    func testTinkerbleSharedLogAcceptsAppKitColorValues() throws {
        let transport = LogRecordingTransport()
        Tinkerble.shared.resetForTesting(transport: transport)
        defer {
            Tinkerble.shared.resetForTesting()
        }

        Tinkerble.shared.log(
            name: "Resolved Color",
            value: NSColor(srgbRed: 0.1, green: 0.2, blue: 0.3, alpha: 0.4)
        )

        let entry = try XCTUnwrap(transport.sentMessages.compactMap(\.loggedEntry).first)
        guard case let .color(color) = entry.value else {
            return XCTFail("Expected color log value.")
        }

        XCTAssertEqual(color.red, 0.1, accuracy: 0.001)
        XCTAssertEqual(color.green, 0.2, accuracy: 0.001)
        XCTAssertEqual(color.blue, 0.3, accuracy: 0.001)
        XCTAssertEqual(color.alpha, 0.4, accuracy: 0.001)
    }
    #endif

    private func waitUntil<T>(
        timeout: Duration = .seconds(1),
        condition: @escaping @MainActor () -> T?
    ) async -> T? {
        let start = ContinuousClock.now
        while start.duration(to: .now) < timeout {
            if let value = condition() {
                return value
            }
            try? await Task.sleep(for: .milliseconds(10))
        }
        return condition()
    }
}

private final class LogRecordingTransport: TinkerbleClientTransport {
    var onMessage: ((TinkerbleWireMessage) -> Void)?
    var onStatusChange: ((TinkerbleConnectionStatus) -> Void)?
    var sentMessages: [TinkerbleWireMessage] = []

    func connect(host: String?, port: Int) {}

    func send(_ message: TinkerbleWireMessage) {
        sentMessages.append(message)
    }

    func disconnect() {}
}

private extension TinkerbleWireMessage {
    var loggedEntry: TinkerbleLogEntry? {
        guard case let .log(entry) = self else { return nil }
        return entry
    }
}

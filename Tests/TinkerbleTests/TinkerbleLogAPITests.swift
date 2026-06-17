import XCTest
@testable import Tinkerble

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
            .string("x: 12.5, y: 48.0"),
            .string("width: 320.0, height: 240.25"),
            .string("x: 1.0, y: 2.0, width: 3.0, height: 4.0"),
            .string("dx: -6.5, dy: 7.0"),
            .string("a: 1.0, b: 2.0, c: 3.0, d: 4.0, tx: 5.0, ty: 6.0")
        ])
    }

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

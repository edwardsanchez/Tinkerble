import XCTest
@testable import Tinkerble

@MainActor
final class TinkerbleRegistrationLifetimeTests: XCTestCase {
    func testTinkerbleStateBoxUnregistersWhenDeallocated() async {
        let transport = LifetimeRecordingTransport()
        Tinkerble.shared.resetForTesting(transport: transport)
        addTeardownBlock { @MainActor in
            Tinkerble.shared.resetForTesting()
        }

        var box: TinkerbleStateBox<String>? = TinkerbleStateBox(
            initialValue: "Loaded",
            category: "Lifetime State",
            name: "Message",
            control: .automatic
        )

        XCTAssertEqual(Tinkerble.shared.registeredTweaks.map(\.id), ["Lifetime State/Message"])
        XCTAssertEqual(transport.sentMessages.compactMap(\.registeredTweak).map(\.id), ["Lifetime State/Message"])
        XCTAssertNotNil(box)

        box = nil

        await waitUntil { Tinkerble.shared.registeredTweaks.isEmpty }
        XCTAssertTrue(Tinkerble.shared.registeredTweaks.isEmpty)
        XCTAssertEqual(transport.sentMessages.last, .unregister(id: "Lifetime State/Message"))
    }

    func testDuplicateLiveRegistrationsRemainVisibleUntilLastTokenUnregisters() async {
        let transport = LifetimeRecordingTransport()
        Tinkerble.shared.resetForTesting(transport: transport)
        addTeardownBlock { @MainActor in
            Tinkerble.shared.resetForTesting()
        }

        var firstValue = "First"
        var secondValue = "Second"
        let firstToken = Tinkerble.shared.register(
            id: "Shared/Title",
            category: "Shared",
            name: "Title",
            value: firstValue,
            control: .automatic,
            applyRemoteValue: { firstValue = $0 }
        )
        let secondToken = Tinkerble.shared.register(
            id: "Shared/Title",
            category: "Shared",
            name: "Title",
            value: secondValue,
            control: .automatic,
            applyRemoteValue: { secondValue = $0 }
        )

        XCTAssertEqual(Tinkerble.shared.registeredTweaks.map(\.id), ["Shared/Title"])
        XCTAssertEqual(transport.sentMessages.compactMap(\.registeredTweak).map(\.id), ["Shared/Title"])
        XCTAssertEqual(secondValue, "First")

        transport.receive(.update(id: "Shared/Title", value: .string("Remote")))
        await waitUntil { firstValue == "Remote" && secondValue == "Remote" }

        transport.sentMessages.removeAll()
        Tinkerble.shared.unregister(firstToken)

        XCTAssertEqual(Tinkerble.shared.registeredTweaks.map(\.id), ["Shared/Title"])
        XCTAssertTrue(transport.sentMessages.isEmpty)

        Tinkerble.shared.unregister(secondToken)

        XCTAssertTrue(Tinkerble.shared.registeredTweaks.isEmpty)
        XCTAssertEqual(transport.sentMessages, [.unregister(id: "Shared/Title")])
    }

    private func waitUntil(
        timeout: TimeInterval = 5,
        condition: @escaping @MainActor () -> Bool
    ) async {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() {
                return
            }
            try? await Task.sleep(for: .milliseconds(50))
        }
    }
}

private final class LifetimeRecordingTransport: TinkerbleClientTransport {
    var onMessage: ((TinkerbleWireMessage) -> Void)?
    var onStatusChange: ((TinkerbleConnectionStatus) -> Void)?
    var sentMessages: [TinkerbleWireMessage] = []

    func connect(host: String, port: Int) {}

    func send(_ message: TinkerbleWireMessage) {
        sentMessages.append(message)
    }

    func disconnect() {}

    func receive(_ message: TinkerbleWireMessage) {
        onMessage?(message)
    }
}

private extension TinkerbleWireMessage {
    var registeredTweak: TinkerbleTweak? {
        guard case let .register(tweak) = self else { return nil }
        return tweak
    }
}

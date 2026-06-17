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

    func testTinkerbleStateBoxRegistersNamedScreen() {
        let transport = LifetimeRecordingTransport()
        Tinkerble.shared.resetForTesting(transport: transport)
        addTeardownBlock { @MainActor in
            Tinkerble.shared.resetForTesting()
        }

        let box = TinkerbleStateBox<String>(
            initialValue: "Loaded",
            screen: "Fan Deck",
            category: "Deck",
            name: "Title",
            control: .automatic
        )

        XCTAssertEqual(Tinkerble.shared.registeredTweaks.map(\.id), ["Fan Deck/Deck/Title"])
        XCTAssertEqual(Tinkerble.shared.registeredTweaks.map(\.screen), ["Fan Deck"])
        XCTAssertNotNil(box)
    }

    func testObservableStateRegistrationRegistersNamedScreen() {
        let transport = LifetimeRecordingTransport()
        Tinkerble.shared.resetForTesting(transport: transport)
        addTeardownBlock { @MainActor in
            Tinkerble.shared.resetForTesting()
        }
        let owner = ScreenRegistrationOwner()
        let registration = TinkerbleObservableStateRegistration()

        registration.activate(
            owner: owner,
            initialValue: "Loaded",
            name: "Title",
            screen: "Basic",
            category: "Layout",
            control: .automatic,
            applyRemoteValue: { owner, value in
                owner.value = value
            }
        )

        XCTAssertEqual(Tinkerble.shared.registeredTweaks.map(\.id), ["Basic/Layout/Title"])
        XCTAssertEqual(Tinkerble.shared.registeredTweaks.map(\.screen), ["Basic"])
    }

    func testActionRegistrationRegistersNamedScreenAndRunsOnTrigger() async {
        let transport = LifetimeRecordingTransport()
        Tinkerble.shared.resetForTesting(transport: transport)
        addTeardownBlock { @MainActor in
            Tinkerble.shared.resetForTesting()
        }
        let owner = ActionRegistrationOwner()
        let registration = TinkerbleActionRegistration()

        registration.activate(
            owner: owner,
            name: "Toggle Fan",
            screen: "Fan Deck",
            category: "Animation",
            perform: { owner in
                owner.runCount += 1
            }
        )

        XCTAssertEqual(Tinkerble.shared.registeredTweaks.map(\.id), ["Fan Deck/Animation/Toggle Fan"])
        XCTAssertEqual(Tinkerble.shared.registeredTweaks.map(\.screen), ["Fan Deck"])
        XCTAssertEqual(Tinkerble.shared.registeredTweaks.map(\.value), [.action])

        transport.receive(.trigger(id: "Fan Deck/Animation/Toggle Fan"))

        await waitUntil { owner.runCount == 1 }
        XCTAssertEqual(owner.runCount, 1)
    }

    func testDuplicateActionRegistrationsRemainVisibleAndAllRunUntilLastTokenUnregisters() async {
        let transport = LifetimeRecordingTransport()
        Tinkerble.shared.resetForTesting(transport: transport)
        addTeardownBlock { @MainActor in
            Tinkerble.shared.resetForTesting()
        }
        var firstRunCount = 0
        var secondRunCount = 0
        let firstToken = Tinkerble.shared.registerAction(
            id: "Fan Deck/Animation/Toggle Fan",
            screen: "Fan Deck",
            category: "Animation",
            name: "Toggle Fan",
            perform: { firstRunCount += 1 }
        )
        let secondToken = Tinkerble.shared.registerAction(
            id: "Fan Deck/Animation/Toggle Fan",
            screen: "Fan Deck",
            category: "Animation",
            name: "Toggle Fan",
            perform: { secondRunCount += 1 }
        )

        XCTAssertEqual(Tinkerble.shared.registeredTweaks.map(\.id), ["Fan Deck/Animation/Toggle Fan"])
        XCTAssertEqual(transport.sentMessages.compactMap(\.registeredTweak).map(\.id), ["Fan Deck/Animation/Toggle Fan"])

        transport.receive(.trigger(id: "Fan Deck/Animation/Toggle Fan"))

        await waitUntil { firstRunCount == 1 && secondRunCount == 1 }
        XCTAssertEqual(firstRunCount, 1)
        XCTAssertEqual(secondRunCount, 1)

        transport.sentMessages.removeAll()
        Tinkerble.shared.unregister(firstToken)

        XCTAssertEqual(Tinkerble.shared.registeredTweaks.map(\.id), ["Fan Deck/Animation/Toggle Fan"])
        XCTAssertTrue(transport.sentMessages.isEmpty)

        Tinkerble.shared.unregister(secondToken)

        XCTAssertTrue(Tinkerble.shared.registeredTweaks.isEmpty)
        XCTAssertEqual(transport.sentMessages, [.unregister(id: "Fan Deck/Animation/Toggle Fan")])
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

private final class ScreenRegistrationOwner {
    var value = ""
}

private final class ActionRegistrationOwner {
    var runCount = 0
}

private final class LifetimeRecordingTransport: TinkerbleClientTransport {
    var onMessage: ((TinkerbleWireMessage) -> Void)?
    var onStatusChange: ((TinkerbleConnectionStatus) -> Void)?
    var sentMessages: [TinkerbleWireMessage] = []

    func connect(host: String?, port: Int) {}

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

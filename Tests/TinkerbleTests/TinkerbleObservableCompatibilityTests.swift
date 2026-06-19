import XCTest
@testable import Tinkerble

#if canImport(Observation)
import Observation

@TinkerbleObservable
@Observable
@MainActor
private final class ObservableDemoModel {
    @TinkerbleObservableState("Badge Count", screen: "Basic", category: "Observable", control: TinkerbleControl<Int>.plain)
    var count = 1
}
#endif

@MainActor
final class TinkerbleObservableCompatibilityTests: XCTestCase {
    func testObservableCompatibilityFixtureCompilesWithoutObservationIgnored() {
        #if canImport(Observation)
        let model = ObservableDemoModel()
        let count = model.count
        XCTAssertEqual(count, 1)
        #else
        XCTAssertTrue(true)
        #endif
    }

    func testObservableModelRegistersOnInit() {
        #if canImport(Observation)
        let transport = ObservableRecordingTransport()
        Tinkerble.shared.resetForTesting(transport: transport)
        addTeardownBlock { @MainActor in
            Tinkerble.shared.resetForTesting()
        }

        let model = ObservableDemoModel()

        XCTAssertEqual(model.count, 1)
#if DEBUG
        XCTAssertEqual(Tinkerble.shared.registeredTweaks.map(\.id), [Self.observableTweakID])
        XCTAssertEqual(Tinkerble.shared.registeredTweaks.map(\.screen), ["Basic"])
        XCTAssertEqual(transport.sentMessages.compactMap(\.observableRegisteredTweak).map(\.id), [Self.observableTweakID])
#else
        XCTAssertTrue(Tinkerble.shared.registeredTweaks.isEmpty)
        XCTAssertTrue(transport.sentMessages.isEmpty)
#endif
        #else
        XCTAssertTrue(true)
        #endif
    }

    func testLocalObservableMutationSendsUpdate() async {
        #if canImport(Observation)
        let transport = ObservableRecordingTransport()
        Tinkerble.shared.resetForTesting(transport: transport)
        addTeardownBlock { @MainActor in
            Tinkerble.shared.resetForTesting()
        }
        let model = ObservableDemoModel()
        transport.sentMessages.removeAll()

        model.count = 4

#if DEBUG
        await waitUntil {
            transport.sentMessages.contains(.update(id: Self.observableTweakID, value: .number(4)))
        }
        XCTAssertEqual(transport.sentMessages, [.update(id: Self.observableTweakID, value: .number(4))])
#else
        try? await Task.sleep(for: .milliseconds(100))
        XCTAssertEqual(model.count, 4)
        XCTAssertTrue(transport.sentMessages.isEmpty)
#endif
        #else
        XCTAssertTrue(true)
        #endif
    }

    func testRemoteUpdateMutatesObservableModelWithoutEchoingLocalUpdate() async {
        #if canImport(Observation)
        let transport = ObservableRecordingTransport()
        Tinkerble.shared.resetForTesting(transport: transport)
        addTeardownBlock { @MainActor in
            Tinkerble.shared.resetForTesting()
        }
        let model = ObservableDemoModel()
        transport.sentMessages.removeAll()

        transport.receive(.update(id: Self.observableTweakID, value: .number(7)))

#if DEBUG
        await waitUntil { model.count == 7 }
        try? await Task.sleep(for: .milliseconds(100))
        XCTAssertEqual(model.count, 7)
        XCTAssertTrue(transport.sentMessages.isEmpty)
#else
        try? await Task.sleep(for: .milliseconds(100))
        XCTAssertEqual(model.count, 1)
        XCTAssertTrue(transport.sentMessages.isEmpty)
#endif
        #else
        XCTAssertTrue(true)
        #endif
    }

    func testObservableModelDeinitUnregisters() async {
        #if canImport(Observation)
        let transport = ObservableRecordingTransport()
        Tinkerble.shared.resetForTesting(transport: transport)
        addTeardownBlock { @MainActor in
            Tinkerble.shared.resetForTesting()
        }
        var model: ObservableDemoModel? = ObservableDemoModel()
        XCTAssertNotNil(model)
        transport.sentMessages.removeAll()

        model = nil

#if DEBUG
        await waitUntil {
            transport.sentMessages.contains(.unregister(id: Self.observableTweakID))
        }
        XCTAssertEqual(transport.sentMessages, [.unregister(id: Self.observableTweakID)])
#else
        try? await Task.sleep(for: .milliseconds(100))
        XCTAssertTrue(transport.sentMessages.isEmpty)
#endif
        #else
        XCTAssertTrue(true)
        #endif
    }

    private static let observableTweakID = "Basic/Observable/Badge Count"

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

private final class ObservableRecordingTransport: TinkerbleClientTransport {
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
    var observableRegisteredTweak: TinkerbleTweak? {
        guard case let .register(tweak) = self else { return nil }
        return tweak
    }
}

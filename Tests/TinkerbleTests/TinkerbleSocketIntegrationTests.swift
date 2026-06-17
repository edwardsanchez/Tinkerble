import XCTest
@testable import Tinkerble
@testable import TinkerbleCompanionCore

@MainActor
final class TinkerbleSocketIntegrationTests: XCTestCase {
    func testSocketLoopRegistersLogsAndAppliesRemoteUpdates() async throws {
        let port = 7877
        let companion = TinkerbleCompanionStore()
        companion.start(port: port)
        addTeardownBlock { @MainActor in
            companion.stop()
        }

        let companionStarted = await waitUntil { companion.connectionStatus.isConnected }
        XCTAssertTrue(companionStarted, "Companion did not start listening")

        let client = Tinkerble(transport: TinkerbleSocketClientTransport())
        var remoteTitle = "Original"

        client.register(
            id: "Title",
            category: nil,
            name: "Title",
            value: remoteTitle,
            control: .automatic,
            applyRemoteValue: { newValue in
                remoteTitle = newValue
            }
        )
        let opacityToken = client.register(
            id: "Layout/Opacity",
            category: "Layout",
            name: "Opacity",
            value: 0.5,
            control: .slider(0...1),
            applyRemoteValue: { _ in }
        )

        client.connect(host: "127.0.0.1", port: port)
        client.log("Integration log")
        addTeardownBlock { @MainActor in
            client.disconnect()
        }

        let receivedTweaks = await waitUntil { companion.tweaks.count == 2 }
        XCTAssertTrue(receivedTweaks, "Companion did not receive registered tweaks")
        XCTAssertEqual(companion.groupedTweaks.map(\.category), [nil, "Layout"])

        let receivedLog = await waitUntil { companion.logs.contains { $0.message == "Integration log" } }
        XCTAssertTrue(receivedLog, "Companion did not receive log")

        companion.updateTweak(id: "Title", value: .string("Updated from Mac"))

        let appliedRemoteUpdate = await waitUntil { remoteTitle == "Updated from Mac" }
        XCTAssertTrue(appliedRemoteUpdate, "iOS-side state did not receive remote update")

        client.unregister(opacityToken)

        let removedUnregisteredTweak = await waitUntil {
            companion.tweaks.map(\.id) == ["Title"]
        }
        XCTAssertTrue(removedUnregisteredTweak, "Companion did not remove unregistered tweak")
    }

    func testSocketLoopDiscoversCompanionWithBonjour() async throws {
        let serviceType = "_tbtest._tcp"
        let companion = TinkerbleCompanionStore()
        companion.start(port: 0, serviceType: serviceType)
        addTeardownBlock { @MainActor in
            companion.stop()
        }

        let companionStarted = await waitUntil { companion.connectionStatus.isConnected }
        XCTAssertTrue(companionStarted, "Companion did not start listening")

        let client = Tinkerble(
            transport: TinkerbleSocketClientTransport(serviceType: serviceType)
        )
        client.register(
            id: "Device/Title",
            category: "Device",
            name: "Title",
            value: "Bonjour",
            control: .automatic,
            applyRemoteValue: { _ in }
        )

        client.connect()
        addTeardownBlock { @MainActor in
            client.disconnect()
        }

        let discoveredTweaks = await waitUntil(timeout: 10) {
            companion.tweaks.map(\.id) == ["Device/Title"]
        }
        XCTAssertTrue(discoveredTweaks, "iOS transport did not discover the Bonjour companion")
    }

    private func waitUntil(
        timeout: TimeInterval = 5,
        condition: @escaping @MainActor () -> Bool
    ) async -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() {
                return true
            }
            try? await Task.sleep(for: .milliseconds(50))
        }
        return condition()
    }
}

private extension TinkerbleConnectionStatus {
    var isConnected: Bool {
        if case .connected = self {
            return true
        }
        return false
    }
}

import XCTest
@testable import Tinkerble
@testable import TinkerbleCompanionCore

@MainActor
final class TinkerbleRSocketIntegrationTests: XCTestCase {
    func testRSocketLoopRegistersLogsAndAppliesRemoteUpdates() async throws {
        let port = 7877
        let companion = TinkerbleCompanionStore()
        companion.start(port: port)
        addTeardownBlock { @MainActor in
            companion.stop()
        }

        let companionStarted = await waitUntil { companion.connectionStatus.isConnected }
        XCTAssertTrue(companionStarted, "Companion did not start listening")

        let client = Tinkerble(transport: TinkerbleRSocketClientTransport())
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

        client.connect(port: port)
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

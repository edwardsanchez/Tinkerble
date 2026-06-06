import XCTest
@testable import Tinkerble

#if canImport(Observation)
import Observation
import SwiftUI

private enum ObservableMacroMood: String, CaseIterable, TinkerbleEnum {
    case calm
    case focused
}

@TinkerbleObservable
@MainActor
private final class ObservableMacroDemoModel {
    @TinkerbleObservableState(name: "Title")
    var title = "Demo"

    @TinkerbleObservableState(category: "Flags", name: "Enabled")
    var isEnabled = true

    @TinkerbleObservableState(category: "Palette", name: "Accent Color")
    var accentColor = Color.blue

    @TinkerbleObservableState(category: "Layout", name: "Card Count", control: TinkerbleControl<Int>.plain)
    var cardCount = 3

    @TinkerbleObservableState("Layout", name: "Opacity", control: .slider(0.0...1.0))
    var opacity = 0.82

    @TinkerbleObservableState(category: "Layout", name: "Scale", control: .slider(Float(0.0)...Float(1.0)))
    var scale: Float = 0.5

    @TinkerbleObservableState(category: "Layout", name: "Corner Radius", control: .slider(CGFloat(0)...CGFloat(24)))
    var cornerRadius: CGFloat = 8

    @TinkerbleObservableState(category: "Modes", name: "Mood")
    var mood = ObservableMacroMood.focused
}
#endif

@MainActor
final class TinkerbleObservableStateMacroUsageTests: XCTestCase {
    #if canImport(Observation)
    func testMacroRegistersAllSupportedObservableValuesWithParityControls() {
        let transport = RecordingTransport()
        Tinkerble.shared.resetForTesting(transport: transport)

        let model = ObservableMacroDemoModel()
        _ = model.title
        _ = model.isEnabled
        _ = model.accentColor
        _ = model.cardCount
        _ = model.opacity
        _ = model.scale
        _ = model.cornerRadius
        _ = model.mood

        let registeredTweaks = transport.sentMessages.compactMap(\.registeredTweak)
        XCTAssertEqual(
            registeredTweaks.map(\.id),
            [
                "Title",
                "Flags/Enabled",
                "Palette/Accent Color",
                "Layout/Card Count",
                "Layout/Opacity",
                "Layout/Scale",
                "Layout/Corner Radius",
                "Modes/Mood",
            ]
        )
        XCTAssertEqual(registeredTweaks[0].value, .string("Demo"))
        XCTAssertEqual(registeredTweaks[1].value, .bool(true))
        XCTAssertEqual(registeredTweaks[2].valueKind, .color)
        XCTAssertEqual(registeredTweaks[3].control, TinkerbleControl<Int>.plain.descriptor)
        XCTAssertEqual(registeredTweaks[4].control, TinkerbleControl<Double>.slider(0.0...1.0).descriptor)
        XCTAssertEqual(registeredTweaks[5].control, TinkerbleControl<Float>.slider(Float(0.0)...Float(1.0)).descriptor)
        XCTAssertEqual(registeredTweaks[6].control, TinkerbleControl<CGFloat>.slider(CGFloat(0)...CGFloat(24)).descriptor)
        XCTAssertEqual(registeredTweaks[7].enumOptions.map(\.id), ["calm", "focused"])
    }

    func testMacroSendsLocalUpdatesAndAppliesRemoteUpdatesWithoutEchoing() async {
        let transport = RecordingTransport()
        Tinkerble.shared.resetForTesting(transport: transport)

        let model = ObservableMacroDemoModel()
        _ = model.cardCount
        transport.sentMessages.removeAll()

        model.cardCount = 4
        XCTAssertEqual(transport.sentMessages, [.update(id: "Layout/Card Count", value: .number(4))])

        transport.sentMessages.removeAll()
        transport.receive(.update(id: "Layout/Card Count", value: .number(7)))
        await waitUntil { model.cardCount == 7 }

        XCTAssertEqual(model.cardCount, 7)
        XCTAssertTrue(transport.sentMessages.isEmpty)
    }

    func testMacroPropertyParticipatesInSwiftObservation() {
        let transport = RecordingTransport()
        Tinkerble.shared.resetForTesting(transport: transport)

        let model = ObservableMacroDemoModel()
        _ = model.cardCount

        let observedChange = ObservationFlag()
        withObservationTracking {
            _ = model.cardCount
        } onChange: {
            observedChange.set()
        }

        model.cardCount = 4

        XCTAssertTrue(observedChange.value)
    }

    func testMacroUnregistersObservableStateWhenOwnerDeallocates() async {
        let transport = RecordingTransport()
        Tinkerble.shared.resetForTesting(transport: transport)
        addTeardownBlock { @MainActor in
            Tinkerble.shared.resetForTesting()
        }

        var model: ObservableMacroDemoModel? = ObservableMacroDemoModel()
        _ = model?.title

        XCTAssertEqual(Tinkerble.shared.registeredTweaks.map(\.id), ["Title"])
        transport.sentMessages.removeAll()

        model = nil

        await waitUntil { Tinkerble.shared.registeredTweaks.isEmpty }
        XCTAssertTrue(Tinkerble.shared.registeredTweaks.isEmpty)
        XCTAssertEqual(transport.sentMessages, [.unregister(id: "Title")])
    }
    #endif

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

private final class RecordingTransport: TinkerbleClientTransport {
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

private final class ObservationFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var didChange = false

    var value: Bool {
        lock.withLock { didChange }
    }

    func set() {
        lock.withLock {
            didChange = true
        }
    }
}

private extension TinkerbleWireMessage {
    var registeredTweak: TinkerbleTweak? {
        guard case let .register(tweak) = self else { return nil }
        return tweak
    }
}

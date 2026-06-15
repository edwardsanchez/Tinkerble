import XCTest
import RSocketCore
@testable import Tinkerble
@testable import TinkerbleCompanionCore

@MainActor
final class TinkerbleCompanionStoreTests: XCTestCase {
    func testCompanionGroupsUncategorizedTweaksBeforeCategorizedTweaks() {
        let store = TinkerbleCompanionStore()

        store.handle(
            .register(
                TinkerbleTweak(
                    id: "Title",
                    category: nil,
                    name: "Title",
                    value: .string("Demo"),
                    valueKind: .string,
                    control: .automatic
                )
            ),
            outbound: nil
        )
        store.handle(
            .register(
                TinkerbleTweak(
                    id: "Layout/Width",
                    category: "Layout",
                    name: "Width",
                    value: .number(120),
                    valueKind: .number,
                    control: TinkerbleControl<Int>.plain.descriptor
                )
            ),
            outbound: nil
        )

        XCTAssertEqual(store.groupedTweaks.map(\.category), [nil, "Layout"])
        XCTAssertEqual(store.groupedTweaks[0].tweaks.map(\.name), ["Title"])
    }

    func testCompanionFiltersGroupsBySelectedScreenWhenMultipleScreensAreRegistered() {
        let store = TinkerbleCompanionStore()

        store.handle(
            .snapshot(
                [
                    TinkerbleTweak(
                        id: "Basic/Layout/Opacity",
                        screen: "Basic",
                        category: "Layout",
                        name: "Opacity",
                        value: .number(0.8),
                        valueKind: .number,
                        control: .automatic
                    ),
                    TinkerbleTweak(
                        id: "Fan Deck/Deck/Card Count",
                        screen: "Fan Deck",
                        category: "Deck",
                        name: "Card Count",
                        value: .number(5),
                        valueKind: .number,
                        control: .automatic
                    ),
                ]
            ),
            outbound: nil
        )

        XCTAssertEqual(store.screens, ["Basic", "Fan Deck"])
        XCTAssertTrue(store.showsScreenSelector)
        XCTAssertEqual(store.selectedScreen, "Basic")
        XCTAssertEqual(store.groupedTweaks.map(\.category), ["Layout"])

        store.selectScreen("Fan Deck")

        XCTAssertEqual(store.groupedTweaks.map(\.category), ["Deck"])
        XCTAssertEqual(store.groupedTweaks.flatMap(\.tweaks).map(\.name), ["Card Count"])
    }

    func testCompanionUsesDefaultScreenAndHidesSelectorForSingleScreenTweaks() {
        let store = TinkerbleCompanionStore()

        store.handle(
            .register(
                TinkerbleTweak(
                    id: "Title",
                    category: nil,
                    name: "Title",
                    value: .string("Demo"),
                    valueKind: .string,
                    control: .automatic
                )
            ),
            outbound: nil
        )

        XCTAssertEqual(store.screens, [TinkerbleTweak.defaultScreenName])
        XCTAssertEqual(store.selectedScreen, TinkerbleTweak.defaultScreenName)
        XCTAssertFalse(store.showsScreenSelector)
        XCTAssertEqual(store.groupedTweaks.flatMap(\.tweaks).map(\.name), ["Title"])
    }

    func testCompanionStoresIncomingLogs() {
        let store = TinkerbleCompanionStore()
        let entry = TinkerbleLogEntry(message: "User tapped Save")

        store.handle(.log(entry), outbound: nil)

        XCTAssertEqual(store.logs, [entry])
    }

    func testCompanionTriggerTweakSendsTriggerMessage() throws {
        let store = TinkerbleCompanionStore()
        let outbound = RecordingOutboundStream()
        let codec = TinkerbleRSocketPayloadCodec()
        store.handle(.hello(role: .iOSApp, version: "test"), outbound: outbound)

        store.triggerTweak(id: "Fan Deck/Animation/Toggle Fan")

        let payload = try XCTUnwrap(outbound.payloads.last)
        XCTAssertEqual(try codec.message(from: payload), .trigger(id: "Fan Deck/Animation/Toggle Fan"))
    }

    func testCompanionIgnoresInboundTriggerMessages() {
        let store = TinkerbleCompanionStore()

        store.handle(.trigger(id: "Fan Deck/Animation/Toggle Fan"), outbound: nil)

        XCTAssertTrue(store.tweaks.isEmpty)
        XCTAssertTrue(store.logs.isEmpty)
    }

    func testCompanionRemovesTweaksWhenTheyUnregister() {
        let store = TinkerbleCompanionStore()

        store.handle(
            .register(
                TinkerbleTweak(
                    id: "Lifetime State/Message",
                    category: "Lifetime State",
                    name: "Message",
                    value: .string("Loaded"),
                    valueKind: .string,
                    control: .automatic
                )
            ),
            outbound: nil
        )

        XCTAssertEqual(store.tweaks.map(\.id), ["Lifetime State/Message"])

        store.handle(.unregister(id: "Lifetime State/Message"), outbound: nil)

        XCTAssertTrue(store.tweaks.isEmpty)
        XCTAssertTrue(store.groupedTweaks.isEmpty)
    }
}

private final class RecordingOutboundStream: UnidirectionalStream {
    var payloads: [Payload] = []

    func onNext(_ payload: Payload, isCompletion: Bool) {
        payloads.append(payload)
    }

    func onComplete() {}

    func onRequestN(_ requestN: Int32) {}

    func onCancel() {}

    func onError(_ error: RSocketCore.Error) {}

    func onExtension(extendedType: Int32, payload: Payload, canBeIgnored: Bool) {}
}

import XCTest
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
            outboundChannel: nil
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
            outboundChannel: nil
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
                    )
                ]
            ),
            outboundChannel: nil
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
            outboundChannel: nil
        )

        XCTAssertEqual(store.screens, [TinkerbleTweak.defaultScreenName])
        XCTAssertEqual(store.selectedScreen, TinkerbleTweak.defaultScreenName)
        XCTAssertFalse(store.showsScreenSelector)
        XCTAssertEqual(store.groupedTweaks.flatMap(\.tweaks).map(\.name), ["Title"])
    }

    func testCompanionStoresIncomingLogValues() {
        let store = TinkerbleCompanionStore()
        let entry = TinkerbleLogEntry(screen: "Cards", category: "Deck", name: "Visible Cards", value: 7)

        store.handle(.log(entry), outboundChannel: nil)

        XCTAssertEqual(store.logs, [entry])
    }

    func testCompanionTriggerTweakSendsTriggerMessage() throws {
        let store = TinkerbleCompanionStore()
        let outbound = RecordingOutboundChannel()
        store.handle(.hello(role: .iOSApp, version: "test"), outboundChannel: outbound)

        store.triggerTweak(id: "Fan Deck/Animation/Toggle Fan")

        XCTAssertEqual(outbound.messages.last, .trigger(id: "Fan Deck/Animation/Toggle Fan"))
    }

    func testCompanionIgnoresInboundTriggerMessages() {
        let store = TinkerbleCompanionStore()

        store.handle(.trigger(id: "Fan Deck/Animation/Toggle Fan"), outboundChannel: nil)

        XCTAssertTrue(store.tweaks.isEmpty)
        XCTAssertTrue(store.logs.isEmpty)
    }

    func testCompanionUpdateRegistersUndoAndRedoSendsUpdateMessages() throws {
        let store = TinkerbleCompanionStore()
        let outbound = RecordingOutboundChannel()
        store.handle(.hello(role: .iOSApp, version: "test"), outboundChannel: outbound)
        store.handle(.register(titleTweak(value: .string("Initial"))), outboundChannel: nil)

        store.updateTweak(id: "Title", value: .string("Edited"))

        XCTAssertEqual(store.tweaks.first?.value, .string("Edited"))
        XCTAssertTrue(store.canUndo)
        XCTAssertFalse(store.canRedo)
        XCTAssertEqual(
            try XCTUnwrap(outbound.messages.last),
            .update(id: "Title", value: .string("Edited"))
        )

        store.undo()

        XCTAssertEqual(store.tweaks.first?.value, .string("Initial"))
        XCTAssertFalse(store.canUndo)
        XCTAssertTrue(store.canRedo)
        XCTAssertEqual(
            try XCTUnwrap(outbound.messages.last),
            .update(id: "Title", value: .string("Initial"))
        )

        store.redo()

        XCTAssertEqual(store.tweaks.first?.value, .string("Edited"))
        XCTAssertTrue(store.canUndo)
        XCTAssertFalse(store.canRedo)
        XCTAssertEqual(
            try XCTUnwrap(outbound.messages.last),
            .update(id: "Title", value: .string("Edited"))
        )
    }

    func testCompanionDoesNotRegisterUndoForInboundUpdates() {
        let store = TinkerbleCompanionStore()
        store.handle(.register(titleTweak(value: .string("Initial"))), outboundChannel: nil)

        store.handle(.update(id: "Title", value: .string("From App")), outboundChannel: nil)

        XCTAssertEqual(store.tweaks.first?.value, .string("From App"))
        XCTAssertFalse(store.canUndo)
        XCTAssertFalse(store.canRedo)
    }

    func testCompanionDoesNotRegisterUndoForRepeatedValues() {
        let store = TinkerbleCompanionStore()
        let outbound = RecordingOutboundChannel()
        store.handle(.hello(role: .iOSApp, version: "test"), outboundChannel: outbound)
        store.handle(.register(titleTweak(value: .string("Initial"))), outboundChannel: nil)

        store.updateTweak(id: "Title", value: .string("Initial"))

        XCTAssertTrue(outbound.messages.isEmpty)
        XCTAssertFalse(store.canUndo)
        XCTAssertFalse(store.canRedo)
    }

    func testCompanionCoalescesContinuousUpdatesIntoSingleUndoEntry() throws {
        let store = TinkerbleCompanionStore()
        let outbound = RecordingOutboundChannel()
        store.handle(.hello(role: .iOSApp, version: "test"), outboundChannel: outbound)
        store.handle(.register(titleTweak(value: .number(0))), outboundChannel: nil)

        store.beginCoalescedTweakUpdate(id: "Title")
        store.updateCoalescedTweak(id: "Title", value: .number(1))
        store.updateCoalescedTweak(id: "Title", value: .number(2))
        store.updateCoalescedTweak(id: "Title", value: .number(3))
        store.endCoalescedTweakUpdate(id: "Title")

        XCTAssertEqual(store.tweaks.first?.value, .number(3))
        XCTAssertTrue(store.canUndo)
        XCTAssertFalse(store.canRedo)
        XCTAssertEqual(
            outbound.messages,
            [
                .update(id: "Title", value: .number(1)),
                .update(id: "Title", value: .number(2)),
                .update(id: "Title", value: .number(3))
            ]
        )

        store.undo()

        XCTAssertEqual(store.tweaks.first?.value, .number(0))
        XCTAssertFalse(store.canUndo)
        XCTAssertTrue(store.canRedo)
        XCTAssertEqual(
            try XCTUnwrap(outbound.messages.last),
            .update(id: "Title", value: .number(0))
        )

        store.redo()

        XCTAssertEqual(store.tweaks.first?.value, .number(3))
        XCTAssertTrue(store.canUndo)
        XCTAssertFalse(store.canRedo)
        XCTAssertEqual(
            try XCTUnwrap(outbound.messages.last),
            .update(id: "Title", value: .number(3))
        )
    }

    func testCompanionDoesNotRegisterCoalescedUndoWhenValueReturnsToStart() {
        let store = TinkerbleCompanionStore()
        let outbound = RecordingOutboundChannel()
        store.handle(.hello(role: .iOSApp, version: "test"), outboundChannel: outbound)
        store.handle(.register(titleTweak(value: .number(0))), outboundChannel: nil)

        store.beginCoalescedTweakUpdate(id: "Title")
        store.updateCoalescedTweak(id: "Title", value: .number(1))
        store.updateCoalescedTweak(id: "Title", value: .number(0))
        store.endCoalescedTweakUpdate(id: "Title")

        XCTAssertEqual(store.tweaks.first?.value, .number(0))
        XCTAssertFalse(store.canUndo)
        XCTAssertFalse(store.canRedo)
    }

    func testCompanionCoalescesStringUpdatesIntoSingleUndoEntry() throws {
        let store = TinkerbleCompanionStore()
        let outbound = RecordingOutboundChannel()
        store.handle(.hello(role: .iOSApp, version: "test"), outboundChannel: outbound)
        store.handle(.register(titleTweak(value: .string("Initial"))), outboundChannel: nil)

        store.beginCoalescedTweakUpdate(id: "Title")
        store.updateCoalescedTweak(id: "Title", value: .string("E"))
        store.updateCoalescedTweak(id: "Title", value: .string("Ed"))
        store.updateCoalescedTweak(id: "Title", value: .string("Edited"))
        store.endCoalescedTweakUpdate(id: "Title")

        XCTAssertEqual(store.tweaks.first?.value, .string("Edited"))
        XCTAssertTrue(store.canUndo)
        XCTAssertFalse(store.canRedo)
        XCTAssertEqual(
            outbound.messages,
            [
                .update(id: "Title", value: .string("E")),
                .update(id: "Title", value: .string("Ed")),
                .update(id: "Title", value: .string("Edited"))
            ]
        )

        store.undo()

        XCTAssertEqual(store.tweaks.first?.value, .string("Initial"))
        XCTAssertFalse(store.canUndo)
        XCTAssertTrue(store.canRedo)
        XCTAssertEqual(
            try XCTUnwrap(outbound.messages.last),
            .update(id: "Title", value: .string("Initial"))
        )

        store.redo()

        XCTAssertEqual(store.tweaks.first?.value, .string("Edited"))
        XCTAssertTrue(store.canUndo)
        XCTAssertFalse(store.canRedo)
        XCTAssertEqual(
            try XCTUnwrap(outbound.messages.last),
            .update(id: "Title", value: .string("Edited"))
        )
    }

    func testCompanionDoesNotRegisterStringUndoWhenValueReturnsToStart() {
        let store = TinkerbleCompanionStore()
        let outbound = RecordingOutboundChannel()
        store.handle(.hello(role: .iOSApp, version: "test"), outboundChannel: outbound)
        store.handle(.register(titleTweak(value: .string("Initial"))), outboundChannel: nil)

        store.beginCoalescedTweakUpdate(id: "Title")
        store.updateCoalescedTweak(id: "Title", value: .string("Edited"))
        store.updateCoalescedTweak(id: "Title", value: .string("Initial"))
        store.endCoalescedTweakUpdate(id: "Title")

        XCTAssertEqual(store.tweaks.first?.value, .string("Initial"))
        XCTAssertFalse(store.canUndo)
        XCTAssertFalse(store.canRedo)
    }

    func testCompanionCreatesVersionOnePerScreen() throws {
        let store = TinkerbleCompanionStore()

        store.handle(
            .hello(role: .iOSApp, version: "test", project: .init(id: "app.test", displayName: "Test App")),
            outboundChannel: nil
        )
        store.handle(
            .snapshot(
                [
                    screenTweak(screen: "Basic", category: "Layout", name: "Opacity", value: .number(0.8)),
                    screenTweak(screen: "Fan Deck", category: "Deck", name: "Card Count", value: .number(5))
                ]
            ),
            outboundChannel: nil
        )

        let basicVersionID = try XCTUnwrap(store.selectedVersionID)
        XCTAssertEqual(store.selectedScreen, "Basic")
        XCTAssertEqual(store.versions.map(\.name), ["Version 1"])
        XCTAssertFalse(store.canDeleteSelectedVersion)

        store.selectScreen("Fan Deck")

        XCTAssertEqual(store.selectedScreen, "Fan Deck")
        XCTAssertEqual(store.versions.map(\.name), ["Version 1"])
        XCTAssertFalse(store.canDeleteSelectedVersion)
        XCTAssertNotEqual(store.selectedVersionID, basicVersionID)
    }

    func testCompanionSavesEditedValueAndReappliesWhenTweakRegistersAgain() throws {
        let store = TinkerbleCompanionStore()
        let outbound = RecordingOutboundChannel()
        store.handle(.hello(role: .iOSApp, version: "test"), outboundChannel: outbound)
        store.handle(.register(titleTweak(value: .string("Initial"))), outboundChannel: nil)

        store.updateTweak(id: "Title", value: .string("Edited"))
        store.handle(.unregister(id: "Title"), outboundChannel: nil)
        store.handle(.register(titleTweak(value: .string("Initial"))), outboundChannel: nil)

        XCTAssertEqual(store.tweaks.first?.value, .string("Edited"))
        XCTAssertEqual(outbound.messages.count, 2)
        XCTAssertEqual(
            try XCTUnwrap(outbound.messages.last),
            .update(id: "Title", value: .string("Edited"))
        )
    }

    func testCompanionCreatesNewVersionFromCurrentScreenValuesAndSwitchesBetweenVersions() {
        let store = TinkerbleCompanionStore()
        store.handle(.hello(role: .iOSApp, version: "test"), outboundChannel: nil)
        store.handle(.register(titleTweak(value: .string("Initial"))), outboundChannel: nil)
        let versionOneID = store.selectedVersionID

        store.createVersion()
        let versionTwoID = store.selectedVersionID
        store.updateTweak(id: "Title", value: .string("Version Two"))

        XCTAssertEqual(store.versions.map(\.name), ["Version 1", "Version 2"])
        XCTAssertNotEqual(versionOneID, versionTwoID)

        if let versionOneID {
            store.selectVersion(versionOneID)
        }

        XCTAssertEqual(store.tweaks.first?.value, .string("Initial"))

        if let versionTwoID {
            store.selectVersion(versionTwoID)
        }

        XCTAssertEqual(store.tweaks.first?.value, .string("Version Two"))
    }

    func testCompanionAddedTweaksUseDefaultUntilChangedThenRestoreSavedValue() {
        let store = TinkerbleCompanionStore()
        store.handle(.hello(role: .iOSApp, version: "test"), outboundChannel: nil)
        store.handle(.register(titleTweak(value: .string("Initial"))), outboundChannel: nil)

        store.updateTweak(id: "Title", value: .string("Edited"))
        store.handle(.register(subtitleTweak(value: .string("Default Subtitle"))), outboundChannel: nil)

        XCTAssertEqual(store.tweaks.first { $0.id == "Subtitle" }?.value, .string("Default Subtitle"))

        store.updateTweak(id: "Subtitle", value: .string("Saved Subtitle"))
        store.handle(.unregister(id: "Subtitle"), outboundChannel: nil)
        store.handle(.register(subtitleTweak(value: .string("Default Subtitle"))), outboundChannel: nil)

        XCTAssertEqual(store.tweaks.first { $0.id == "Subtitle" }?.value, .string("Saved Subtitle"))
    }

    func testCompanionDeletesSelectedNonProtectedVersionAndKeepsVersionOne() {
        let store = TinkerbleCompanionStore()
        store.handle(.hello(role: .iOSApp, version: "test"), outboundChannel: nil)
        store.handle(.register(titleTweak(value: .string("Initial"))), outboundChannel: nil)

        store.updateTweak(id: "Title", value: .string("Version One"))
        store.createVersion()
        store.updateTweak(id: "Title", value: .string("Version Two"))

        XCTAssertTrue(store.canDeleteSelectedVersion)

        store.deleteSelectedVersion()

        XCTAssertEqual(store.versions.map(\.name), ["Version 1"])
        XCTAssertFalse(store.canDeleteSelectedVersion)
        XCTAssertEqual(store.tweaks.first?.value, .string("Version One"))
    }

    func testCompanionResetsVersionOneToOriginalValues() throws {
        let store = TinkerbleCompanionStore()
        let outbound = RecordingOutboundChannel()
        store.handle(.hello(role: .iOSApp, version: "test"), outboundChannel: outbound)
        store.handle(.register(titleTweak(value: .string("Initial"))), outboundChannel: nil)

        store.updateTweak(id: "Title", value: .string("Edited"))

        XCTAssertEqual(store.tweaks.first?.value, .string("Edited"))
        XCTAssertTrue(store.canResetSelectedVersion)
        XCTAssertFalse(store.canDeleteSelectedVersion)
        XCTAssertTrue(store.canUndo)

        store.resetSelectedVersion()

        XCTAssertEqual(store.tweaks.first?.value, .string("Initial"))
        XCTAssertFalse(store.canUndo)
        XCTAssertFalse(store.canRedo)
        XCTAssertEqual(
            try XCTUnwrap(outbound.messages.last),
            .update(id: "Title", value: .string("Initial"))
        )

        store.handle(.unregister(id: "Title"), outboundChannel: nil)
        store.handle(.register(titleTweak(value: .string("Initial"))), outboundChannel: nil)

        XCTAssertEqual(store.tweaks.first?.value, .string("Initial"))
    }

    func testCompanionDoesNotResetNonProtectedVersion() {
        let store = TinkerbleCompanionStore()
        store.handle(.hello(role: .iOSApp, version: "test"), outboundChannel: nil)
        store.handle(.register(titleTweak(value: .string("Initial"))), outboundChannel: nil)

        store.createVersion()
        store.updateTweak(id: "Title", value: .string("Version Two"))

        XCTAssertFalse(store.canResetSelectedVersion)
        XCTAssertTrue(store.canDeleteSelectedVersion)

        store.resetSelectedVersion()

        XCTAssertEqual(store.tweaks.first?.value, .string("Version Two"))
    }

    func testCompanionIgnoresSavedValueWhenTweakKindChanges() {
        let store = TinkerbleCompanionStore()
        store.handle(.hello(role: .iOSApp, version: "test"), outboundChannel: nil)
        store.handle(.register(titleTweak(value: .string("Initial"))), outboundChannel: nil)

        store.updateTweak(id: "Title", value: .string("Edited"))
        store.handle(.unregister(id: "Title"), outboundChannel: nil)
        store.handle(.register(titleTweak(value: .number(12))), outboundChannel: nil)

        XCTAssertEqual(store.tweaks.first?.value, .number(12))
    }

    func testCompanionKeepsSavedVersionsSeparateByProjectIdentity() {
        let repository = TinkerbleInMemoryVersionRepository()
        let firstStore = TinkerbleCompanionStore(versionRepository: repository)
        firstStore.handle(
            .hello(role: .iOSApp, version: "test", project: .init(id: "app.one", displayName: "One")),
            outboundChannel: nil
        )
        firstStore.handle(.register(titleTweak(value: .string("Initial"))), outboundChannel: nil)
        firstStore.updateTweak(id: "Title", value: .string("Saved For One"))

        let secondStore = TinkerbleCompanionStore(versionRepository: repository)
        secondStore.handle(
            .hello(role: .iOSApp, version: "test", project: .init(id: "app.two", displayName: "Two")),
            outboundChannel: nil
        )
        secondStore.handle(.register(titleTweak(value: .string("Initial"))), outboundChannel: nil)

        XCTAssertEqual(secondStore.tweaks.first?.value, .string("Initial"))

        let reloadedFirstStore = TinkerbleCompanionStore(versionRepository: repository)
        reloadedFirstStore.handle(
            .hello(role: .iOSApp, version: "test", project: .init(id: "app.one", displayName: "One")),
            outboundChannel: nil
        )
        reloadedFirstStore.handle(.register(titleTweak(value: .string("Initial"))), outboundChannel: nil)

        XCTAssertEqual(reloadedFirstStore.tweaks.first?.value, .string("Saved For One"))
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
            outboundChannel: nil
        )

        XCTAssertEqual(store.tweaks.map(\.id), ["Lifetime State/Message"])

        store.handle(.unregister(id: "Lifetime State/Message"), outboundChannel: nil)

        XCTAssertTrue(store.tweaks.isEmpty)
        XCTAssertTrue(store.groupedTweaks.isEmpty)
    }

    private func titleTweak(value: TinkerbleValue) -> TinkerbleTweak {
        TinkerbleTweak(
            id: "Title",
            category: nil,
            name: "Title",
            value: value,
            valueKind: value.kind,
            control: .automatic
        )
    }

    private func subtitleTweak(value: TinkerbleValue) -> TinkerbleTweak {
        TinkerbleTweak(
            id: "Subtitle",
            category: nil,
            name: "Subtitle",
            value: value,
            valueKind: value.kind,
            control: .automatic
        )
    }

    private func screenTweak(screen: String, category: String, name: String, value: TinkerbleValue) -> TinkerbleTweak {
        TinkerbleTweak(
            id: TinkerbleTweak.makeID(screen: screen, category: category, name: name),
            screen: screen,
            category: category,
            name: name,
            value: value,
            valueKind: value.kind,
            control: .automatic
        )
    }
}

private final class RecordingOutboundChannel: TinkerbleCompanionOutboundChannel {
    var messages: [TinkerbleWireMessage] = []

    func send(_ message: TinkerbleWireMessage) {
        messages.append(message)
    }

    func close() {}
}

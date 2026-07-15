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

    func testInboundUpdateDoesNotReplaceCompiledDefaultForCategoryReset() {
        let store = TinkerbleCompanionStore()
        let tweak = screenTweak(screen: "Basic", category: "Layout", name: "Title", value: .string("Initial"))
        store.handle(.register(tweak), outboundChannel: nil)

        store.handle(.update(id: tweak.id, value: .string("From App")), outboundChannel: nil)
        store.resetCategoryToDefaults("Layout")

        XCTAssertEqual(store.tweaks.first?.value, .string("Initial"))
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

    func testCategoryResetIsScopedAndCreatesOneCompositeUndoEntry() {
        let store = TinkerbleCompanionStore()
        let outbound = RecordingOutboundChannel()
        store.handle(.hello(role: .iOSApp, version: "test"), outboundChannel: outbound)
        let title = screenTweak(screen: "Basic", category: "Layout", name: "Title", value: .string("Initial"))
        let count = screenTweak(screen: "Basic", category: "Layout", name: "Count", value: .number(1))
        let otherScreen = screenTweak(screen: "Other", category: "Layout", name: "Title", value: .string("Other Initial"))
        let action = TinkerbleTweak(
            id: TinkerbleTweak.makeID(screen: "Basic", category: "Layout", name: "Action"),
            screen: "Basic",
            category: "Layout",
            name: "Action",
            value: .action,
            valueKind: .action,
            control: .automatic
        )
        store.handle(.snapshot([title, count, otherScreen, action]), outboundChannel: nil)

        store.updateTweak(id: title.id, value: .string("Edited"))
        store.updateTweak(id: count.id, value: .number(7))
        store.updateTweak(id: otherScreen.id, value: .string("Other Edited"))
        store.selectScreen("Basic")
        store.resetCategoryToDefaults("Layout")

        XCTAssertEqual(store.tweaks.first { $0.id == title.id }?.value, .string("Initial"))
        XCTAssertEqual(store.tweaks.first { $0.id == count.id }?.value, .number(1))
        XCTAssertEqual(store.tweaks.first { $0.id == otherScreen.id }?.value, .string("Other Edited"))
        XCTAssertEqual(store.tweaks.first { $0.id == action.id }?.value, .action)

        store.undo()

        XCTAssertEqual(store.tweaks.first { $0.id == title.id }?.value, .string("Edited"))
        XCTAssertEqual(store.tweaks.first { $0.id == count.id }?.value, .number(7))
        XCTAssertEqual(store.tweaks.first { $0.id == otherScreen.id }?.value, .string("Other Edited"))

        store.redo()

        XCTAssertEqual(store.tweaks.first { $0.id == title.id }?.value, .string("Initial"))
        XCTAssertEqual(store.tweaks.first { $0.id == count.id }?.value, .number(1))
        XCTAssertEqual(store.tweaks.first { $0.id == otherScreen.id }?.value, .string("Other Edited"))
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

    func testApplyingSourceUpdatesEffectiveDefaultAndPersistsItForTheRunningBuild() async throws {
        let root = URL(fileURLWithPath: "/tmp/TinkerbleProject")
        let anchor = sourceAnchor(initializer: "\"Initial\"")
        let edit = TinkerbleAppliedSourceEdit(
            tweakID: "Basic/Layout/Title",
            anchor: anchor,
            previousExpression: "\"Initial\"",
            writtenExpression: "\"Applied\"",
            originalFileHash: "before",
            writtenFileHash: "after"
        )
        let sourceEditor = StubSourceEditor(outcome: .success(.init(edits: [edit])))
        let appliedDefaults = TinkerbleInMemoryAppliedDefaultRepository()
        let store = TinkerbleCompanionStore(
            versionRepository: TinkerbleInMemoryVersionRepository(),
            sourceEditor: sourceEditor,
            appliedDefaultRepository: appliedDefaults,
            sourceProjectRoot: root,
            sourceProjectID: "app.test"
        )
        store.handle(
            .hello(role: .iOSApp, version: "test", project: .init(id: "app.test", displayName: "Test")),
            outboundChannel: nil
        )
        let tweak = sourceTweak(anchor: anchor, value: .string("Initial"))
        store.handle(.register(tweak), outboundChannel: nil)
        store.updateTweak(id: tweak.id, value: .string("Applied"))
        await waitUntil { !store.isReconcilingAppliedDefaults }

        store.applyTweakToSource(id: tweak.id)
        await waitUntil { store.sourceEditingTweakIDs.isEmpty }

        let key = TinkerbleAppliedDefaultKey(projectID: "app.test", projectRoot: root, anchor: anchor)
        let persisted = await appliedDefaults.record(for: key)
        XCTAssertEqual(persisted?.value, .string("Applied"))
        XCTAssertFalse(store.canResetCategoryToDefaults("Layout"))

        store.updateTweak(id: tweak.id, value: .string("Changed Again"))
        store.resetCategoryToDefaults("Layout")

        XCTAssertEqual(store.tweaks.first?.value, .string("Applied"))
    }

    func testReconnectReappliesCachedDefaultToTheRunningApp() async throws {
        let root = FileManager.default.temporaryDirectory.appending(
            path: "TinkerbleReconnect-\(UUID().uuidString)",
            directoryHint: .isDirectory
        )
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        let fileURL = root.appending(path: "View.swift")
        let writtenSource = Data(
            "struct View { @TinkerbleState(\"Title\") var title = \"Applied\" }".utf8
        )
        try writtenSource.write(to: fileURL)
        let anchor = sourceAnchor(initializer: "\"Initial\"", fileURL: fileURL)
        let edit = TinkerbleAppliedSourceEdit(
            tweakID: "Basic/Layout/Title",
            anchor: anchor,
            previousExpression: "\"Initial\"",
            writtenExpression: "\"Applied\"",
            originalFileHash: "before",
            writtenFileHash: TinkerbleSourceHash.sha256(writtenSource)
        )
        let appliedDefaults = TinkerbleInMemoryAppliedDefaultRepository()
        try await appliedDefaults.update(
            [
                TinkerbleAppliedDefaultRecord(
                    projectID: "app.test",
                    projectRoot: root,
                    edit: edit,
                    value: .string("Applied"),
                    sourceValueType: .string
                )
            ]
        )
        let store = TinkerbleCompanionStore(
            versionRepository: TinkerbleInMemoryVersionRepository(),
            appliedDefaultRepository: appliedDefaults,
            sourceProjectRoot: root,
            sourceProjectID: "app.test"
        )
        let outbound = RecordingOutboundChannel()
        store.handle(
            .hello(role: .iOSApp, version: "test", project: .init(id: "app.test", displayName: "Test")),
            outboundChannel: outbound
        )
        store.handle(
            .snapshot([sourceTweak(anchor: anchor, value: .string("Initial"))]),
            outboundChannel: nil
        )

        await waitUntil { !store.isReconcilingAppliedDefaults }

        XCTAssertEqual(store.tweaks.first?.value, .string("Applied"))
        XCTAssertEqual(outbound.messages.last, .update(id: "Basic/Layout/Title", value: .string("Applied")))
    }

    func testApplyingSourceWithoutProjectRootProducesAnAlertWithoutCallingEditor() async {
        let sourceEditor = StubSourceEditor(outcome: .success(.init(edits: [])))
        let store = TinkerbleCompanionStore(
            versionRepository: TinkerbleInMemoryVersionRepository(),
            sourceEditor: sourceEditor
        )
        let tweak = sourceTweak(anchor: sourceAnchor(initializer: "\"Initial\""), value: .string("Initial"))
        store.handle(.register(tweak), outboundChannel: nil)
        store.updateTweak(id: tweak.id, value: .string("Edited"))
        await waitUntil { !store.isReconcilingAppliedDefaults }

        store.applyTweakToSource(id: tweak.id)

        XCTAssertNotNil(store.sourceEditAlert)
        let applyCount = await sourceEditor.applyCount
        XCTAssertEqual(applyCount, 0)
    }

    func testApplyingSourceForDifferentProjectProducesAnAlertWithoutCallingEditor() async {
        let sourceEditor = StubSourceEditor(outcome: .success(.init(edits: [])))
        let store = TinkerbleCompanionStore(
            versionRepository: TinkerbleInMemoryVersionRepository(),
            sourceEditor: sourceEditor,
            sourceProjectRoot: URL(fileURLWithPath: "/tmp/TinkerbleProject"),
            sourceProjectID: "app.expected"
        )
        store.handle(
            .hello(role: .iOSApp, version: "test", project: .init(id: "app.connected", displayName: "Connected")),
            outboundChannel: nil
        )
        let tweak = sourceTweak(anchor: sourceAnchor(initializer: "\"Initial\""), value: .string("Initial"))
        store.handle(.register(tweak), outboundChannel: nil)
        store.updateTweak(id: tweak.id, value: .string("Edited"))
        await waitUntil { !store.isReconcilingAppliedDefaults }

        store.applyTweakToSource(id: tweak.id)

        XCTAssertNotNil(store.sourceEditAlert)
        let applyCount = await sourceEditor.applyCount
        XCTAssertEqual(applyCount, 0)
    }

    func testCategoryApplyAggregatesMultipleSourceIssuesIntoOneAlert() async {
        let root = URL(fileURLWithPath: "/tmp/TinkerbleProject")
        let first = sourceTweak(
            name: "Title",
            anchor: sourceAnchor(propertyName: "title", initializer: "\"Initial\""),
            value: .string("Initial")
        )
        let second = sourceTweak(
            name: "Subtitle",
            anchor: sourceAnchor(propertyName: "subtitle", initializer: "\"Initial\""),
            value: .string("Initial")
        )
        let applyError = TinkerbleSourceApplyError(
            issues: [
                .init(tweak: first, reason: .fileMissing(first.sourceAnchors[0].filePath)),
                .init(tweak: second, reason: .staleInitializer(expected: ["\"Initial\""], actual: "\"Manual\""))
            ]
        )
        let sourceEditor = StubSourceEditor(outcome: .failure(applyError))
        let store = TinkerbleCompanionStore(
            versionRepository: TinkerbleInMemoryVersionRepository(),
            sourceEditor: sourceEditor,
            sourceProjectRoot: root,
            sourceProjectID: "app.test"
        )
        store.handle(
            .hello(role: .iOSApp, version: "test", project: .init(id: "app.test", displayName: "Test")),
            outboundChannel: nil
        )
        store.handle(.snapshot([first, second]), outboundChannel: nil)
        store.updateTweak(id: first.id, value: .string("First Edited"))
        store.updateTweak(id: second.id, value: .string("Second Edited"))
        await waitUntil { !store.isReconcilingAppliedDefaults }

        store.applyCategoryToSource("Layout")
        await waitUntil { store.sourceEditingTweakIDs.isEmpty }

        let message = store.sourceEditAlert?.message
        XCTAssertNotNil(message)
        XCTAssertTrue(message?.contains(first.name) == true)
        XCTAssertTrue(message?.contains(second.name) == true)
    }

    func testSourceActionsWaitForAppliedDefaultReconciliation() async {
        let root = URL(fileURLWithPath: "/tmp/TinkerbleProject")
        let store = TinkerbleCompanionStore(
            versionRepository: TinkerbleInMemoryVersionRepository(),
            sourceEditor: StubSourceEditor(outcome: .success(.init(edits: []))),
            appliedDefaultRepository: TinkerbleInMemoryAppliedDefaultRepository(),
            sourceProjectRoot: root,
            sourceProjectID: "app.test"
        )
        store.handle(
            .hello(role: .iOSApp, version: "test", project: .init(id: "app.test", displayName: "Test")),
            outboundChannel: nil
        )
        let tweak = sourceTweak(anchor: sourceAnchor(initializer: "\"Initial\""), value: .string("Initial"))
        store.handle(.register(tweak), outboundChannel: nil)
        store.updateTweak(id: tweak.id, value: .string("Edited"))

        XCTAssertTrue(store.isReconcilingAppliedDefaults)
        XCTAssertFalse(store.canApplyTweakToSource(tweak.id))
        XCTAssertFalse(store.canResetCategoryToDefaults("Layout"))

        await waitUntil { !store.isReconcilingAppliedDefaults }

        XCTAssertTrue(store.canApplyTweakToSource(tweak.id))
        XCTAssertTrue(store.canResetCategoryToDefaults("Layout"))
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

    private func sourceTweak(
        name: String = "Title",
        anchor: TinkerbleSourceAnchor,
        value: TinkerbleValue
    ) -> TinkerbleTweak {
        TinkerbleTweak(
            id: TinkerbleTweak.makeID(screen: "Basic", category: "Layout", name: name),
            screen: "Basic",
            category: "Layout",
            name: name,
            value: value,
            codeDefaultValue: value,
            valueKind: value.kind,
            control: .automatic,
            sourceValueType: .string,
            sourceAnchors: [anchor]
        )
    }

    private func sourceAnchor(
        propertyName: String = "title",
        initializer: String,
        fileURL: URL = URL(fileURLWithPath: "/tmp/TinkerbleProject/View.swift")
    ) -> TinkerbleSourceAnchor {
        TinkerbleSourceAnchor(
            filePath: fileURL.path,
            line: 4,
            column: 5,
            enclosingTypePath: ["View"],
            propertyName: propertyName,
            initializerExpression: initializer
        )
    }

    private func waitUntil(
        _ condition: @escaping @MainActor () -> Bool,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        for _ in 0 ..< 1_000 {
            if condition() {
                return
            }
            await Task.yield()
        }
        XCTFail("Timed out waiting for asynchronous store work", file: file, line: line)
    }
}

private final class RecordingOutboundChannel: TinkerbleCompanionOutboundChannel {
    var messages: [TinkerbleWireMessage] = []

    func send(_ message: TinkerbleWireMessage) {
        messages.append(message)
    }

    func close() {}
}

private actor StubSourceEditor: TinkerbleSourceEditing {
    enum Outcome: Sendable {
        case success(TinkerbleSourceApplyResult)
        case failure(TinkerbleSourceApplyError)
    }

    private let outcome: Outcome
    private(set) var applyCount = 0

    init(outcome: Outcome) {
        self.outcome = outcome
    }

    func apply(_ requests: [TinkerbleSourceApplyRequest]) async throws -> TinkerbleSourceApplyResult {
        applyCount += 1
        switch outcome {
        case let .success(result):
            return result
        case let .failure(error):
            throw error
        }
    }
}

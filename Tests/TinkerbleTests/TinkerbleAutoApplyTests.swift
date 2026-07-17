import Foundation
@testable import Tinkerble
@testable import TinkerbleCompanionCore
import XCTest

@MainActor
final class TinkerbleAutoApplyTests: XCTestCase {
    func testAutoApplyUsesTwoSecondDefaultDelay() {
        XCTAssertEqual(TinkerbleCompanionStore.defaultAutoApplyDelay, .seconds(2))
    }

    func testAutoApplyDefaultsToOffAndDoesNotWriteSource() async {
        let sourceEditor = RecordingAutoApplySourceEditor()
        let store = makeStore(sourceEditor: sourceEditor)
        let tweak = makeTweak(name: "Enabled", value: .bool(true), sourceValueType: .bool)
        store.handle(.register(tweak), outboundChannel: nil)
        await waitForReconciliation(in: store)

        XCTAssertFalse(store.isAutoApplyEnabled)

        store.updateTweak(id: tweak.id, value: .bool(false))
        try? await Task.sleep(for: .milliseconds(80))

        let applyCount = await sourceEditor.applyCount
        XCTAssertEqual(applyCount, 0)
    }

    func testBooleanAndEnumChangesApplyImmediately() async {
        let sourceEditor = RecordingAutoApplySourceEditor()
        let store = makeStore(sourceEditor: sourceEditor)
        let boolTweak = makeTweak(name: "Enabled", value: .bool(true), sourceValueType: .bool)
        let enumTweak = makeTweak(
            name: "Mood",
            value: .enumCase("focused"),
            sourceValueType: .enumeration(typeName: "Mood")
        )
        store.handle(.snapshot([boolTweak, enumTweak]), outboundChannel: nil)
        await waitForReconciliation(in: store)
        store.setAutoApplyEnabled(true)

        store.updateTweak(id: boolTweak.id, value: .bool(false))
        await waitForApplyCount(1, sourceEditor: sourceEditor)
        store.updateTweak(id: enumTweak.id, value: .enumCase("celebratory"))
        await waitForApplyCount(2, sourceEditor: sourceEditor)

        let appliedValues = await sourceEditor.appliedValues
        XCTAssertEqual(appliedValues, [.bool(false), .enumCase("celebratory")])
    }

    func testNumberChangesWaitForDelayAndCoalesceToLatestValue() async {
        let sourceEditor = RecordingAutoApplySourceEditor()
        let store = makeStore(sourceEditor: sourceEditor, autoApplyDelay: .milliseconds(60))
        let tweak = makeTweak(name: "Count", value: .number(1), sourceValueType: .int)
        store.handle(.register(tweak), outboundChannel: nil)
        await waitForReconciliation(in: store)
        store.setAutoApplyEnabled(true)

        store.updateTweak(id: tweak.id, value: .number(2))
        try? await Task.sleep(for: .milliseconds(20))
        var applyCount = await sourceEditor.applyCount
        XCTAssertEqual(applyCount, 0)

        store.updateTweak(id: tweak.id, value: .number(3))
        try? await Task.sleep(for: .milliseconds(20))
        applyCount = await sourceEditor.applyCount
        XCTAssertEqual(applyCount, 0)

        await waitForApplyCount(1, sourceEditor: sourceEditor)

        let appliedValues = await sourceEditor.appliedValues
        XCTAssertEqual(appliedValues, [.number(3)])
    }

    func testCoalescedSliderChangeWritesOnlyAfterInteractionEnds() async {
        let sourceEditor = RecordingAutoApplySourceEditor()
        let store = makeStore(sourceEditor: sourceEditor, autoApplyDelay: .milliseconds(30))
        let tweak = makeTweak(
            name: "Opacity",
            value: .number(0.5),
            sourceValueType: .double,
            control: .slider(.init(minimum: 0, maximum: 1, step: 0.01, decimalPlaces: 2))
        )
        store.handle(.register(tweak), outboundChannel: nil)
        await waitForReconciliation(in: store)
        store.setAutoApplyEnabled(true)

        store.beginCoalescedTweakUpdate(id: tweak.id)
        store.updateCoalescedTweak(id: tweak.id, value: .number(0.6))
        store.updateCoalescedTweak(id: tweak.id, value: .number(0.7))
        store.updateCoalescedTweak(id: tweak.id, value: .number(0.8))
        try? await Task.sleep(for: .milliseconds(80))

        let applyCount = await sourceEditor.applyCount
        XCTAssertEqual(applyCount, 0)

        store.endCoalescedTweakUpdate(id: tweak.id)
        await waitForApplyCount(1, sourceEditor: sourceEditor)

        let appliedValues = await sourceEditor.appliedValues
        XCTAssertEqual(appliedValues, [.number(0.8)])
    }

    func testCoalescedTextChangesWaitForDelayAfterLastEditAcrossCheckpoints() async {
        let sourceEditor = RecordingAutoApplySourceEditor()
        let store = makeStore(sourceEditor: sourceEditor, autoApplyDelay: .milliseconds(60))
        let tweak = makeTweak(name: "Title", value: .string("Initial"), sourceValueType: .string)
        store.handle(.register(tweak), outboundChannel: nil)
        await waitForReconciliation(in: store)
        store.setAutoApplyEnabled(true)

        store.beginCoalescedTweakUpdate(id: tweak.id)
        store.updateCoalescedTweak(id: tweak.id, value: .string("E"))
        try? await Task.sleep(for: .milliseconds(40))

        store.endCoalescedTweakUpdate(id: tweak.id)
        store.beginCoalescedTweakUpdate(id: tweak.id)
        store.updateCoalescedTweak(id: tweak.id, value: .string("Edited"))
        store.endCoalescedTweakUpdate(id: tweak.id)
        try? await Task.sleep(for: .milliseconds(40))

        var applyCount = await sourceEditor.applyCount
        XCTAssertEqual(applyCount, 0)

        await waitForApplyCount(1, sourceEditor: sourceEditor)

        applyCount = await sourceEditor.applyCount
        let appliedValues = await sourceEditor.appliedValues
        XCTAssertEqual(applyCount, 1)
        XCTAssertEqual(appliedValues, [.string("Edited")])
    }

    func testTurningAutoApplyOffCancelsDelayedNumberWrite() async {
        let sourceEditor = RecordingAutoApplySourceEditor()
        let store = makeStore(sourceEditor: sourceEditor, autoApplyDelay: .milliseconds(50))
        let tweak = makeTweak(name: "Count", value: .number(1), sourceValueType: .int)
        store.handle(.register(tweak), outboundChannel: nil)
        await waitForReconciliation(in: store)
        store.setAutoApplyEnabled(true)

        store.updateTweak(id: tweak.id, value: .number(2))
        store.setAutoApplyEnabled(false)
        try? await Task.sleep(for: .milliseconds(100))

        XCTAssertFalse(store.isAutoApplyEnabled)
        let applyCount = await sourceEditor.applyCount
        XCTAssertEqual(applyCount, 0)
    }

    func testAutoApplyWritesThroughRealSourceEditingService() async throws {
        let root = FileManager.default.temporaryDirectory.appending(
            path: "TinkerbleAutoApplyTests-\(UUID().uuidString)",
            directoryHint: .isDirectory
        )
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        let sourceURL = root.appending(path: "Fixture.swift")
        let originalSource = """
        struct Fixture {
            @TinkerbleState("Enabled") var isEnabled = true
        }
        """
        try originalSource.write(to: sourceURL, atomically: true, encoding: .utf8)

        let store = TinkerbleCompanionStore(
            versionRepository: TinkerbleInMemoryVersionRepository(),
            sourceEditor: TinkerbleSourceEditingService(),
            appliedDefaultRepository: TinkerbleInMemoryAppliedDefaultRepository(),
            sourceProjectRoot: root,
            sourceProjectID: "app.test"
        )
        store.handle(
            .hello(role: .iOSApp, version: "test", project: .init(id: "app.test", displayName: "Test")),
            outboundChannel: nil
        )
        let tweak = makeTweak(
            name: "Enabled",
            value: .bool(true),
            sourceValueType: .bool,
            fileURL: sourceURL,
            enclosingTypePath: ["Fixture"],
            propertyName: "isEnabled",
            initializerExpression: "true"
        )
        store.handle(.register(tweak), outboundChannel: nil)
        await waitForReconciliation(in: store)
        store.setAutoApplyEnabled(true)

        store.updateTweak(id: tweak.id, value: .bool(false))
        await waitForSource("""
        struct Fixture {
            @TinkerbleState("Enabled") var isEnabled = false
        }
        """, at: sourceURL)

        XCTAssertEqual(try String(contentsOf: sourceURL, encoding: .utf8), """
        struct Fixture {
            @TinkerbleState("Enabled") var isEnabled = false
        }
        """)
    }

    private func makeStore(
        sourceEditor: any TinkerbleSourceEditing,
        autoApplyDelay: Duration = .milliseconds(20)
    ) -> TinkerbleCompanionStore {
        let store = TinkerbleCompanionStore(
            versionRepository: TinkerbleInMemoryVersionRepository(),
            sourceEditor: sourceEditor,
            appliedDefaultRepository: TinkerbleInMemoryAppliedDefaultRepository(),
            sourceProjectRoot: URL(fileURLWithPath: "/tmp/TinkerbleAutoApplyTests"),
            sourceProjectID: "app.test",
            autoApplyDelay: autoApplyDelay
        )
        store.handle(
            .hello(role: .iOSApp, version: "test", project: .init(id: "app.test", displayName: "Test")),
            outboundChannel: nil
        )
        return store
    }

    private func makeTweak(
        name: String,
        value: TinkerbleValue,
        sourceValueType: TinkerbleSourceValueType,
        control: TinkerbleControlDescriptor = .automatic,
        fileURL: URL = URL(fileURLWithPath: "/tmp/TinkerbleAutoApplyTests/Fixture.swift"),
        enclosingTypePath: [String] = ["Fixture"],
        propertyName: String? = nil,
        initializerExpression: String? = nil
    ) -> TinkerbleTweak {
        let propertyName = propertyName ?? name.lowercased()
        let initializerExpression = initializerExpression ?? expression(for: value)
        return TinkerbleTweak(
            id: TinkerbleTweak.makeID(screen: "Basic", category: "Values", name: name),
            screen: "Basic",
            category: "Values",
            name: name,
            value: value,
            codeDefaultValue: value,
            valueKind: value.kind,
            control: control,
            sourceValueType: sourceValueType,
            sourceAnchors: [
                .init(
                    filePath: fileURL.path,
                    line: 2,
                    column: 5,
                    enclosingTypePath: enclosingTypePath,
                    propertyName: propertyName,
                    initializerExpression: initializerExpression
                )
            ]
        )
    }

    private func expression(for value: TinkerbleValue) -> String {
        switch value {
        case let .string(value):
            "\"\(value)\""
        case let .bool(value):
            value ? "true" : "false"
        case .color:
            "Color.clear"
        case let .number(value):
            String(value)
        case .date:
            "Date()"
        case let .enumCase(value):
            ".\(value)"
        case .action:
            "()"
        }
    }

    private func waitForReconciliation(in store: TinkerbleCompanionStore) async {
        for _ in 0 ..< 1000 {
            if !store.isReconcilingAppliedDefaults {
                return
            }
            await Task.yield()
        }
        XCTFail("Timed out waiting for applied-default reconciliation")
    }

    private func waitForApplyCount(
        _ expectedCount: Int,
        sourceEditor: RecordingAutoApplySourceEditor
    ) async {
        for _ in 0 ..< 1000 {
            if await sourceEditor.applyCount == expectedCount {
                return
            }
            try? await Task.sleep(for: .milliseconds(1))
        }
        XCTFail("Timed out waiting for \(expectedCount) source applies")
    }

    private func waitForSource(_ expectedSource: String, at url: URL) async {
        for _ in 0 ..< 1000 {
            if (try? String(contentsOf: url, encoding: .utf8)) == expectedSource {
                return
            }
            try? await Task.sleep(for: .milliseconds(1))
        }
        XCTFail("Timed out waiting for source edit")
    }
}

private actor RecordingAutoApplySourceEditor: TinkerbleSourceEditing {
    private(set) var appliedValues: [TinkerbleValue] = []
    private(set) var applyCount = 0

    func apply(_ requests: [TinkerbleSourceApplyRequest]) async throws -> TinkerbleSourceApplyResult {
        applyCount += 1
        appliedValues.append(contentsOf: requests.map(\.tweak.value))
        return .init(
            edits: requests.compactMap { request in
                guard let anchor = request.tweak.sourceAnchors.first else { return nil }
                return TinkerbleAppliedSourceEdit(
                    tweakID: request.tweak.id,
                    anchor: anchor,
                    previousExpression: anchor.initializerExpression,
                    writtenExpression: "updated",
                    originalFileHash: "before",
                    writtenFileHash: "after"
                )
            }
        )
    }
}

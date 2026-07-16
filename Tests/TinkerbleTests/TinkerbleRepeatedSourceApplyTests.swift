import Foundation
@testable import Tinkerble
@testable import TinkerbleCompanionCore
import XCTest

@MainActor
final class TinkerbleRepeatedSourceApplyTests: XCTestCase {
    private static let tweakID = "Basic/Values/Amount"

    func testManualAndAutoApplyRewriteTheSameNumericSource() async throws {
        let (sourceURL, store) = try makeFixture()
        addTeardownBlock { try? FileManager.default.removeItem(at: sourceURL.deletingLastPathComponent()) }
        await waitForReconciliation(in: store)

        store.updateTweak(id: Self.tweakID, value: .number(2.5))
        store.applyTweakToSource(id: Self.tweakID)
        await waitForSource(expression: "2.5", at: sourceURL)
        await waitForSourceEditingToFinish(in: store)

        store.setAutoApplyEnabled(true)
        store.updateTweak(id: Self.tweakID, value: .number(3.5))
        await waitForSource(expression: "3.5", at: sourceURL)
        await waitForSourceEditingToFinish(in: store)

        XCTAssertNil(store.sourceEditAlert)
        XCTAssertFalse(store.canApplyTweakToSource(Self.tweakID))
    }

    func testEnablingAutoApplyWritesAValueChangedWhileItWasOff() async throws {
        let (sourceURL, store) = try makeFixture()
        addTeardownBlock { try? FileManager.default.removeItem(at: sourceURL.deletingLastPathComponent()) }
        await waitForReconciliation(in: store)

        store.updateTweak(id: Self.tweakID, value: .number(2.5))
        store.setAutoApplyEnabled(true)

        await waitForSource(expression: "2.5", at: sourceURL)
        await waitForSourceEditingToFinish(in: store)

        XCTAssertNil(store.sourceEditAlert)
        XCTAssertFalse(store.canApplyTweakToSource(Self.tweakID))
    }

    func testPersistedAutoApplyWritesSavedValueAfterReconnection() async throws {
        let versionRepository = TinkerbleInMemoryVersionRepository()
        let versions = try versionRepository.ensureVersions(projectID: "app.test", screen: "Basic")
        let version = try XCTUnwrap(versions.first)
        try versionRepository.saveValue(
            projectID: "app.test",
            screen: "Basic",
            versionID: version.id,
            tweakID: Self.tweakID,
            value: .number(2.5)
        )
        let (sourceURL, store) = try makeFixture(
            versionRepository: versionRepository,
            autoApplyPreference: EnabledAutoApplyPreference()
        )
        addTeardownBlock { try? FileManager.default.removeItem(at: sourceURL.deletingLastPathComponent()) }

        await waitForSource(expression: "2.5", at: sourceURL)
        await waitForSourceEditingToFinish(in: store)

        XCTAssertTrue(store.isAutoApplyEnabled)
        XCTAssertNil(store.sourceEditAlert)
        XCTAssertFalse(store.canApplyTweakToSource(Self.tweakID))
    }

    private func makeFixture(
        versionRepository: (any TinkerbleVersionRepository)? = nil,
        autoApplyPreference: (any TinkerbleAutoApplyPreference)? = nil
    ) throws -> (URL, TinkerbleCompanionStore) {
        let root = FileManager.default.temporaryDirectory.appending(
            path: "TinkerbleRepeatedSourceApplyTests-\(UUID().uuidString)",
            directoryHint: .isDirectory
        )
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let sourceURL = root.appending(path: "Fixture.swift")
        try source(expression: "1.0").write(to: sourceURL, atomically: true, encoding: .utf8)

        let store = TinkerbleCompanionStore(
            versionRepository: versionRepository ?? TinkerbleInMemoryVersionRepository(),
            sourceEditor: TinkerbleSourceEditingService(),
            appliedDefaultRepository: TinkerbleInMemoryAppliedDefaultRepository(),
            sourceProjectRoot: root,
            sourceProjectID: "app.test",
            autoApplyPreference: autoApplyPreference,
            autoApplyDelay: .milliseconds(30)
        )
        store.handle(
            .hello(role: .iOSApp, version: "test", project: .init(id: "app.test", displayName: "Test")),
            outboundChannel: nil
        )
        let anchor = TinkerbleSourceAnchor(
            filePath: sourceURL.path,
            line: 2,
            column: 5,
            enclosingTypePath: ["Fixture"],
            propertyName: "amount",
            initializerExpression: "1.0"
        )
        let tweak = TinkerbleTweak(
            id: Self.tweakID,
            screen: "Basic",
            category: "Values",
            name: "Amount",
            value: .number(1),
            codeDefaultValue: .number(1),
            valueKind: .number,
            control: .automatic,
            sourceValueType: .double,
            sourceAnchors: [anchor]
        )
        store.handle(.register(tweak), outboundChannel: nil)
        return (sourceURL, store)
    }

    private func source(expression: String) -> String {
        """
        struct Fixture {
            @TinkerbleState("Amount") var amount = \(expression)
        }
        """
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

    private func waitForSource(expression: String, at url: URL) async {
        for _ in 0 ..< 1000 {
            if (try? String(contentsOf: url, encoding: .utf8)) == source(expression: expression) {
                return
            }
            try? await Task.sleep(for: .milliseconds(1))
        }
        XCTFail("Timed out waiting for source edit")
    }

    private func waitForSourceEditingToFinish(in store: TinkerbleCompanionStore) async {
        for _ in 0 ..< 1000 {
            if store.sourceEditingTweakIDs.isEmpty {
                return
            }
            try? await Task.sleep(for: .milliseconds(1))
        }
        XCTFail("Timed out waiting for source editing to finish")
    }
}

@MainActor
private final class EnabledAutoApplyPreference: TinkerbleAutoApplyPreference {
    var isEnabled = true
}

import Foundation
import XCTest
@testable import Tinkerble
@testable import TinkerbleCompanionCore

final class TinkerbleAppliedDefaultRepositoryTests: XCTestCase {
    func testInMemoryRepositoryAppliesAndRemovesBatchAtomically() async throws {
        let repository = TinkerbleInMemoryAppliedDefaultRepository()
        let first = record(property: "first", value: .number(1))
        let second = record(property: "second", value: .number(2))

        try await repository.update([first, second])
        await repository.update([], removing: [first.key])
        let removedRecord = await repository.record(for: first.key)
        let retainedRecord = await repository.record(for: second.key)

        XCTAssertNil(removedRecord)
        XCTAssertEqual(retainedRecord, second)
    }

    func testJSONRepositoryPersistsAndReloadsRecords() async throws {
        let directory = FileManager.default.temporaryDirectory.appending(
            path: "TinkerbleAppliedDefaults-\(UUID().uuidString)",
            directoryHint: .isDirectory
        )
        let fileURL = directory.appending(path: "defaults.json")
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        let record = record(property: "value", value: .string("Applied"), sourceValueType: .string)

        try await TinkerbleJSONAppliedDefaultRepository(fileURL: fileURL).update([record])
        let reloaded = TinkerbleJSONAppliedDefaultRepository(fileURL: fileURL)
        let reloadedRecord = try await reloaded.record(for: record.key)

        XCTAssertEqual(reloadedRecord, record)
    }

    func testJSONRepositoryRecoversFromCorruptedDocument() async throws {
        let directory = FileManager.default.temporaryDirectory.appending(
            path: "TinkerbleAppliedDefaults-\(UUID().uuidString)",
            directoryHint: .isDirectory
        )
        let fileURL = directory.appending(path: "defaults.json")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data("not json".utf8).write(to: fileURL)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }

        let repository = TinkerbleJSONAppliedDefaultRepository(fileURL: fileURL)
        let records = try await repository.records(
            projectID: "test.project",
            canonicalProjectRoot: "/tmp/project"
        )
        let directoryContents = try FileManager.default.contentsOfDirectory(atPath: directory.path)

        XCTAssertTrue(records.isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: fileURL.path))
        XCTAssertEqual(directoryContents.filter { $0.hasPrefix("defaults.json.corrupt-") }.count, 1)
    }

    func testJSONRepositoryRecoversFromUnsupportedSchema() async throws {
        let directory = FileManager.default.temporaryDirectory.appending(
            path: "TinkerbleAppliedDefaults-\(UUID().uuidString)",
            directoryHint: .isDirectory
        )
        let fileURL = directory.appending(path: "defaults.json")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data(#"{"schemaVersion":999,"records":[]}"#.utf8).write(to: fileURL)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }

        let repository = TinkerbleJSONAppliedDefaultRepository(fileURL: fileURL)
        let records = try await repository.records(
            projectID: "test.project",
            canonicalProjectRoot: "/tmp/project"
        )
        let directoryContents = try FileManager.default.contentsOfDirectory(atPath: directory.path)

        XCTAssertTrue(records.isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: fileURL.path))
        XCTAssertEqual(directoryContents.filter { $0.hasPrefix("defaults.json.corrupt-") }.count, 1)
    }

    func testReconcileKeepsAppliedDefaultBeforeRebuild() async throws {
        let fixture = try sourceFixture(initializer: "27")
        let repository = TinkerbleInMemoryAppliedDefaultRepository()
        let applied = record(
            property: "value",
            value: .number(27),
            compiled: "1",
            written: "27",
            projectRoot: fixture.root,
            fileURL: fixture.fileURL
        )
        try await repository.update([applied])
        let tweak = sourceTweak(
            property: "value",
            defaultValue: .number(1),
            initializer: "1",
            fileURL: fixture.fileURL
        )

        let resolutions = try await repository.reconcile(
            projectID: "test.project",
            projectRoot: fixture.root,
            tweaks: [tweak]
        )

        XCTAssertEqual(resolutions["value"]?.effectiveValue, .number(27))
        XCTAssertEqual(resolutions["value"]?.acceptedInitializerExpressions, ["27"])
    }

    func testReconcileUsesCompiledDefaultAndRemovesCacheAfterRebuild() async throws {
        let fixture = try sourceFixture(initializer: "27")
        let repository = TinkerbleInMemoryAppliedDefaultRepository()
        let applied = record(
            property: "value",
            value: .number(27),
            compiled: "1",
            written: "27",
            projectRoot: fixture.root,
            fileURL: fixture.fileURL
        )
        try await repository.update([applied])
        let rebuilt = sourceTweak(
            property: "value",
            defaultValue: .number(27),
            initializer: "27",
            fileURL: fixture.fileURL
        )

        let resolutions = try await repository.reconcile(
            projectID: "test.project",
            projectRoot: fixture.root,
            tweaks: [rebuilt]
        )
        let removedRecord = await repository.record(for: applied.key)

        XCTAssertEqual(resolutions["value"]?.effectiveValue, .number(27))
        XCTAssertNil(removedRecord)
    }

    func testReconcileRemovesCacheWhenRebuiltSourceWasReverted() async throws {
        let fixture = try sourceFixture(initializer: "1")
        let repository = TinkerbleInMemoryAppliedDefaultRepository()
        let applied = record(
            property: "value",
            value: .number(27),
            compiled: "1",
            written: "27",
            projectRoot: fixture.root,
            fileURL: fixture.fileURL
        )
        try await repository.update([applied])
        let rebuilt = sourceTweak(
            property: "value",
            defaultValue: .number(1),
            initializer: "1",
            fileURL: fixture.fileURL
        )

        let resolutions = try await repository.reconcile(
            projectID: "test.project",
            projectRoot: fixture.root,
            tweaks: [rebuilt]
        )
        let removedRecord = await repository.record(for: applied.key)

        XCTAssertEqual(resolutions["value"]?.effectiveValue, .number(1))
        XCTAssertNil(removedRecord)
    }

    func testReconcileRejectsAppliedDefaultFromDifferentSourceValueType() async throws {
        let repository = TinkerbleInMemoryAppliedDefaultRepository()
        let applied = record(
            property: "value",
            value: .number(27),
            sourceValueType: .int,
            compiled: "1",
            written: "27"
        )
        try await repository.update([applied])
        let tweak = sourceTweak(
            property: "value",
            defaultValue: .number(1),
            initializer: "1",
            sourceValueType: .double
        )

        let resolutions = try await repository.reconcile(
            projectID: "test.project",
            projectRoot: URL(fileURLWithPath: "/tmp/project"),
            tweaks: [tweak]
        )
        let removedRecord = await repository.record(for: applied.key)

        XCTAssertEqual(resolutions["value"]?.effectiveValue, .number(1))
        XCTAssertNil(removedRecord)
    }

    private func record(
        property: String,
        value: TinkerbleValue,
        sourceValueType: TinkerbleSourceValueType = .int,
        compiled: String = "1",
        written: String = "2",
        projectRoot: URL = URL(fileURLWithPath: "/tmp/project"),
        fileURL: URL? = nil
    ) -> TinkerbleAppliedDefaultRecord {
        let sourceFileURL = fileURL ?? projectRoot.appending(path: "Fixture.swift")
        let anchor = TinkerbleSourceAnchor(
            filePath: sourceFileURL.path,
            line: 1,
            column: 1,
            enclosingTypePath: ["Fixture"],
            propertyName: property,
            initializerExpression: compiled
        )
        return .init(
            key: .init(
                projectID: "test.project",
                canonicalProjectRoot: projectRoot.path,
                anchorStableID: anchor.stableID
            ),
            anchor: anchor,
            value: value,
            sourceValueType: sourceValueType,
            compiledInitializerExpression: compiled,
            writtenInitializerExpression: written
        )
    }

    private func sourceTweak(
        property: String,
        defaultValue: TinkerbleValue,
        initializer: String,
        sourceValueType: TinkerbleSourceValueType = .int,
        fileURL: URL = URL(fileURLWithPath: "/tmp/project/Fixture.swift")
    ) -> TinkerbleTweak {
        let anchor = TinkerbleSourceAnchor(
            filePath: fileURL.path,
            line: 1,
            column: 1,
            enclosingTypePath: ["Fixture"],
            propertyName: property,
            initializerExpression: initializer
        )
        return TinkerbleTweak(
            id: property,
            category: "Tests",
            name: property,
            value: defaultValue,
            codeDefaultValue: defaultValue,
            valueKind: defaultValue.kind,
            control: .automatic,
            sourceValueType: sourceValueType,
            sourceAnchors: [anchor]
        )
    }

    private func sourceFixture(initializer: String) throws -> (root: URL, fileURL: URL) {
        let root = FileManager.default.temporaryDirectory.appending(
            path: "TinkerbleAppliedDefaultSource-\(UUID().uuidString)",
            directoryHint: .isDirectory
        )
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let fileURL = root.appending(path: "Fixture.swift")
        let data = Data(source(initializer: initializer).utf8)
        try data.write(to: fileURL)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        return (root, fileURL)
    }

    private func source(initializer: String) -> String {
        """
        struct Fixture {
            @TinkerbleState("Value") var value = \(initializer)
        }
        """
    }
}

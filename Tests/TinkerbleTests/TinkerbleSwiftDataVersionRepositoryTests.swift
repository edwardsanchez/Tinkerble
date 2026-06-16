import XCTest
import SwiftData
@testable import Tinkerble
@testable import TinkerbleCompanionCore

@MainActor
final class TinkerbleSwiftDataVersionRepositoryTests: XCTestCase {
    func testSwiftDataRepositoryCreatesVersionsAndPersistsValues() throws {
        let repository = try TinkerbleSwiftDataVersionRepository(isStoredInMemoryOnly: true)
        let versions = try repository.ensureVersions(projectID: "app.test", screen: "Home")
        let versionOne = try XCTUnwrap(versions.first)

        try repository.saveValue(
            projectID: "app.test",
            screen: "Home",
            versionID: versionOne.id,
            tweakID: "Title",
            value: .string("Version One")
        )

        let updatedVersions = try repository.createVersion(
            projectID: "app.test",
            screen: "Home",
            values: ["Title": .string("Version Two")]
        )
        let versionTwo = try XCTUnwrap(updatedVersions.first { $0.ordinal == 2 })

        XCTAssertEqual(versions.map(\.name), ["Version 1"])
        XCTAssertEqual(updatedVersions.map(\.name), ["Version 1", "Version 2"])
        XCTAssertEqual(
            try repository.value(projectID: "app.test", screen: "Home", versionID: versionOne.id, tweakID: "Title"),
            .string("Version One")
        )
        XCTAssertEqual(
            try repository.value(projectID: "app.test", screen: "Home", versionID: versionTwo.id, tweakID: "Title"),
            .string("Version Two")
        )
    }

    func testSwiftDataRepositoryPersistsValuesAcrossRepositoryInstances() throws {
        let directory = URL.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: directory)
        }

        let storeURL = directory.appending(path: "Versions.store")
        let versionID: UUID

        do {
            let repository = try makeDiskBackedRepository(storeURL: storeURL)
            let version = try XCTUnwrap(repository.ensureVersions(projectID: "app.test", screen: "Home").first)
            versionID = version.id
            try repository.saveValue(
                projectID: "app.test",
                screen: "Home",
                versionID: version.id,
                tweakID: "Title",
                value: .string("Persisted")
            )
        }

        let reloadedRepository = try makeDiskBackedRepository(storeURL: storeURL)

        XCTAssertEqual(
            try reloadedRepository.value(projectID: "app.test", screen: "Home", versionID: versionID, tweakID: "Title"),
            .string("Persisted")
        )
        XCTAssertEqual(
            try reloadedRepository.ensureVersions(projectID: "app.test", screen: "Home").map(\.id),
            [versionID]
        )
    }

    func testSwiftDataRepositoryDeletesOnlyNonProtectedVersions() throws {
        let repository = try TinkerbleSwiftDataVersionRepository(isStoredInMemoryOnly: true)
        let versionOne = try XCTUnwrap(repository.ensureVersions(projectID: "app.test", screen: "Home").first)
        let versionTwo = try XCTUnwrap(
            repository.createVersion(projectID: "app.test", screen: "Home", values: [:])
                .first { $0.ordinal == 2 }
        )

        let afterProtectedDelete = try repository.deleteVersion(
            projectID: "app.test",
            screen: "Home",
            versionID: versionOne.id
        )
        let afterVersionTwoDelete = try repository.deleteVersion(
            projectID: "app.test",
            screen: "Home",
            versionID: versionTwo.id
        )

        XCTAssertEqual(afterProtectedDelete.map(\.name), ["Version 1", "Version 2"])
        XCTAssertEqual(afterVersionTwoDelete.map(\.name), ["Version 1"])
    }

    func testSwiftDataRepositoryResetClearsSavedValuesWithoutDeletingVersion() throws {
        let repository = try TinkerbleSwiftDataVersionRepository(isStoredInMemoryOnly: true)
        let versionOne = try XCTUnwrap(repository.ensureVersions(projectID: "app.test", screen: "Home").first)

        try repository.saveValue(
            projectID: "app.test",
            screen: "Home",
            versionID: versionOne.id,
            tweakID: "Title",
            value: .string("Edited")
        )

        XCTAssertEqual(
            try repository.value(projectID: "app.test", screen: "Home", versionID: versionOne.id, tweakID: "Title"),
            .string("Edited")
        )

        try repository.resetVersion(projectID: "app.test", screen: "Home", versionID: versionOne.id)

        XCTAssertNil(
            try repository.value(projectID: "app.test", screen: "Home", versionID: versionOne.id, tweakID: "Title")
        )
        XCTAssertEqual(
            try repository.ensureVersions(projectID: "app.test", screen: "Home").map(\.id),
            [versionOne.id]
        )
    }

    private func makeDiskBackedRepository(storeURL: URL) throws -> TinkerbleSwiftDataVersionRepository {
        let configuration = ModelConfiguration(url: storeURL)
        let container = try ModelContainer(
            for: SavedTinkerbleVersionModel.self,
            SavedTinkerbleValueModel.self,
            configurations: configuration
        )
        return TinkerbleSwiftDataVersionRepository(modelContext: ModelContext(container))
    }
}

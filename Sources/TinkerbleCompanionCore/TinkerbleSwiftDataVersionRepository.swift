import Foundation
import SwiftData
import Tinkerble

@MainActor
public final class TinkerbleSwiftDataVersionRepository: TinkerbleVersionRepository {
    private let modelContext: ModelContext
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public convenience init(isStoredInMemoryOnly: Bool = false) throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: isStoredInMemoryOnly)
        let modelContainer = try ModelContainer(
            for: SavedTinkerbleVersionModel.self,
            SavedTinkerbleValueModel.self,
            configurations: configuration
        )
        self.init(modelContext: ModelContext(modelContainer))
    }

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    public func ensureVersions(projectID: String, screen: String) throws -> [TinkerbleSavedVersion] {
        var models = try versionModels(projectID: projectID, screen: screen)
        if models.isEmpty {
            let version = SavedTinkerbleVersionModel(projectID: projectID, screen: screen, ordinal: 1)
            modelContext.insert(version)
            try modelContext.save()
            models = [version]
        }
        return models.map(\.savedVersion)
    }

    public func createVersion(
        projectID: String,
        screen: String,
        values: [String: TinkerbleValue]
    ) throws -> [TinkerbleSavedVersion] {
        let existingVersions = try versionModels(projectID: projectID, screen: screen)
        let nextOrdinal = (existingVersions.map(\.ordinal).max() ?? 0) + 1
        let version = SavedTinkerbleVersionModel(projectID: projectID, screen: screen, ordinal: nextOrdinal)
        modelContext.insert(version)
        for (tweakID, value) in values {
            try saveValue(
                projectID: projectID,
                screen: screen,
                versionID: version.id,
                tweakID: tweakID,
                value: value,
                savesContext: false
            )
        }
        try modelContext.save()
        return try versionModels(projectID: projectID, screen: screen).map(\.savedVersion)
    }

    public func deleteVersion(projectID: String, screen: String, versionID: UUID) throws -> [TinkerbleSavedVersion] {
        guard let version = try versionModel(projectID: projectID, screen: screen, versionID: versionID),
              version.ordinal != 1
        else {
            return try ensureVersions(projectID: projectID, screen: screen)
        }

        let values = try valueModels(projectID: projectID, screen: screen, versionID: versionID)
        for value in values {
            modelContext.delete(value)
        }
        modelContext.delete(version)
        try modelContext.save()
        return try ensureVersions(projectID: projectID, screen: screen)
    }

    public func resetVersion(projectID: String, screen: String, versionID: UUID) throws {
        let values = try valueModels(projectID: projectID, screen: screen, versionID: versionID)
        for value in values {
            modelContext.delete(value)
        }
        try modelContext.save()
    }

    public func value(projectID: String, screen: String, versionID: UUID, tweakID: String) throws -> TinkerbleValue? {
        guard let valueModel = try valueModel(projectID: projectID, screen: screen, versionID: versionID, tweakID: tweakID) else {
            return nil
        }
        return try decoder.decode(TinkerbleValue.self, from: valueModel.encodedValue)
    }

    public func saveValue(projectID: String, screen: String, versionID: UUID, tweakID: String, value: TinkerbleValue) throws {
        try saveValue(projectID: projectID, screen: screen, versionID: versionID, tweakID: tweakID, value: value, savesContext: true)
    }

    private func saveValue(
        projectID: String,
        screen: String,
        versionID: UUID,
        tweakID: String,
        value: TinkerbleValue,
        savesContext: Bool
    ) throws {
        let encodedValue = try encoder.encode(value)
        if let valueModel = try valueModel(projectID: projectID, screen: screen, versionID: versionID, tweakID: tweakID) {
            valueModel.valueKind = value.kind.rawValue
            valueModel.encodedValue = encodedValue
            valueModel.updatedAt = Date()
        } else {
            modelContext.insert(
                SavedTinkerbleValueModel(
                    projectID: projectID,
                    screen: screen,
                    versionID: versionID,
                    tweakID: tweakID,
                    value: value,
                    encodedValue: encodedValue
                )
            )
        }
        if savesContext {
            try modelContext.save()
        }
    }

    private func versionModels(projectID: String, screen: String) throws -> [SavedTinkerbleVersionModel] {
        let descriptor = FetchDescriptor<SavedTinkerbleVersionModel>(
            predicate: #Predicate { version in
                version.projectID == projectID && version.screen == screen
            },
            sortBy: [SortDescriptor(\.ordinal)]
        )
        return try modelContext.fetch(descriptor)
    }

    private func versionModel(projectID: String, screen: String, versionID: UUID) throws -> SavedTinkerbleVersionModel? {
        let descriptor = FetchDescriptor<SavedTinkerbleVersionModel>(
            predicate: #Predicate { version in
                version.projectID == projectID && version.screen == screen && version.id == versionID
            }
        )
        return try modelContext.fetch(descriptor).first
    }

    private func valueModels(projectID: String, screen: String, versionID: UUID) throws -> [SavedTinkerbleValueModel] {
        let descriptor = FetchDescriptor<SavedTinkerbleValueModel>(
            predicate: #Predicate { value in
                value.projectID == projectID && value.screen == screen && value.versionID == versionID
            }
        )
        return try modelContext.fetch(descriptor)
    }

    private func valueModel(
        projectID: String,
        screen: String,
        versionID: UUID,
        tweakID: String
    ) throws -> SavedTinkerbleValueModel? {
        let descriptor = FetchDescriptor<SavedTinkerbleValueModel>(
            predicate: #Predicate { value in
                value.projectID == projectID
                    && value.screen == screen
                    && value.versionID == versionID
                    && value.tweakID == tweakID
            }
        )
        return try modelContext.fetch(descriptor).first
    }
}

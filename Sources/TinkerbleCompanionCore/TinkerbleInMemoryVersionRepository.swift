import Foundation
import Tinkerble

@MainActor
public final class TinkerbleInMemoryVersionRepository: TinkerbleVersionRepository {
    private var versionsByScope: [TinkerbleVersionScope: [TinkerbleSavedVersion]] = [:]
    private var valuesByKey: [TinkerbleVersionValueKey: TinkerbleValue] = [:]

    public init() {}

    public func ensureVersions(projectID: String, screen: String) throws -> [TinkerbleSavedVersion] {
        let scope = TinkerbleVersionScope(projectID: projectID, screen: screen)
        if versionsByScope[scope]?.isEmpty != false {
            versionsByScope[scope] = [TinkerbleSavedVersion(id: UUID(), ordinal: 1)]
        }
        return sortedVersions(for: scope)
    }

    public func createVersion(
        projectID: String,
        screen: String,
        values: [String: TinkerbleValue]
    ) throws -> [TinkerbleSavedVersion] {
        let scope = TinkerbleVersionScope(projectID: projectID, screen: screen)
        let existingVersions = try ensureVersions(projectID: projectID, screen: screen)
        let nextOrdinal = (existingVersions.map(\.ordinal).max() ?? 0) + 1
        let version = TinkerbleSavedVersion(id: UUID(), ordinal: nextOrdinal)
        versionsByScope[scope, default: []].append(version)
        for (tweakID, value) in values {
            try saveValue(projectID: projectID, screen: screen, versionID: version.id, tweakID: tweakID, value: value)
        }
        return sortedVersions(for: scope)
    }

    public func deleteVersion(projectID: String, screen: String, versionID: UUID) throws -> [TinkerbleSavedVersion] {
        let scope = TinkerbleVersionScope(projectID: projectID, screen: screen)
        let versions = try ensureVersions(projectID: projectID, screen: screen)
        guard let version = versions.first(where: { $0.id == versionID }), !version.isProtected else {
            return sortedVersions(for: scope)
        }

        versionsByScope[scope] = versions.filter { $0.id != versionID }
        valuesByKey = valuesByKey.filter { $0.key.versionID != versionID }
        return try ensureVersions(projectID: projectID, screen: screen)
    }

    public func resetVersion(projectID: String, screen: String, versionID: UUID) throws {
        valuesByKey = valuesByKey.filter { key, _ in
            key.projectID != projectID || key.screen != screen || key.versionID != versionID
        }
    }

    public func value(projectID: String, screen: String, versionID: UUID, tweakID: String) throws -> TinkerbleValue? {
        valuesByKey[
            TinkerbleVersionValueKey(
                projectID: projectID,
                screen: screen,
                versionID: versionID,
                tweakID: tweakID
            )
        ]
    }

    public func saveValue(projectID: String, screen: String, versionID: UUID, tweakID: String, value: TinkerbleValue) throws {
        valuesByKey[
            TinkerbleVersionValueKey(
                projectID: projectID,
                screen: screen,
                versionID: versionID,
                tweakID: tweakID
            )
        ] = value
    }

    private func sortedVersions(for scope: TinkerbleVersionScope) -> [TinkerbleSavedVersion] {
        (versionsByScope[scope] ?? []).sorted { $0.ordinal < $1.ordinal }
    }
}

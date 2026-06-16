import Foundation
import Tinkerble

@MainActor
public protocol TinkerbleVersionRepository: AnyObject {
    func ensureVersions(projectID: String, screen: String) throws -> [TinkerbleSavedVersion]
    func createVersion(
        projectID: String,
        screen: String,
        values: [String: TinkerbleValue]
    ) throws -> [TinkerbleSavedVersion]
    func deleteVersion(projectID: String, screen: String, versionID: UUID) throws -> [TinkerbleSavedVersion]
    func resetVersion(projectID: String, screen: String, versionID: UUID) throws
    func value(projectID: String, screen: String, versionID: UUID, tweakID: String) throws -> TinkerbleValue?
    func saveValue(projectID: String, screen: String, versionID: UUID, tweakID: String, value: TinkerbleValue) throws
}

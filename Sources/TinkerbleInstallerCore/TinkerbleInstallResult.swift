import Foundation

public struct TinkerbleInstallResult: Equatable, Sendable {
    public var projectPath: String
    public var targetNames: [String]
    public var changes: [String]
    public var isDryRun: Bool

    public init(projectPath: String, targetNames: [String], changes: [String], isDryRun: Bool) {
        self.projectPath = projectPath
        self.targetNames = targetNames
        self.changes = changes
        self.isDryRun = isDryRun
    }
}

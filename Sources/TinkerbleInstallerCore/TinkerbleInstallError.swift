import Foundation

public enum TinkerbleInstallError: Error, CustomStringConvertible, Equatable {
    case invalidArguments(String)
    case noProjectFound
    case multipleProjectsFound([String])
    case noTargetsFound
    case targetNotFound(String)
    case nonInteractiveSelectionRequired([String])
    case unsupportedWorkspace(String)
    case malformedProject(String)

    public var description: String {
        switch self {
        case .invalidArguments(let message):
            message
        case .noProjectFound:
            "No .xcodeproj was found in the current directory."
        case .multipleProjectsFound(let projects):
            "Multiple projects found. Pass --project with one of: \(projects.joined(separator: ", "))."
        case .noTargetsFound:
            "No app targets were found in the selected project."
        case .targetNotFound(let target):
            "Target not found: \(target)"
        case .nonInteractiveSelectionRequired(let targets):
            "Pass --target with one or more app targets: \(targets.joined(separator: ", "))."
        case .unsupportedWorkspace(let path):
            "Workspace install needs a project selection. Pass --project for a project inside \(path)."
        case .malformedProject(let message):
            "Malformed Xcode project: \(message)"
        }
    }
}

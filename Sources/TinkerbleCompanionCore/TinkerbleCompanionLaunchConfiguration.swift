import Foundation

public enum TinkerbleCompanionLaunchMode: Equatable, Sendable {
    case companion
    case allComponents
}

public struct TinkerbleCompanionLaunchConfiguration: Equatable, Sendable {
    public var mode: TinkerbleCompanionLaunchMode
    public var projectRoot: URL?
    public var projectID: String?

    public init(arguments: [String]) {
        mode = arguments.contains("--all-components") ? .allComponents : .companion
        projectRoot = Self.value(after: "--project-root", in: arguments).map {
            URL(filePath: $0, directoryHint: .isDirectory)
        }
        projectID = Self.value(after: "--project-id", in: arguments)
    }

    private static func value(after option: String, in arguments: [String]) -> String? {
        guard let optionIndex = arguments.firstIndex(of: option) else { return nil }
        let valueIndex = arguments.index(after: optionIndex)
        guard arguments.indices.contains(valueIndex) else { return nil }
        let value = arguments[valueIndex].trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty, !value.hasPrefix("--") else { return nil }
        return value
    }
}

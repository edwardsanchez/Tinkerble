import Foundation

public struct TinkerbleSourceAnchor: Codable, Equatable, Hashable, Sendable {
    public var filePath: String
    public var line: Int
    public var column: Int
    public var enclosingTypePath: [String]
    public var propertyName: String
    public var initializerExpression: String
    public var schemaVersion: Int

    public init(
        filePath: String,
        line: Int,
        column: Int,
        enclosingTypePath: [String],
        propertyName: String,
        initializerExpression: String,
        schemaVersion: Int = 1
    ) {
        self.filePath = filePath
        self.line = line
        self.column = column
        self.enclosingTypePath = enclosingTypePath
        self.propertyName = propertyName
        self.initializerExpression = initializerExpression
        self.schemaVersion = schemaVersion
    }

    public var stableID: String {
        let canonicalPath = URL(fileURLWithPath: filePath).standardizedFileURL.path
        return Self.lengthPrefixed(
            [canonicalPath] + enclosingTypePath + [propertyName]
        )
    }

    private static func lengthPrefixed(_ components: [String]) -> String {
        components
            .map { component in "\(component.utf8.count):\(component)" }
            .joined(separator: "|")
    }
}

public enum TinkerbleSourceValueType: Codable, Equatable, Hashable, Sendable {
    case string
    case bool
    case color
    case int
    case double
    case float
    case cgFloat
    case angle
    case date
    case enumeration(typeName: String)
}

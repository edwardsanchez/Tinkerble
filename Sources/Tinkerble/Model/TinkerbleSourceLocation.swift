import Foundation

/// A position in a source file, used to order controls by where they are declared.
///
/// Locations compare by file path, then line, then column.
public struct TinkerbleSourceLocation: Codable, Equatable, Hashable, Sendable {
    public var filePath: String
    public var line: Int
    public var column: Int

    public init(filePath: String, line: Int, column: Int) {
        self.filePath = filePath
        self.line = line
        self.column = column
    }
}

extension TinkerbleSourceLocation: Comparable {
    public static func < (left: Self, right: Self) -> Bool {
        (left.filePath, left.line, left.column) < (right.filePath, right.line, right.column)
    }
}

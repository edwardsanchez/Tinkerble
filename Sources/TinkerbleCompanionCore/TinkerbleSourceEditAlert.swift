import Foundation

public struct TinkerbleSourceEditAlert: Equatable, Identifiable, Sendable {
    public var id: UUID
    public var title: String
    public var message: String

    public init(id: UUID = UUID(), title: String, message: String) {
        self.id = id
        self.title = title
        self.message = message
    }
}

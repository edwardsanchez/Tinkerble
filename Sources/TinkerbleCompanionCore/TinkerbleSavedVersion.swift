import Foundation
public struct TinkerbleSavedVersion: Equatable, Hashable, Identifiable {
    public var id: UUID
    public var ordinal: Int

    public init(id: UUID, ordinal: Int) {
        self.id = id
        self.ordinal = ordinal
    }

    public var name: String {
        "Version \(ordinal)"
    }

    public var isProtected: Bool {
        ordinal == 1
    }
}

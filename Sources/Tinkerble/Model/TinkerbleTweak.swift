import Foundation

public struct TinkerbleEnumOption: Codable, Equatable, Hashable, Identifiable {
    public var id: String
    public var displayName: String

    public init(id: String, displayName: String) {
        self.id = id
        self.displayName = displayName
    }
}

public struct TinkerbleTweak: Codable, Equatable, Hashable, Identifiable {
    public var id: String
    public var category: String?
    public var name: String
    public var value: TinkerbleValue
    public var valueKind: TinkerbleValueKind
    public var control: TinkerbleControlDescriptor
    public var enumOptions: [TinkerbleEnumOption]

    public init(
        id: String,
        category: String?,
        name: String,
        value: TinkerbleValue,
        valueKind: TinkerbleValueKind,
        control: TinkerbleControlDescriptor,
        enumOptions: [TinkerbleEnumOption] = []
    ) {
        self.id = id
        self.category = category
        self.name = name
        self.value = value
        self.valueKind = valueKind
        self.control = control
        self.enumOptions = enumOptions
    }
}

public struct TinkerbleLogEntry: Codable, Equatable, Hashable, Identifiable {
    public var id: UUID
    public var message: String
    public var date: Date

    public init(id: UUID = UUID(), message: String, date: Date = Date()) {
        self.id = id
        self.message = message
        self.date = date
    }
}

public struct TinkerbleTweakGroup: Identifiable, Equatable {
    public var id: String { category ?? "__uncategorized" }
    public var category: String?
    public var tweaks: [TinkerbleTweak]

    public init(category: String?, tweaks: [TinkerbleTweak]) {
        self.category = category
        self.tweaks = tweaks
    }
}

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
    public static let defaultScreenName = "default"

    public var id: String
    public var screen: String
    public var category: String?
    public var name: String
    public var value: TinkerbleValue
    public var valueKind: TinkerbleValueKind
    public var control: TinkerbleControlDescriptor
    public var enumOptions: [TinkerbleEnumOption]

    public init(
        id: String,
        screen: String? = nil,
        category: String?,
        name: String,
        value: TinkerbleValue,
        valueKind: TinkerbleValueKind,
        control: TinkerbleControlDescriptor,
        enumOptions: [TinkerbleEnumOption] = []
    ) {
        self.id = id
        self.screen = Self.normalizedScreen(screen)
        self.category = category
        self.name = name
        self.value = value
        self.valueKind = valueKind
        self.control = control
        self.enumOptions = enumOptions
    }

    public static func normalizedScreen(_ screen: String?) -> String {
        guard let screen = screen?.trimmingCharacters(in: .whitespacesAndNewlines),
              !screen.isEmpty
        else {
            return defaultScreenName
        }
        return screen
    }

    public static func makeID(screen: String? = nil, category: String?, name: String) -> String {
        let normalizedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedScreen = normalizedScreen(screen)
        let categoryPrefix: String
        if let category = category?.trimmingCharacters(in: .whitespacesAndNewlines),
           !category.isEmpty {
            categoryPrefix = "\(category)/"
        } else {
            categoryPrefix = ""
        }

        if normalizedScreen == defaultScreenName {
            return "\(categoryPrefix)\(normalizedName)"
        }
        return "\(normalizedScreen)/\(categoryPrefix)\(normalizedName)"
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case screen
        case category
        case name
        case value
        case valueKind
        case control
        case enumOptions
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        screen = Self.normalizedScreen(try container.decodeIfPresent(String.self, forKey: .screen))
        category = try container.decodeIfPresent(String.self, forKey: .category)
        name = try container.decode(String.self, forKey: .name)
        value = try container.decode(TinkerbleValue.self, forKey: .value)
        valueKind = try container.decode(TinkerbleValueKind.self, forKey: .valueKind)
        control = try container.decode(TinkerbleControlDescriptor.self, forKey: .control)
        enumOptions = try container.decodeIfPresent([TinkerbleEnumOption].self, forKey: .enumOptions) ?? []
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

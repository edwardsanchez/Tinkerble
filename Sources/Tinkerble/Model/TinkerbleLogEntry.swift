import Foundation

public struct TinkerbleLogEntry: Codable, Equatable, Hashable, Identifiable {
    public static let defaultCategoryName = "Default"
    public static let defaultName = "Message"

    public var id: UUID
    public var screen: String
    public var category: String
    public var name: String
    public var value: TinkerbleLogValue
    public var decimalPlaces: Int
    public var date: Date

    public var valueID: String {
        Self.makeValueID(screen: screen, category: category, name: name)
    }

    public var displayValue: String {
        value.displayValue(decimalPlaces: decimalPlaces)
    }

    @available(*, deprecated, message: "Use displayValue instead.")
    public var message: String {
        displayValue
    }

    public init<Value: TinkerbleLogValueConvertible>(
        id: UUID = UUID(),
        screen: String? = nil,
        category: String? = nil,
        name: String,
        value: Value,
        decimalPlaces: Int = TinkerbleLogValue.defaultDecimalPlaces,
        date: Date = Date()
    ) {
        self.init(
            id: id,
            screen: screen,
            category: category,
            name: name,
            value: value.tinkerbleLogValue(decimalPlaces: decimalPlaces),
            decimalPlaces: decimalPlaces,
            date: date
        )
    }

    public init(
        id: UUID = UUID(),
        screen: String? = nil,
        category: String? = nil,
        name: String,
        value: TinkerbleLogValue,
        decimalPlaces: Int = TinkerbleLogValue.defaultDecimalPlaces,
        date: Date = Date()
    ) {
        self.id = id
        self.screen = TinkerbleTweak.normalizedScreen(screen)
        self.category = Self.normalizedCategory(category)
        self.name = Self.normalizedName(name)
        self.value = value
        self.decimalPlaces = Self.normalizedDecimalPlaces(decimalPlaces)
        self.date = date
    }

    @available(*, deprecated, message: "Use init(screen:category:name:value:date:) instead.")
    public init(id: UUID = UUID(), message: String, date: Date = Date()) {
        self.init(id: id, name: Self.defaultName, value: message, date: date)
    }

    public static func normalizedCategory(_ category: String?) -> String {
        guard let category = category?.trimmingCharacters(in: .whitespacesAndNewlines),
              !category.isEmpty
        else {
            return defaultCategoryName
        }
        return category
    }

    public static func normalizedName(_ name: String) -> String {
        let normalizedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return normalizedName.isEmpty ? defaultName : normalizedName
    }

    public static func normalizedDecimalPlaces(_ decimalPlaces: Int) -> Int {
        min(max(0, decimalPlaces), TinkerbleLogValue.maximumDecimalPlaces)
    }

    public static func makeValueID(screen: String? = nil, category: String? = nil, name: String) -> String {
        let screen = TinkerbleTweak.normalizedScreen(screen)
        let category = normalizedCategory(category)
        let name = normalizedName(name)
        return "\(screen)/\(category)/\(name)"
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case screen
        case category
        case name
        case value
        case decimalPlaces
        case date
        case message
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        date = try container.decodeIfPresent(Date.self, forKey: .date) ?? Date()

        if let value = try container.decodeIfPresent(TinkerbleLogValue.self, forKey: .value) {
            screen = TinkerbleTweak.normalizedScreen(try container.decodeIfPresent(String.self, forKey: .screen))
            category = Self.normalizedCategory(try container.decodeIfPresent(String.self, forKey: .category))
            name = Self.normalizedName(try container.decodeIfPresent(String.self, forKey: .name) ?? Self.defaultName)
            self.value = value
            decimalPlaces = Self.normalizedDecimalPlaces(
                try container.decodeIfPresent(Int.self, forKey: .decimalPlaces)
                    ?? TinkerbleLogValue.defaultDecimalPlaces
            )
        } else {
            screen = TinkerbleTweak.defaultScreenName
            category = Self.defaultCategoryName
            name = Self.defaultName
            value = .string(try container.decode(String.self, forKey: .message))
            decimalPlaces = TinkerbleLogValue.defaultDecimalPlaces
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(screen, forKey: .screen)
        try container.encode(category, forKey: .category)
        try container.encode(name, forKey: .name)
        try container.encode(value, forKey: .value)
        try container.encode(decimalPlaces, forKey: .decimalPlaces)
        try container.encode(date, forKey: .date)
    }
}

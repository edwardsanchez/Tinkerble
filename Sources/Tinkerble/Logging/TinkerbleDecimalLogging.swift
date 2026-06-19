extension Tinkerble {
    public func log<Value: TinkerbleLogValueConvertible>(
        _ name: String,
        value: Value,
        screen: String? = nil,
        category: String? = nil,
        decimalPlaces: Int
    ) {
#if DEBUG
        log(.init(
            screen: screen,
            category: category,
            name: name,
            value: value,
            decimalPlaces: decimalPlaces
        ))
#else
        _ = name
        _ = value
        _ = screen
        _ = category
        _ = decimalPlaces
#endif
    }

    @available(*, deprecated, message: "Use log(\"Name\", value: ..., screen: ..., category: ..., decimalPlaces: ...) instead.")
    public func log<Value: TinkerbleLogValueConvertible>(
        name: String,
        value: Value,
        screen: String? = nil,
        category: String? = nil,
        decimalPlaces: Int
    ) {
        log(name, value: value, screen: screen, category: category, decimalPlaces: decimalPlaces)
    }
}

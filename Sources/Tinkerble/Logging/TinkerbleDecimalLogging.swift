extension Tinkerble {
    public func log<Value: TinkerbleLogValueConvertible>(
        name: String,
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
}

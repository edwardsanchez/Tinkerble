import Foundation
import OSLog

public enum TinkerLog {
    private static let logger = Logger(subsystem: "Tinkerble", category: "TinkerLog")

    public static func value<Value: TinkerbleLogValueConvertible>(
        name: String,
        value: Value,
        screen: String? = nil,
        category: String? = nil
    ) {
        let entry = TinkerbleLogEntry(screen: screen, category: category, name: name, value: value)
        logger.debug("\(entry.name, privacy: .public): \(entry.value.displayValue, privacy: .public)")
#if DEBUG
        Task { @MainActor in
            Tinkerble.shared.log(entry)
        }
#endif
    }

    @available(*, deprecated, message: "Use value(name:value:screen:category:) for live log values.")
    public static func log(_ message: String) {
        logger.debug("\(message, privacy: .public)")
#if DEBUG
        Task { @MainActor in
            Tinkerble.shared.log(.init(name: TinkerbleLogEntry.defaultName, value: message))
        }
#endif
    }

    @available(*, deprecated, message: "Use value(name:value:screen:category:) for live log values.")
    public static func print(_ message: String) {
        log(message)
    }
}

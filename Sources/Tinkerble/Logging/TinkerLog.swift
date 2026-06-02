import Foundation
import OSLog

public enum TinkerLog {
    private static let logger = Logger(subsystem: "Tinkerble", category: "TinkerLog")

    public static func log(_ message: String) {
        logger.debug("\(message, privacy: .public)")
        Task { @MainActor in
            Tinkerble.shared.log(message)
        }
    }

    public static func print(_ message: String) {
        log(message)
    }
}

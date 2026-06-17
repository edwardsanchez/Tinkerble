import Foundation

public enum TinkerbleRole: String, Codable, Equatable, Hashable {
    case iOSApp
    case macCompanion
}

public enum TinkerbleConnectionStatus: Codable, Equatable, Hashable {
    case disconnected
    case connecting(String)
    case connected(String)
    case failed(String)
}

public struct TinkerbleProjectIdentity: Codable, Equatable, Hashable {
    public static let fallback = TinkerbleProjectIdentity(id: "default", displayName: "Default")

    public var id: String
    public var displayName: String

    public init(id: String, displayName: String) {
        let normalizedID = id.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedDisplayName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        self.id = normalizedID.isEmpty ? Self.fallback.id : normalizedID
        self.displayName = normalizedDisplayName.isEmpty ? self.id : normalizedDisplayName
    }

    public static var current: Self {
        let bundle = Bundle.main
        let bundleIdentifier = bundle.bundleIdentifier
        let displayName = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
        let bundleName = bundle.object(forInfoDictionaryKey: "CFBundleName") as? String
        let processName = ProcessInfo.processInfo.processName

        return TinkerbleProjectIdentity(
            id: bundleIdentifier ?? processName,
            displayName: displayName ?? bundleName ?? processName
        )
    }
}

public enum TinkerbleWireMessage: Codable, Equatable {
    case hello(role: TinkerbleRole, version: String, project: TinkerbleProjectIdentity? = nil)
    case snapshot([TinkerbleTweak])
    case register(TinkerbleTweak)
    case unregister(id: String)
    case update(id: String, value: TinkerbleValue)
    case trigger(id: String)
    case log(TinkerbleLogEntry)
}

public protocol TinkerbleClientTransport: AnyObject {
    var onMessage: ((TinkerbleWireMessage) -> Void)? { get set }
    var onStatusChange: ((TinkerbleConnectionStatus) -> Void)? { get set }

    func connect(host: String?, port: Int)
    func send(_ message: TinkerbleWireMessage)
    func disconnect()
}

public enum TinkerbleNetworkConfiguration {
    public static let defaultPort = 7777
    public static let bonjourServiceType = "_tinkerble._tcp"
}

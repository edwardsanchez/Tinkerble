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

public enum TinkerbleWireMessage: Codable, Equatable {
    case hello(role: TinkerbleRole, version: String)
    case snapshot([TinkerbleTweak])
    case register(TinkerbleTweak)
    case unregister(id: String)
    case update(id: String, value: TinkerbleValue)
    case log(TinkerbleLogEntry)
}

public protocol TinkerbleClientTransport: AnyObject {
    var onMessage: ((TinkerbleWireMessage) -> Void)? { get set }
    var onStatusChange: ((TinkerbleConnectionStatus) -> Void)? { get set }

    func connect(host: String, port: Int)
    func send(_ message: TinkerbleWireMessage)
    func disconnect()
}

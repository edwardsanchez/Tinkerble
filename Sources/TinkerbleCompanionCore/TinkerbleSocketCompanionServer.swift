import Foundation
import Network
import Tinkerble

protocol TinkerbleCompanionOutboundChannel: AnyObject {
    func send(_ message: TinkerbleWireMessage)
    func close()
}

final class TinkerbleSocketCompanionServer {
    private static let serviceName = "Tinkerble Companion"

    private let host: String
    private let port: Int
    private let serviceType: String
    private let queue = DispatchQueue(label: "Tinkerble.SocketCompanionServer")
    private let onMessage: (TinkerbleWireMessage, TinkerbleCompanionOutboundChannel?) -> Void
    private let onStatusChange: (TinkerbleConnectionStatus) -> Void
    private var listener: NWListener?
    private var activeConnection: TinkerbleSocketCompanionConnection?
    private var didFallbackToDynamicPort = false

    init(
        host: String,
        port: Int,
        serviceType: String,
        onMessage: @escaping (TinkerbleWireMessage, TinkerbleCompanionOutboundChannel?) -> Void,
        onStatusChange: @escaping (TinkerbleConnectionStatus) -> Void
    ) {
        self.host = host
        self.port = port
        self.serviceType = serviceType
        self.onMessage = onMessage
        self.onStatusChange = onStatusChange
    }

    func start() {
        onStatusChange(.connecting("\(host):\(port)"))

        queue.async { [weak self] in
            guard let self else { return }
            self.didFallbackToDynamicPort = false
            guard let rawPort = UInt16(exactly: self.port),
                  let nwPort = NWEndpoint.Port(rawValue: rawPort) else {
                self.onStatusChange(.failed("Invalid port: \(self.port)"))
                return
            }

            self.startListener(preferredPort: nwPort)
        }
    }

    func stop() {
        queue.async { [weak self] in
            self?.activeConnection?.close()
            self?.activeConnection = nil
            self?.listener?.stateUpdateHandler = nil
            self?.listener?.cancel()
            self?.listener = nil
            self?.onStatusChange(.disconnected)
        }
    }

    private func startListener(preferredPort: NWEndpoint.Port?) {
        do {
            let parameters = NWParameters.tcp
            parameters.allowLocalEndpointReuse = true

            let listener: NWListener
            if let preferredPort {
                listener = try NWListener(using: parameters, on: preferredPort)
            } else {
                listener = try NWListener(using: parameters)
            }
            listener.service = NWListener.Service(
                name: Self.serviceName,
                type: serviceType
            )
            listener.stateUpdateHandler = { [weak self] state in
                self?.handle(state)
            }
            listener.newConnectionHandler = { [weak self] connection in
                self?.accept(connection)
            }
            self.listener = listener
            listener.start(queue: queue)
        } catch let error as NWError
            where preferredPort != nil && !didFallbackToDynamicPort && error.isAddressAlreadyInUse {
            didFallbackToDynamicPort = true
            startListener(preferredPort: nil)
        } catch {
            onStatusChange(.failed(error.localizedDescription))
        }
    }

    private func handle(_ state: NWListener.State) {
        switch state {
        case .ready:
            let resolvedPort = listener?.port?.rawValue ?? UInt16(port)
            let portDescription = didFallbackToDynamicPort
                ? "\(resolvedPort) (7777 unavailable)"
                : "\(resolvedPort)"
            onStatusChange(.connected("Listening on \(host):\(portDescription)"))
        case let .failed(error):
            if !didFallbackToDynamicPort, error.isAddressAlreadyInUse {
                listener?.cancel()
                listener = nil
                didFallbackToDynamicPort = true
                startListener(preferredPort: nil)
                return
            }

            onStatusChange(.failed(error.localizedDescription))
        case .cancelled:
            onStatusChange(.disconnected)
        case .setup, .waiting:
            break
        @unknown default:
            break
        }
    }

    private func accept(_ connection: NWConnection) {
        activeConnection?.close()
        let companionConnection = TinkerbleSocketCompanionConnection(
            connection: connection,
            queue: queue,
            onMessage: onMessage,
            onStatusChange: onStatusChange
        )
        activeConnection = companionConnection
        companionConnection.start()
    }
}

private extension NWError {
    var isAddressAlreadyInUse: Bool {
        if case let .posix(error) = self {
            return error == .EADDRINUSE
        }
        return false
    }
}

private final class TinkerbleSocketCompanionConnection: TinkerbleCompanionOutboundChannel, @unchecked Sendable {
    private let connection: NWConnection
    private let queue: DispatchQueue
    private let codec = TinkerbleSocketMessageCodec()
    private let onMessage: (TinkerbleWireMessage, TinkerbleCompanionOutboundChannel?) -> Void
    private let onStatusChange: (TinkerbleConnectionStatus) -> Void
    private var receiveBuffer = Data()
    private var isReady = false

    init(
        connection: NWConnection,
        queue: DispatchQueue,
        onMessage: @escaping (TinkerbleWireMessage, TinkerbleCompanionOutboundChannel?) -> Void,
        onStatusChange: @escaping (TinkerbleConnectionStatus) -> Void
    ) {
        self.connection = connection
        self.queue = queue
        self.onMessage = onMessage
        self.onStatusChange = onStatusChange
    }

    func start() {
        connection.stateUpdateHandler = { [weak self] state in
            self?.handle(state)
        }
        connection.start(queue: queue)
    }

    func send(_ message: TinkerbleWireMessage) {
        queue.async { [weak self] in
            self?.sendOnQueue(message)
        }
    }

    func close() {
        isReady = false
        receiveBuffer.removeAll()
        connection.stateUpdateHandler = nil
        connection.cancel()
    }

    private func handle(_ state: NWConnection.State) {
        switch state {
        case .ready:
            isReady = true
            receiveNextChunk()
        case let .failed(error):
            close()
            onStatusChange(.failed(error.localizedDescription))
        case .cancelled:
            isReady = false
        case .setup, .waiting, .preparing:
            break
        @unknown default:
            break
        }
    }

    private func receiveNextChunk() {
        connection.receive(
            minimumIncompleteLength: 1,
            maximumLength: 64 * 1024
        ) { [weak self] data, _, isComplete, error in
            guard let self else { return }
            if let data, !data.isEmpty {
                self.receiveBuffer.append(data)
                self.decodeBufferedMessages()
            }

            if let error {
                self.close()
                self.onStatusChange(.failed(error.localizedDescription))
                return
            }

            if isComplete {
                self.close()
                return
            }

            self.receiveNextChunk()
        }
    }

    private func decodeBufferedMessages() {
        do {
            for message in try codec.messages(fromBufferedData: &receiveBuffer) {
                onMessage(message, self)
            }
        } catch {
            close()
            onStatusChange(.failed("Could not decode socket frame: \(error.localizedDescription)"))
        }
    }

    private func sendOnQueue(_ message: TinkerbleWireMessage) {
        guard isReady else { return }

        do {
            let frame = try codec.frame(for: message)
            connection.send(content: frame, completion: .contentProcessed { [weak self] error in
                if let error {
                    self?.onStatusChange(.failed(error.localizedDescription))
                }
            })
        } catch {
            onStatusChange(.failed("Could not encode socket frame: \(error.localizedDescription)"))
        }
    }
}

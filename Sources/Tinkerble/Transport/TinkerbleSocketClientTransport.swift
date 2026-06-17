import Foundation
import Network

public final class TinkerbleSocketClientTransport: TinkerbleClientTransport, @unchecked Sendable {
    public var onMessage: ((TinkerbleWireMessage) -> Void)?
    public var onStatusChange: ((TinkerbleConnectionStatus) -> Void)?

    private static let queueKey = DispatchSpecificKey<Void>()

    private let queue = DispatchQueue(label: "Tinkerble.SocketClientTransport")
    private let codec = TinkerbleSocketMessageCodec()
    private let projectIdentity: TinkerbleProjectIdentity
    private let serviceType: String
    private var browser: NWBrowser?
    private var connection: NWConnection?
    private var pendingMessages: [TinkerbleWireMessage] = []
    private var receiveBuffer = Data()
    private var isReady = false

    public init(
        projectIdentity: TinkerbleProjectIdentity = .current,
        serviceType: String = TinkerbleNetworkConfiguration.bonjourServiceType
    ) {
        self.projectIdentity = projectIdentity
        self.serviceType = serviceType
        queue.setSpecific(key: Self.queueKey, value: ())
    }

    public func connect(host: String? = nil, port: Int = TinkerbleNetworkConfiguration.defaultPort) {
        if let host {
            guard let rawPort = UInt16(exactly: port),
                  let nwPort = NWEndpoint.Port(rawValue: rawPort) else {
                onStatusChange?(.failed("Invalid port: \(port)"))
                return
            }

            let endpoint = NWEndpoint.hostPort(host: NWEndpoint.Host(host), port: nwPort)
            connect(to: endpoint, statusDescription: "\(host):\(port)")
            return
        }

        let serviceDescription = serviceType
        onStatusChange?(.connecting("Searching for \(serviceDescription)"))
        queue.async { [weak self] in
            guard let self else { return }
            self.disconnectOnQueue(publishStatus: false, clearPendingMessages: false)

            let browser = NWBrowser(
                for: .bonjour(type: self.serviceType, domain: nil),
                using: .tcp
            )
            self.browser = browser
            browser.stateUpdateHandler = { [weak self, weak browser] state in
                guard let self, self.browser === browser else { return }
                self.handleBrowserState(state, serviceDescription: serviceDescription)
            }
            browser.browseResultsChangedHandler = { [weak self, weak browser] results, _ in
                guard let self, self.browser === browser, let result = results.first else { return }
                self.browser?.cancel()
                self.browser = nil
                self.connectOnQueue(to: result.endpoint, statusDescription: result.endpoint.debugDescription)
            }
            browser.start(queue: self.queue)
        }
    }

    public func send(_ message: TinkerbleWireMessage) {
        queue.async { [weak self] in
            self?.sendOnQueue(message)
        }
    }

    public func disconnect() {
        queue.async { [weak self] in
            self?.disconnectOnQueue(publishStatus: true)
        }
    }

    deinit {
        if DispatchQueue.getSpecific(key: Self.queueKey) != nil {
            disconnectOnQueue(publishStatus: false)
        } else {
            queue.sync {
                disconnectOnQueue(publishStatus: false)
            }
        }
    }

    private func connect(to endpoint: NWEndpoint, statusDescription: String) {
        onStatusChange?(.connecting(statusDescription))
        queue.async { [weak self] in
            guard let self else { return }
            self.disconnectOnQueue(publishStatus: false, clearPendingMessages: false)
            self.connectOnQueue(to: endpoint, statusDescription: statusDescription)
        }
    }

    private func connectOnQueue(to endpoint: NWEndpoint, statusDescription: String) {
        let connection = NWConnection(to: endpoint, using: .tcp)
        self.connection = connection
        connection.stateUpdateHandler = { [weak self, weak connection] state in
            guard let self, self.connection === connection else { return }
            self.handleConnectionState(state, endpoint: statusDescription)
        }
        connection.start(queue: queue)
    }

    private func handleBrowserState(_ state: NWBrowser.State, serviceDescription: String) {
        switch state {
        case let .failed(error):
            disconnectOnQueue(publishStatus: false)
            publishStatus(.failed("Could not discover \(serviceDescription): \(error.localizedDescription)"))
        case let .waiting(error):
            publishStatus(.failed("Waiting to discover \(serviceDescription): \(error.localizedDescription)"))
        case .cancelled:
            break
        case .ready, .setup:
            break
        @unknown default:
            break
        }
    }

    private func handleConnectionState(_ state: NWConnection.State, endpoint: String) {
        switch state {
        case .ready:
            isReady = true
            receiveBuffer.removeAll()
            sendOnQueue(
                .hello(
                    role: .iOSApp,
                    version: "0.1.0",
                    project: projectIdentity
                )
            )
            flushPendingMessages()
            publishStatus(.connected(endpoint))
            receiveNextChunk()
        case let .failed(error):
            disconnectOnQueue(publishStatus: false)
            publishStatus(.failed(error.localizedDescription))
        case .cancelled:
            isReady = false
            publishStatus(.disconnected)
        case .setup, .waiting, .preparing:
            break
        @unknown default:
            break
        }
    }

    private func receiveNextChunk() {
        guard let connection else { return }

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
                self.disconnectOnQueue(publishStatus: false)
                self.publishStatus(.failed(error.localizedDescription))
                return
            }

            if isComplete {
                self.disconnectOnQueue(publishStatus: true)
                return
            }

            self.receiveNextChunk()
        }
    }

    private func decodeBufferedMessages() {
        do {
            for message in try codec.messages(fromBufferedData: &receiveBuffer) {
                Task { @MainActor [weak self] in
                    self?.onMessage?(message)
                }
            }
        } catch {
            disconnectOnQueue(publishStatus: false)
            publishStatus(.failed("Could not decode socket frame: \(error.localizedDescription)"))
        }
    }

    private func sendOnQueue(_ message: TinkerbleWireMessage) {
        guard isReady, let connection else {
            pendingMessages.append(message)
            return
        }

        do {
            let frame = try codec.frame(for: message)
            connection.send(content: frame, completion: .contentProcessed { [weak self] error in
                if let error {
                    self?.publishStatus(.failed(error.localizedDescription))
                }
            })
        } catch {
            publishStatus(.failed("Could not encode socket frame: \(error.localizedDescription)"))
        }
    }

    private func flushPendingMessages() {
        let messages = pendingMessages
        pendingMessages.removeAll()
        messages.forEach(sendOnQueue)
    }

    private func disconnectOnQueue(publishStatus shouldPublishStatus: Bool, clearPendingMessages: Bool = true) {
        isReady = false
        receiveBuffer.removeAll()
        if clearPendingMessages {
            pendingMessages.removeAll()
        }
        browser?.stateUpdateHandler = nil
        browser?.browseResultsChangedHandler = nil
        browser?.cancel()
        browser = nil
        connection?.stateUpdateHandler = nil
        connection?.cancel()
        connection = nil
        if shouldPublishStatus {
            publishStatus(.disconnected)
        }
    }

    private func publishStatus(_ status: TinkerbleConnectionStatus) {
        Task { @MainActor [weak self] in
            self?.onStatusChange?(status)
        }
    }
}

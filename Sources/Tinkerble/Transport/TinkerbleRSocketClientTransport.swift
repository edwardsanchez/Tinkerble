import Foundation
import RSocketCore
import RSocketTCPTransport
import RSocketTSChannel

public final class TinkerbleRSocketClientTransport: TinkerbleClientTransport {
    public var onMessage: ((TinkerbleWireMessage) -> Void)?
    public var onStatusChange: ((TinkerbleConnectionStatus) -> Void)?

    private let queue = DispatchQueue(label: "Tinkerble.RSocketClientTransport")
    private let codec = TinkerbleRSocketPayloadCodec()
    private var client: CoreClient?
    private var outboundStream: UnidirectionalStream?
    private var pendingMessages: [TinkerbleWireMessage] = []
    private var endpointDescription: String?
    private let projectIdentity: TinkerbleProjectIdentity

    public init(projectIdentity: TinkerbleProjectIdentity = .current) {
        self.projectIdentity = projectIdentity
    }

    public func connect(host: String = "127.0.0.1", port: Int = 7777) {
        let endpoint = "\(host):\(port)"
        endpointDescription = endpoint
        onStatusChange?(.connecting(endpoint))

        queue.async { [weak self] in
            guard let self else { return }
            do {
                let bootstrap = RSocketTSChannel.ClientBootstrap(
                    transport: TCPTransport(),
                    config: .mobileToServer
                )
                let hello = TinkerbleWireMessage.hello(
                    role: .iOSApp,
                    version: "0.1.0",
                    project: self.projectIdentity
                )
                let setupPayload = try self.codec.payload(for: hello)
                let client = try bootstrap
                    .connect(to: .init(host: host, port: port), payload: setupPayload, responder: nil)
                    .wait()

                let inbound = TinkerbleRSocketInboundStream(
                    onPayload: { [weak self] payload in
                        self?.receive(payload)
                    },
                    onFailure: { [weak self] message in
                        self?.publishStatus(.failed(message))
                    }
                )
                let outbound = client.requester.channel(
                    payload: setupPayload,
                    initialRequestN: Int32.max,
                    isCompleted: false,
                    responderStream: inbound
                )

                self.client = client
                self.outboundStream = outbound
                self.flushPendingMessages()
                self.publishStatus(.connected(endpoint))
            } catch {
                self.publishStatus(.failed(error.localizedDescription))
            }
        }
    }

    public func send(_ message: TinkerbleWireMessage) {
        queue.async { [weak self] in
            self?.sendOnQueue(message)
        }
    }

    public func disconnect() {
        queue.async { [weak self] in
            guard let self else { return }
            self.outboundStream?.onComplete()
            self.outboundStream = nil
            if let client = self.client {
                try? client.shutdown().wait()
            }
            self.client = nil
            self.pendingMessages.removeAll()
            self.publishStatus(.disconnected)
        }
    }

    deinit {
        disconnect()
    }

    private func receive(_ payload: Payload) {
        do {
            let message = try codec.message(from: payload)
            Task { @MainActor [weak self] in
                self?.onMessage?(message)
            }
        } catch {
            publishStatus(.failed("Could not decode RSocket payload: \(error.localizedDescription)"))
        }
    }

    private func sendOnQueue(_ message: TinkerbleWireMessage) {
        guard let outboundStream else {
            pendingMessages.append(message)
            return
        }

        do {
            let payload = try codec.payload(for: message)
            outboundStream.onNext(payload, isCompletion: false)
        } catch {
            publishStatus(.failed("Could not encode RSocket payload: \(error.localizedDescription)"))
        }
    }

    private func flushPendingMessages() {
        let messages = pendingMessages
        pendingMessages.removeAll()
        messages.forEach(sendOnQueue)
    }

    private func publishStatus(_ status: TinkerbleConnectionStatus) {
        Task { @MainActor [weak self] in
            self?.onStatusChange?(status)
        }
    }
}

import Foundation
@preconcurrency import NIOCore
@preconcurrency import NIOExtras
@preconcurrency import NIOPosix
import RSocketCore
import Tinkerble

final class TinkerbleRSocketCompanionServer {
    private let host: String
    private let port: Int
    private let codec = TinkerbleRSocketPayloadCodec()
    private let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
    private let onMessage: (TinkerbleWireMessage, UnidirectionalStream?) -> Void
    private let onStatusChange: (TinkerbleConnectionStatus) -> Void
    private var channel: Channel?

    init(
        host: String,
        port: Int,
        onMessage: @escaping (TinkerbleWireMessage, UnidirectionalStream?) -> Void,
        onStatusChange: @escaping (TinkerbleConnectionStatus) -> Void
    ) {
        self.host = host
        self.port = port
        self.onMessage = onMessage
        self.onStatusChange = onStatusChange
    }

    func start() {
        onStatusChange(.connecting("\(host):\(port)"))

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            do {
                let bootstrap = ServerBootstrap(group: self.group)
                    .serverChannelOption(ChannelOptions.backlog, value: 256)
                    .serverChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
                    .childChannelInitializer { [weak self] channel in
                        guard let self else {
                            return channel.eventLoop.makeSucceededFuture(())
                        }

                        do {
                            try channel.pipeline.syncOperations.addHandler(
                                ByteToMessageHandler(
                                    LengthFieldBasedFrameDecoder(lengthFieldBitLength: .threeBytes),
                                    maximumBufferSize: 1 << 20
                                )
                            )
                            try channel.pipeline.syncOperations.addHandler(
                                LengthFieldPrepender(lengthFieldBitLength: .threeBytes)
                            )
                        } catch {
                            return channel.eventLoop.makeFailedFuture(error)
                        }

                        return channel.pipeline.addRSocketServerHandlers(
                            makeResponder: { [weak self] setupInfo in
                                guard let self else { return nil }
                                self.receive(setupInfo.payload, outbound: nil)
                                return TinkerbleCompanionResponder(
                                    encoding: setupInfo.encoding,
                                    onPayload: { [weak self] payload, outbound in
                                        self?.receive(payload, outbound: outbound)
                                    }
                                )
                            }
                        )
                    }

                self.channel = try bootstrap.bind(host: self.host, port: self.port).wait()
                self.onStatusChange(.connected("Listening on \(self.host):\(self.port)"))
            } catch {
                self.onStatusChange(.failed(error.localizedDescription))
            }
        }
    }

    func stop() {
        try? channel?.close().wait()
        channel = nil
        try? group.syncShutdownGracefully()
        onStatusChange(.disconnected)
    }

    private func receive(_ payload: Payload, outbound: UnidirectionalStream?) {
        do {
            onMessage(try codec.message(from: payload), outbound)
        } catch {
            onStatusChange(.failed("Could not decode RSocket payload: \(error.localizedDescription)"))
        }
    }
}

private final class TinkerbleCompanionResponder: RSocket {
    let encoding: ConnectionEncoding
    private let onPayload: (Payload, UnidirectionalStream?) -> Void

    init(encoding: ConnectionEncoding, onPayload: @escaping (Payload, UnidirectionalStream?) -> Void) {
        self.encoding = encoding
        self.onPayload = onPayload
    }

    func metadataPush(metadata: ByteBuffer) {}

    func fireAndForget(payload: Payload) {
        onPayload(payload, nil)
    }

    func requestResponse(payload: Payload, responderStream: UnidirectionalStream) -> Cancellable {
        onPayload(payload, responderStream)
        responderStream.onComplete()
        return TinkerbleNoOpStream()
    }

    func stream(payload: Payload, initialRequestN: Int32, responderStream: UnidirectionalStream) -> Subscription {
        onPayload(payload, responderStream)
        return TinkerbleNoOpStream()
    }

    func channel(
        payload: Payload,
        initialRequestN: Int32,
        isCompleted: Bool,
        responderStream: UnidirectionalStream
    ) -> UnidirectionalStream {
        onPayload(payload, responderStream)
        return TinkerbleRSocketInboundStream(
            onPayload: { [weak self] payload in
                self?.onPayload(payload, responderStream)
            }
        )
    }
}

private final class TinkerbleNoOpStream: UnidirectionalStream {
    func onNext(_ payload: Payload, isCompletion: Bool) {}
    func onComplete() {}
    func onRequestN(_ requestN: Int32) {}
    func onCancel() {}
    func onError(_ error: RSocketCore.Error) {}
    func onExtension(extendedType: Int32, payload: Payload, canBeIgnored: Bool) {}
}

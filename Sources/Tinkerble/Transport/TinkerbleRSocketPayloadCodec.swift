import Foundation
import NIOCore
import RSocketCore

public struct TinkerbleRSocketPayloadCodec {
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init() {
        encoder = JSONEncoder()
        decoder = JSONDecoder()
    }

    public func payload(for message: TinkerbleWireMessage) throws -> Payload {
        let data = try encoder.encode(message)
        var buffer = ByteBufferAllocator().buffer(capacity: data.count)
        buffer.writeBytes(data)
        return Payload(data: buffer)
    }

    public func message(from payload: Payload) throws -> TinkerbleWireMessage {
        var buffer = payload.data
        let bytes = buffer.readBytes(length: buffer.readableBytes) ?? []
        return try decoder.decode(TinkerbleWireMessage.self, from: Data(bytes))
    }
}

public final class TinkerbleRSocketInboundStream: UnidirectionalStream {
    private let onPayload: (Payload) -> Void
    private let onFailure: ((String) -> Void)?

    public init(onPayload: @escaping (Payload) -> Void, onFailure: ((String) -> Void)? = nil) {
        self.onPayload = onPayload
        self.onFailure = onFailure
    }

    public func onNext(_ payload: Payload, isCompletion: Bool) {
        onPayload(payload)
    }

    public func onComplete() {}

    public func onRequestN(_ requestN: Int32) {}

    public func onCancel() {}

    public func onError(_ error: RSocketCore.Error) {
        onFailure?(String(describing: error))
    }

    public func onExtension(extendedType: Int32, payload: Payload, canBeIgnored: Bool) {}
}

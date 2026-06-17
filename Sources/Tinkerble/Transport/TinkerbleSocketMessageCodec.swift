import Foundation

public struct TinkerbleSocketMessageCodec {
    public static let maximumPayloadSize = 1 << 20

    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init() {
        encoder = JSONEncoder()
        decoder = JSONDecoder()
    }

    public func data(for message: TinkerbleWireMessage) throws -> Data {
        try encoder.encode(message)
    }

    public func message(from data: Data) throws -> TinkerbleWireMessage {
        try decoder.decode(TinkerbleWireMessage.self, from: data)
    }

    public func frame(for message: TinkerbleWireMessage) throws -> Data {
        let payload = try data(for: message)
        guard payload.count <= Self.maximumPayloadSize else {
            throw TinkerbleSocketMessageCodecError.payloadTooLarge(payload.count)
        }

        var length = UInt32(payload.count).bigEndian
        var frame = Data()
        withUnsafeBytes(of: &length) { bytes in
            frame.append(contentsOf: bytes)
        }
        frame.append(payload)
        return frame
    }

    public func messages(fromBufferedData buffer: inout Data) throws -> [TinkerbleWireMessage] {
        var messages: [TinkerbleWireMessage] = []

        while buffer.count >= 4 {
            let payloadLength = buffer.prefix(4).reduce(UInt32(0)) { partial, byte in
                (partial << 8) | UInt32(byte)
            }
            guard payloadLength <= Self.maximumPayloadSize else {
                throw TinkerbleSocketMessageCodecError.payloadTooLarge(Int(payloadLength))
            }

            let frameLength = 4 + Int(payloadLength)
            guard buffer.count >= frameLength else {
                break
            }

            let payload = buffer.subdata(in: 4..<frameLength)
            buffer.removeSubrange(0..<frameLength)
            messages.append(try message(from: payload))
        }

        return messages
    }
}

public enum TinkerbleSocketMessageCodecError: Error, Equatable {
    case payloadTooLarge(Int)
}

import CryptoKit
import Foundation

enum TinkerbleSourceHash {
    private static let hexadecimalDigits = Array("0123456789abcdef".utf8)

    static func sha256(_ data: Data) -> String {
        let digest = SHA256.hash(data: data)
        var result = [UInt8]()
        result.reserveCapacity(SHA256.byteCount * 2)
        for byte in digest {
            result.append(hexadecimalDigits[Int(byte >> 4)])
            result.append(hexadecimalDigits[Int(byte & 0x0F)])
        }
        return String(decoding: result, as: UTF8.self)
    }
}

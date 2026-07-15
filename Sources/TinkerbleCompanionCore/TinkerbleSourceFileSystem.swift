import Foundation

struct TinkerbleSourceFileInformation: Sendable {
    var exists: Bool
    var isRegularFile: Bool
    var isWritable: Bool
}

protocol TinkerbleSourceFileSystem: Sendable {
    func canonicalURL(_ url: URL) -> URL
    func information(at url: URL) -> TinkerbleSourceFileInformation
    func data(at url: URL) throws -> Data
    func stage(_ data: Data, beside originalURL: URL) throws -> URL
    func replaceItem(at originalURL: URL, with stagedURL: URL) throws
    func removeItemIfPresent(at url: URL)
}

struct TinkerbleLocalSourceFileSystem: TinkerbleSourceFileSystem {
    func canonicalURL(_ url: URL) -> URL {
        url.standardizedFileURL.resolvingSymlinksInPath()
    }

    func information(at url: URL) -> TinkerbleSourceFileInformation {
        let fileManager = FileManager.default
        var isDirectory: ObjCBool = false
        let exists = fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory)
        guard exists else {
            return .init(exists: false, isRegularFile: false, isWritable: false)
        }
        let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .isWritableKey])
        return .init(
            exists: true,
            isRegularFile: values?.isRegularFile == true && !isDirectory.boolValue,
            isWritable: values?.isWritable == true
        )
    }

    func data(at url: URL) throws -> Data {
        try Data(contentsOf: url, options: .mappedIfSafe)
    }

    func stage(_ data: Data, beside originalURL: URL) throws -> URL {
        let stageURL = originalURL.deletingLastPathComponent().appending(
            path: ".\(originalURL.lastPathComponent).tinkerble-\(UUID().uuidString).tmp"
        )
        try data.write(to: stageURL, options: .withoutOverwriting)
        return stageURL
    }

    func replaceItem(at originalURL: URL, with stagedURL: URL) throws {
        _ = try FileManager.default.replaceItemAt(originalURL, withItemAt: stagedURL)
    }

    func removeItemIfPresent(at url: URL) {
        try? FileManager.default.removeItem(at: url)
    }
}

import Foundation

public actor TinkerbleJSONAppliedDefaultRepository: TinkerbleAppliedDefaultRepository {
    public static var defaultFileURL: URL {
        URL.applicationSupportDirectory
            .appending(path: "Tinkerble", directoryHint: .isDirectory)
            .appending(path: "AppliedDefaults.json")
    }

    private let fileURL: URL
    private var recordsByKey: [TinkerbleAppliedDefaultKey: TinkerbleAppliedDefaultRecord]?

    public init(fileURL: URL? = nil) {
        self.fileURL = fileURL ?? Self.defaultFileURL
    }

    public func record(for key: TinkerbleAppliedDefaultKey) throws -> TinkerbleAppliedDefaultRecord? {
        try loadIfNeeded()[key]
    }

    public func records(projectID: String, canonicalProjectRoot: String) throws -> [TinkerbleAppliedDefaultRecord] {
        let root = URL(fileURLWithPath: canonicalProjectRoot).standardizedFileURL.path
        return try loadIfNeeded().values
            .filter { $0.key.projectID == projectID && $0.key.canonicalProjectRoot == root }
            .sorted { $0.key.anchorStableID < $1.key.anchorStableID }
    }

    public func update(
        _ records: [TinkerbleAppliedDefaultRecord],
        removing keys: [TinkerbleAppliedDefaultKey]
    ) throws {
        var updatedRecords = try loadIfNeeded()
        for key in keys {
            updatedRecords.removeValue(forKey: key)
        }
        for record in records {
            updatedRecords[record.key] = record
        }
        try persist(updatedRecords)
        recordsByKey = updatedRecords
    }

    private func loadIfNeeded() throws -> [TinkerbleAppliedDefaultKey: TinkerbleAppliedDefaultRecord] {
        if let recordsByKey {
            return recordsByKey
        }
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            let empty: [TinkerbleAppliedDefaultKey: TinkerbleAppliedDefaultRecord] = [:]
            recordsByKey = empty
            return empty
        }
        let data = try Data(contentsOf: fileURL)
        let document = try JSONDecoder().decode(TinkerbleAppliedDefaultDocument.self, from: data)
        let loaded = Dictionary(uniqueKeysWithValues: document.records.map { ($0.key, $0) })
        recordsByKey = loaded
        return loaded
    }

    private func persist(_ records: [TinkerbleAppliedDefaultKey: TinkerbleAppliedDefaultRecord]) throws {
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let document = TinkerbleAppliedDefaultDocument(
            schemaVersion: 1,
            records: records.values.sorted { $0.key.anchorStableID < $1.key.anchorStableID }
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(document)
        try data.write(to: fileURL, options: .atomic)
    }
}

private struct TinkerbleAppliedDefaultDocument: Codable {
    var schemaVersion: Int
    var records: [TinkerbleAppliedDefaultRecord]
}

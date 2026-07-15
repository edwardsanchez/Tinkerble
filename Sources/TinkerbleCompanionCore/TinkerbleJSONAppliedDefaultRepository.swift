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
        let loaded: [TinkerbleAppliedDefaultKey: TinkerbleAppliedDefaultRecord]
        do {
            let document = try JSONDecoder().decode(TinkerbleAppliedDefaultDocument.self, from: data)
            guard document.schemaVersion == TinkerbleAppliedDefaultDocument.currentSchemaVersion else {
                throw TinkerbleAppliedDefaultDocumentError.unsupportedSchema
            }
            var records: [TinkerbleAppliedDefaultKey: TinkerbleAppliedDefaultRecord] = [:]
            for record in document.records {
                guard records.updateValue(record, forKey: record.key) == nil else {
                    throw TinkerbleAppliedDefaultDocumentError.duplicateRecord
                }
            }
            loaded = records
        } catch is DecodingError {
            return recoverFromInvalidDocument()
        } catch is TinkerbleAppliedDefaultDocumentError {
            return recoverFromInvalidDocument()
        }
        recordsByKey = loaded
        return loaded
    }

    private func recoverFromInvalidDocument() -> [TinkerbleAppliedDefaultKey: TinkerbleAppliedDefaultRecord] {
        let backupURL = fileURL.deletingLastPathComponent().appending(
            path: "\(fileURL.lastPathComponent).corrupt-\(UUID().uuidString)"
        )
        try? FileManager.default.moveItem(at: fileURL, to: backupURL)
        let empty: [TinkerbleAppliedDefaultKey: TinkerbleAppliedDefaultRecord] = [:]
        recordsByKey = empty
        return empty
    }

    private func persist(_ records: [TinkerbleAppliedDefaultKey: TinkerbleAppliedDefaultRecord]) throws {
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let document = TinkerbleAppliedDefaultDocument(
            schemaVersion: TinkerbleAppliedDefaultDocument.currentSchemaVersion,
            records: records.values.sorted { $0.key.anchorStableID < $1.key.anchorStableID }
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(document)
        try data.write(to: fileURL, options: .atomic)
    }
}

private struct TinkerbleAppliedDefaultDocument: Codable {
    static let currentSchemaVersion = 1

    var schemaVersion: Int
    var records: [TinkerbleAppliedDefaultRecord]
}

private enum TinkerbleAppliedDefaultDocumentError: Error {
    case unsupportedSchema
    case duplicateRecord
}

import Foundation

public actor TinkerbleInMemoryAppliedDefaultRepository: TinkerbleAppliedDefaultRepository {
    private var recordsByKey: [TinkerbleAppliedDefaultKey: TinkerbleAppliedDefaultRecord]

    public init(records: [TinkerbleAppliedDefaultRecord] = []) {
        recordsByKey = Dictionary(uniqueKeysWithValues: records.map { ($0.key, $0) })
    }

    public func record(for key: TinkerbleAppliedDefaultKey) -> TinkerbleAppliedDefaultRecord? {
        recordsByKey[key]
    }

    public func records(projectID: String, canonicalProjectRoot: String) -> [TinkerbleAppliedDefaultRecord] {
        let root = URL(fileURLWithPath: canonicalProjectRoot).standardizedFileURL.path
        return recordsByKey.values
            .filter { $0.key.projectID == projectID && $0.key.canonicalProjectRoot == root }
            .sorted { $0.key.anchorStableID < $1.key.anchorStableID }
    }

    public func update(
        _ records: [TinkerbleAppliedDefaultRecord],
        removing keys: [TinkerbleAppliedDefaultKey]
    ) {
        for key in keys {
            recordsByKey.removeValue(forKey: key)
        }
        for record in records {
            recordsByKey[record.key] = record
        }
    }
}

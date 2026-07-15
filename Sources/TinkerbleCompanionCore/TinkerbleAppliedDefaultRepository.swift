import Foundation
import Tinkerble

public struct TinkerbleAppliedDefaultKey: Codable, Equatable, Hashable, Sendable {
    public var projectID: String
    public var canonicalProjectRoot: String
    public var anchorStableID: String

    public init(projectID: String, canonicalProjectRoot: String, anchorStableID: String) {
        self.projectID = projectID
        self.canonicalProjectRoot = URL(fileURLWithPath: canonicalProjectRoot).standardizedFileURL.path
        self.anchorStableID = anchorStableID
    }

    public init(projectID: String, projectRoot: URL, anchor: TinkerbleSourceAnchor) {
        self.init(
            projectID: projectID,
            canonicalProjectRoot: projectRoot.standardizedFileURL.resolvingSymlinksInPath().path,
            anchorStableID: anchor.stableID
        )
    }
}

public struct TinkerbleAppliedDefaultRecord: Codable, Equatable, Hashable, Sendable {
    public var key: TinkerbleAppliedDefaultKey
    public var anchor: TinkerbleSourceAnchor
    public var value: TinkerbleValue
    public var compiledInitializerExpression: String
    public var writtenInitializerExpression: String

    public init(
        key: TinkerbleAppliedDefaultKey,
        anchor: TinkerbleSourceAnchor,
        value: TinkerbleValue,
        compiledInitializerExpression: String,
        writtenInitializerExpression: String
    ) {
        self.key = key
        self.anchor = anchor
        self.value = value
        self.compiledInitializerExpression = compiledInitializerExpression
        self.writtenInitializerExpression = writtenInitializerExpression
    }

    public init(
        projectID: String,
        projectRoot: URL,
        edit: TinkerbleAppliedSourceEdit,
        value: TinkerbleValue
    ) {
        self.init(
            key: .init(projectID: projectID, projectRoot: projectRoot, anchor: edit.anchor),
            anchor: edit.anchor,
            value: value,
            compiledInitializerExpression: edit.anchor.initializerExpression,
            writtenInitializerExpression: edit.writtenExpression
        )
    }
}

public struct TinkerbleAppliedDefaultResolution: Equatable, Sendable {
    public var effectiveValue: TinkerbleValue
    public var acceptedInitializerExpressions: [String]
    public var record: TinkerbleAppliedDefaultRecord?

    public init(
        effectiveValue: TinkerbleValue,
        acceptedInitializerExpressions: [String] = [],
        record: TinkerbleAppliedDefaultRecord? = nil
    ) {
        self.effectiveValue = effectiveValue
        self.acceptedInitializerExpressions = acceptedInitializerExpressions
        self.record = record
    }
}

public protocol TinkerbleAppliedDefaultRepository: Sendable {
    func record(for key: TinkerbleAppliedDefaultKey) async throws -> TinkerbleAppliedDefaultRecord?
    func records(projectID: String, canonicalProjectRoot: String) async throws -> [TinkerbleAppliedDefaultRecord]
    func update(
        _ records: [TinkerbleAppliedDefaultRecord],
        removing keys: [TinkerbleAppliedDefaultKey]
    ) async throws
}

public extension TinkerbleAppliedDefaultRepository {
    func update(_ records: [TinkerbleAppliedDefaultRecord]) async throws {
        try await update(records, removing: [])
    }

    func remove(_ keys: [TinkerbleAppliedDefaultKey]) async throws {
        try await update([], removing: keys)
    }

    func reconcile(
        projectID: String,
        projectRoot: URL,
        tweaks: [TinkerbleTweak]
    ) async throws -> [String: TinkerbleAppliedDefaultResolution] {
        let root = projectRoot.standardizedFileURL.resolvingSymlinksInPath().path
        let existingRecords = try await records(projectID: projectID, canonicalProjectRoot: root)
        let recordsByKey = Dictionary(uniqueKeysWithValues: existingRecords.map { ($0.key, $0) })
        var resolutions: [String: TinkerbleAppliedDefaultResolution] = [:]
        var staleKeys: [TinkerbleAppliedDefaultKey] = []

        for tweak in tweaks {
            let uniqueAnchors = Dictionary(grouping: tweak.sourceAnchors, by: \.stableID).values.compactMap(\.first)
            guard uniqueAnchors.count == 1, let anchor = uniqueAnchors.first else {
                resolutions[tweak.id] = .init(effectiveValue: tweak.codeDefaultValue)
                continue
            }
            let key = TinkerbleAppliedDefaultKey(projectID: projectID, projectRoot: projectRoot, anchor: anchor)
            guard let record = recordsByKey[key] else {
                resolutions[tweak.id] = .init(effectiveValue: tweak.codeDefaultValue)
                continue
            }

            if anchor.initializerExpression == record.compiledInitializerExpression {
                resolutions[tweak.id] = .init(
                    effectiveValue: record.value,
                    acceptedInitializerExpressions: [record.writtenInitializerExpression],
                    record: record
                )
            } else if anchor.initializerExpression == record.writtenInitializerExpression {
                resolutions[tweak.id] = .init(effectiveValue: tweak.codeDefaultValue)
                staleKeys.append(key)
            } else {
                resolutions[tweak.id] = .init(effectiveValue: tweak.codeDefaultValue)
                staleKeys.append(key)
            }
        }

        if !staleKeys.isEmpty {
            try await remove(staleKeys)
        }
        return resolutions
    }
}

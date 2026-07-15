import Foundation
import Tinkerble

public struct TinkerbleSourceApplyRequest: Sendable {
    public var projectID: String
    public var projectRoot: URL
    public var tweak: TinkerbleTweak
    public var acceptedInitializerExpressions: [String]

    public init(
        projectID: String,
        projectRoot: URL,
        tweak: TinkerbleTweak,
        acceptedInitializerExpressions: [String] = []
    ) {
        self.projectID = projectID
        self.projectRoot = projectRoot
        self.tweak = tweak
        self.acceptedInitializerExpressions = acceptedInitializerExpressions
    }
}

public struct TinkerbleAppliedSourceEdit: Equatable, Sendable {
    public var tweakID: String
    public var anchor: TinkerbleSourceAnchor
    public var previousExpression: String
    public var writtenExpression: String
    public var originalFileHash: String
    public var writtenFileHash: String

    public init(
        tweakID: String,
        anchor: TinkerbleSourceAnchor,
        previousExpression: String,
        writtenExpression: String,
        originalFileHash: String,
        writtenFileHash: String
    ) {
        self.tweakID = tweakID
        self.anchor = anchor
        self.previousExpression = previousExpression
        self.writtenExpression = writtenExpression
        self.originalFileHash = originalFileHash
        self.writtenFileHash = writtenFileHash
    }
}

public struct TinkerbleSourceApplyResult: Equatable, Sendable {
    public var edits: [TinkerbleAppliedSourceEdit]

    public init(edits: [TinkerbleAppliedSourceEdit]) {
        self.edits = edits
    }
}

public protocol TinkerbleSourceEditing: Sendable {
    func apply(_ requests: [TinkerbleSourceApplyRequest]) async throws -> TinkerbleSourceApplyResult
}

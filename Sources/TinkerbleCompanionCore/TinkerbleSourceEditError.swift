import Foundation
import Tinkerble

public struct TinkerbleSourceEditIssue: LocalizedError, Identifiable, Equatable, Sendable {
    public enum Reason: Equatable, Sendable {
        case missingSourceMetadata
        case ambiguousSourceAnchors([String])
        case sourceOutsideProject(String)
        case fileMissing(String)
        case fileIsNotRegular(String)
        case fileIsNotWritable(String)
        case unreadableFile(String)
        case invalidUTF8(String)
        case parseFailure(String)
        case declarationMissing(String)
        case declarationMoved(String)
        case declarationAmbiguous(String)
        case initializerMissing(String)
        case staleInitializer(expected: [String], actual: String)
        case unsupportedValue(String)
        case concurrentModification(String)
        case stagingFailure(String)
        case writeFailure(String)
        case verificationFailure(String)
        case rollbackFailure(String)
    }

    public var tweakID: String
    public var tweakName: String
    public var screen: String
    public var category: String?
    public var reason: Reason

    public init(tweak: TinkerbleTweak, reason: Reason) {
        tweakID = tweak.id
        tweakName = tweak.name
        screen = tweak.screen
        category = tweak.category
        self.reason = reason
    }

    public var id: String {
        "\(tweakID)|\(errorDescription ?? String(describing: reason))"
    }

    public var errorDescription: String? {
        switch reason {
        case .missingSourceMetadata:
            "Tinkerble did not receive source information for this value. Rebuild the app and try again."
        case let .ambiguousSourceAnchors(paths):
            "This value is registered by more than one source declaration: \(paths.joined(separator: ", "))."
        case let .sourceOutsideProject(path):
            "The source file is outside the active project: \(path)."
        case let .fileMissing(path):
            "The source file no longer exists at \(path). It may have moved or been renamed. Rebuild and try again."
        case let .fileIsNotRegular(path):
            "The source location is not a regular file: \(path)."
        case let .fileIsNotWritable(path):
            "The source file is not writable: \(path)."
        case let .unreadableFile(path):
            "The source file could not be read: \(path)."
        case let .invalidUTF8(path):
            "The source file is not valid UTF-8: \(path)."
        case let .parseFailure(path):
            "The source file contains syntax that could not be parsed safely: \(path)."
        case let .declarationMissing(path):
            "The original property declaration could not be found in \(path). Rebuild and try again."
        case let .declarationMoved(path):
            "The original property declaration moved within \(path) after the app was built. Rebuild and try again."
        case let .declarationAmbiguous(path):
            "More than one matching property declaration was found in \(path)."
        case let .initializerMissing(path):
            "The property in \(path) does not have an inline default value that Tinkerble can edit."
        case .staleInitializer:
            "The property's default has changed since the app was built. Rebuild and try again."
        case let .unsupportedValue(message):
            message
        case let .concurrentModification(path):
            "The source file changed while Tinkerble was applying values: \(path). Try again."
        case let .stagingFailure(path):
            "Tinkerble could not stage the source edit for \(path)."
        case let .writeFailure(path):
            "Tinkerble could not replace the source file at \(path)."
        case let .verificationFailure(path):
            "The source file at \(path) did not match the verified edit after it was written."
        case let .rollbackFailure(path):
            "Tinkerble could not completely restore \(path) after another edit failed."
        }
    }
}

public struct TinkerbleSourceApplyError: LocalizedError, Equatable, Sendable {
    public var issues: [TinkerbleSourceEditIssue]
    public var changedFilePaths: [String]

    public init(issues: [TinkerbleSourceEditIssue], changedFilePaths: [String] = []) {
        self.issues = issues
        self.changedFilePaths = changedFilePaths
    }

    public var noFilesChanged: Bool {
        changedFilePaths.isEmpty
    }

    public var errorDescription: String? {
        guard let firstIssue = issues.first else {
            return "Tinkerble could not apply values to code."
        }
        if issues.count == 1 {
            return firstIssue.errorDescription
        }
        return "Tinkerble could not apply \(issues.count) values to code."
    }
}

import Foundation
import SwiftParser
import Tinkerble

public actor TinkerbleSourceEditingService: TinkerbleSourceEditing {
    private let fileSystem: any TinkerbleSourceFileSystem
    private let locator = TinkerbleSwiftSourceLocator()
    private let serializer: TinkerbleValueExpressionSerializer

    public init() {
        fileSystem = TinkerbleLocalSourceFileSystem()
        serializer = TinkerbleValueExpressionSerializer()
    }

    init(
        fileSystem: any TinkerbleSourceFileSystem,
        serializer: TinkerbleValueExpressionSerializer = .init()
    ) {
        self.fileSystem = fileSystem
        self.serializer = serializer
    }

    public func apply(_ requests: [TinkerbleSourceApplyRequest]) async throws -> TinkerbleSourceApplyResult {
        guard !requests.isEmpty else { return .init(edits: []) }

        var files: [String: PreparedSourceFile] = [:]
        var issues: [TinkerbleSourceEditIssue] = []

        for request in requests {
            do {
                let preparedEdit = try prepare(request, files: &files)
                files[preparedEdit.fileKey]?.patches.append(preparedEdit.patch)
            } catch let issue as TinkerbleSourceEditIssue {
                issues.append(issue)
            } catch {
                issues.append(
                    .init(tweak: request.tweak, reason: .unsupportedValue(error.localizedDescription))
                )
            }
        }

        guard issues.isEmpty else {
            throw TinkerbleSourceApplyError(issues: issues)
        }

        do {
            files = try proposedFiles(from: files)
        } catch let issue as TinkerbleSourceEditIssue {
            throw TinkerbleSourceApplyError(issues: [issue])
        }

        return try commit(files: files)
    }

    private func prepare(
        _ request: TinkerbleSourceApplyRequest,
        files: inout [String: PreparedSourceFile]
    ) throws -> PreparedEdit {
        let uniqueAnchors = Dictionary(grouping: request.tweak.sourceAnchors, by: \.stableID).values.compactMap(\.first)
        guard let anchor = uniqueAnchors.first else {
            throw TinkerbleSourceEditIssue(tweak: request.tweak, reason: .missingSourceMetadata)
        }
        guard uniqueAnchors.count == 1 else {
            throw TinkerbleSourceEditIssue(
                tweak: request.tweak,
                reason: .ambiguousSourceAnchors(uniqueAnchors.map(\.filePath).sorted())
            )
        }
        guard anchor.schemaVersion == 1 else {
            throw TinkerbleSourceEditIssue(
                tweak: request.tweak,
                reason: .unsupportedValue("This source registration was created by an unsupported metadata version. Rebuild with a compatible Tinkerble version.")
            )
        }

        let projectRoot = fileSystem.canonicalURL(request.projectRoot)
        let sourceURL = fileSystem.canonicalURL(URL(fileURLWithPath: anchor.filePath))
        guard sourceURL.pathComponents.starts(with: projectRoot.pathComponents), sourceURL != projectRoot else {
            throw TinkerbleSourceEditIssue(tweak: request.tweak, reason: .sourceOutsideProject(sourceURL.path))
        }

        let information = fileSystem.information(at: sourceURL)
        guard information.exists else {
            throw TinkerbleSourceEditIssue(tweak: request.tweak, reason: .fileMissing(sourceURL.path))
        }
        guard information.isRegularFile else {
            throw TinkerbleSourceEditIssue(tweak: request.tweak, reason: .fileIsNotRegular(sourceURL.path))
        }
        guard information.isWritable else {
            throw TinkerbleSourceEditIssue(tweak: request.tweak, reason: .fileIsNotWritable(sourceURL.path))
        }

        let fileKey = sourceURL.path
        let preparedFile: PreparedSourceFile
        if let existingFile = files[fileKey] {
            preparedFile = existingFile
        } else {
            let data: Data
            do {
                data = try fileSystem.data(at: sourceURL)
            } catch {
                throw TinkerbleSourceEditIssue(tweak: request.tweak, reason: .unreadableFile(sourceURL.path))
            }
            guard let source = String(data: data, encoding: .utf8) else {
                throw TinkerbleSourceEditIssue(tweak: request.tweak, reason: .invalidUTF8(sourceURL.path))
            }
            preparedFile = .init(
                url: sourceURL,
                originalData: data,
                originalHash: TinkerbleSourceHash.sha256(data),
                source: source,
                proposedData: data,
                proposedHash: TinkerbleSourceHash.sha256(data),
                patches: []
            )
            files[fileKey] = preparedFile
        }

        let located = try locator.locate(
            anchor: anchor,
            acceptedInitializerExpressions: request.acceptedInitializerExpressions,
            source: preparedFile.source,
            tweak: request.tweak
        )
        let writtenExpression = try serializer.expression(
            for: request.tweak,
            anchor: anchor,
            currentInitializer: located.expression
        )
        guard locator.canonicalExpression(writtenExpression) != nil else {
            throw TinkerbleSourceEditIssue(
                tweak: request.tweak,
                reason: .unsupportedValue("Tinkerble could not produce a valid Swift expression for this value.")
            )
        }

        return .init(
            fileKey: fileKey,
            patch: .init(
                request: request,
                anchor: anchor,
                previousExpression: located.expression,
                writtenExpression: writtenExpression,
                utf8Range: located.utf8Range
            )
        )
    }

    private func proposedFiles(from files: [String: PreparedSourceFile]) throws -> [String: PreparedSourceFile] {
        var proposedFiles = files
        for key in proposedFiles.keys.sorted() {
            guard var file = proposedFiles[key], let firstTweak = file.patches.first?.request.tweak else { continue }
            let patches = file.patches.sorted { $0.utf8Range.lowerBound > $1.utf8Range.lowerBound }

            for pair in zip(patches, patches.dropFirst()) where pair.0.utf8Range.overlaps(pair.1.utf8Range) {
                throw TinkerbleSourceEditIssue(
                    tweak: firstTweak,
                    reason: .declarationAmbiguous(file.url.path)
                )
            }

            var proposedData = file.originalData
            for patch in patches {
                guard patch.utf8Range.lowerBound >= 0, patch.utf8Range.upperBound <= proposedData.count else {
                    throw TinkerbleSourceEditIssue(tweak: patch.request.tweak, reason: .parseFailure(file.url.path))
                }
                proposedData.replaceSubrange(patch.utf8Range, with: Data(patch.writtenExpression.utf8))
            }

            guard let proposedSource = String(data: proposedData, encoding: .utf8),
                  !Parser.parse(source: proposedSource).hasError
            else {
                throw TinkerbleSourceEditIssue(tweak: firstTweak, reason: .parseFailure(file.url.path))
            }
            file.proposedData = proposedData
            file.proposedHash = TinkerbleSourceHash.sha256(proposedData)
            proposedFiles[key] = file
        }
        return proposedFiles
    }

    private func commit(files: [String: PreparedSourceFile]) throws -> TinkerbleSourceApplyResult {
        let changedFiles = files.values.filter { $0.originalHash != $0.proposedHash }
        var stages: [String: URL] = [:]
        var committedKeys: [String] = []

        defer {
            for stage in stages.values {
                fileSystem.removeItemIfPresent(at: stage)
            }
        }

        for file in changedFiles {
            do {
                stages[file.url.path] = try fileSystem.stage(file.proposedData, beside: file.url)
            } catch {
                let issue = TinkerbleSourceEditIssue(
                    tweak: file.patches[0].request.tweak,
                    reason: .stagingFailure(file.url.path)
                )
                throw TinkerbleSourceApplyError(issues: [issue])
            }
        }

        do {
            for file in changedFiles.sorted(by: { $0.url.path < $1.url.path }) {
                let currentData: Data
                do {
                    currentData = try fileSystem.data(at: file.url)
                } catch {
                    throw TinkerbleSourceEditIssue(
                        tweak: file.patches[0].request.tweak,
                        reason: .unreadableFile(file.url.path)
                    )
                }
                guard TinkerbleSourceHash.sha256(currentData) == file.originalHash else {
                    throw TinkerbleSourceEditIssue(
                        tweak: file.patches[0].request.tweak,
                        reason: .concurrentModification(file.url.path)
                    )
                }
                guard let stage = stages[file.url.path] else {
                    throw TinkerbleSourceEditIssue(
                        tweak: file.patches[0].request.tweak,
                        reason: .stagingFailure(file.url.path)
                    )
                }

                do {
                    try fileSystem.replaceItem(at: file.url, with: stage)
                    committedKeys.append(file.url.path)
                } catch {
                    throw TinkerbleSourceEditIssue(
                        tweak: file.patches[0].request.tweak,
                        reason: .writeFailure(file.url.path)
                    )
                }

                let writtenData: Data
                do {
                    writtenData = try fileSystem.data(at: file.url)
                } catch {
                    throw TinkerbleSourceEditIssue(
                        tweak: file.patches[0].request.tweak,
                        reason: .verificationFailure(file.url.path)
                    )
                }
                guard TinkerbleSourceHash.sha256(writtenData) == file.proposedHash else {
                    throw TinkerbleSourceEditIssue(
                        tweak: file.patches[0].request.tweak,
                        reason: .verificationFailure(file.url.path)
                    )
                }
            }

            for file in changedFiles.sorted(by: { $0.url.path < $1.url.path }) {
                let finalData: Data
                do {
                    finalData = try fileSystem.data(at: file.url)
                } catch {
                    throw TinkerbleSourceEditIssue(
                        tweak: file.patches[0].request.tweak,
                        reason: .verificationFailure(file.url.path)
                    )
                }
                guard TinkerbleSourceHash.sha256(finalData) == file.proposedHash else {
                    throw TinkerbleSourceEditIssue(
                        tweak: file.patches[0].request.tweak,
                        reason: .verificationFailure(file.url.path)
                    )
                }
            }
        } catch let originalIssue as TinkerbleSourceEditIssue {
            let rollback = rollback(committedKeys: committedKeys, files: files)
            throw TinkerbleSourceApplyError(
                issues: [originalIssue] + rollback.issues,
                changedFilePaths: rollback.changedFilePaths
            )
        } catch {
            let fallbackFile = changedFiles.first
            let issue = fallbackFile.map {
                TinkerbleSourceEditIssue(tweak: $0.patches[0].request.tweak, reason: .writeFailure($0.url.path))
            }
            let rollback = rollback(committedKeys: committedKeys, files: files)
            throw TinkerbleSourceApplyError(
                issues: (issue.map { [$0] } ?? []) + rollback.issues,
                changedFilePaths: rollback.changedFilePaths
            )
        }

        let edits = files.values
            .flatMap { file in
                file.patches.map { patch in
                    TinkerbleAppliedSourceEdit(
                        tweakID: patch.request.tweak.id,
                        anchor: patch.anchor,
                        previousExpression: patch.previousExpression,
                        writtenExpression: patch.writtenExpression,
                        originalFileHash: file.originalHash,
                        writtenFileHash: file.proposedHash
                    )
                }
            }
            .sorted { $0.tweakID < $1.tweakID }
        return .init(edits: edits)
    }

    private func rollback(
        committedKeys: [String],
        files: [String: PreparedSourceFile]
    ) -> (issues: [TinkerbleSourceEditIssue], changedFilePaths: [String]) {
        var issues: [TinkerbleSourceEditIssue] = []
        var changedFilePaths: [String] = []
        for key in committedKeys.reversed() {
            guard let file = files[key] else { continue }
            do {
                let currentData = try fileSystem.data(at: file.url)
                guard TinkerbleSourceHash.sha256(currentData) == file.proposedHash else {
                    throw CocoaError(.fileWriteUnknown)
                }
                let rollbackStage = try fileSystem.stage(file.originalData, beside: file.url)
                defer { fileSystem.removeItemIfPresent(at: rollbackStage) }
                try fileSystem.replaceItem(at: file.url, with: rollbackStage)
                let restoredData = try fileSystem.data(at: file.url)
                guard TinkerbleSourceHash.sha256(restoredData) == file.originalHash else {
                    throw CocoaError(.fileWriteUnknown)
                }
            } catch {
                issues.append(
                    .init(tweak: file.patches[0].request.tweak, reason: .rollbackFailure(file.url.path))
                )
                changedFilePaths.append(file.url.path)
            }
        }
        return (issues, changedFilePaths)
    }
}

private struct PreparedEdit {
    var fileKey: String
    var patch: PreparedSourcePatch
}

private struct PreparedSourcePatch {
    var request: TinkerbleSourceApplyRequest
    var anchor: TinkerbleSourceAnchor
    var previousExpression: String
    var writtenExpression: String
    var utf8Range: Range<Int>
}

private struct PreparedSourceFile {
    var url: URL
    var originalData: Data
    var originalHash: String
    var source: String
    var proposedData: Data
    var proposedHash: String
    var patches: [PreparedSourcePatch]
}

import Foundation
import SwiftUI
import XCTest
@testable import Tinkerble
@testable import TinkerbleCompanionCore

private enum CustomIdentifierMode: String, CaseIterable, TinkerbleEnum {
    case happy = "celebratory"
    case quiet
}

final class TinkerbleSourceEditingTests: XCTestCase {
    func testAppliesEverySupportedValueTypeInOneTransaction() async throws {
        let projectRoot = try temporaryProject()
        let fileURL = projectRoot.appending(path: "Fixture.swift")
        let original = """
        import SwiftUI
        import Tinkerble

        enum TestMode: String, CaseIterable, TinkerbleEnum {
            case first
            case second
        }

        struct Fixture {
            @TinkerbleState("String") var stringValue = "before"
            @TinkerbleState("Bool") var boolValue = false
            @TinkerbleState("Color") var colorValue = Color.blue
            @TinkerbleState("Int") var intValue = 1
            @TinkerbleState("Double") var doubleValue = 1.0
            @TinkerbleState("Float") var floatValue = Float(1)
            @TinkerbleState("CGFloat") var cgFloatValue = CGFloat(1)
            @TinkerbleState("Angle") var angleValue = Angle.degrees(10)
            @TinkerbleState("Date") var dateValue = Date(timeIntervalSinceReferenceDate: 1)
            @TinkerbleState("Enum") var enumValue = TestMode.first
        }
        """
        try original.write(to: fileURL, atomically: true, encoding: .utf8)

        let requests = [
            request(fileURL: fileURL, root: projectRoot, property: "stringValue", initializer: "\"before\"", type: .string, value: .string("after")),
            request(fileURL: fileURL, root: projectRoot, property: "boolValue", initializer: "false", type: .bool, value: .bool(true)),
            request(fileURL: fileURL, root: projectRoot, property: "colorValue", initializer: "Color.blue", type: .color, value: .color(.init(red: 0.1, green: 0.2, blue: 0.3, alpha: 0.4))),
            request(fileURL: fileURL, root: projectRoot, property: "intValue", initializer: "1", type: .int, value: .number(27)),
            request(fileURL: fileURL, root: projectRoot, property: "doubleValue", initializer: "1.0", type: .double, value: .number(2.5)),
            request(fileURL: fileURL, root: projectRoot, property: "floatValue", initializer: "Float(1)", type: .float, value: .number(3.5)),
            request(fileURL: fileURL, root: projectRoot, property: "cgFloatValue", initializer: "CGFloat(1)", type: .cgFloat, value: .number(4.5)),
            request(
                fileURL: fileURL,
                root: projectRoot,
                property: "angleValue",
                initializer: "Angle.degrees(10)",
                type: .angle,
                value: .number(.pi / 2),
                control: .plain(.init(step: 1, decimalPlaces: 0, angleUnit: .degrees))
            ),
            request(
                fileURL: fileURL,
                root: projectRoot,
                property: "dateValue",
                initializer: "Date(timeIntervalSinceReferenceDate: 1)",
                type: .date,
                value: .date(Date(timeIntervalSinceReferenceDate: 42))
            ),
            request(
                fileURL: fileURL,
                root: projectRoot,
                property: "enumValue",
                initializer: "TestMode.first",
                type: .enumeration(typeName: "TestMode"),
                value: .enumCase("second")
            )
        ]

        let result = try await TinkerbleSourceEditingService().apply(requests)

        XCTAssertEqual(result.edits.count, 10)
        XCTAssertEqual(
            try String(contentsOf: fileURL, encoding: .utf8),
            """
            import SwiftUI
            import Tinkerble

            enum TestMode: String, CaseIterable, TinkerbleEnum {
                case first
                case second
            }

            struct Fixture {
                @TinkerbleState("String") var stringValue = "after"
                @TinkerbleState("Bool") var boolValue = true
                @TinkerbleState("Color") var colorValue = Color(.sRGB, red: 0.1, green: 0.2, blue: 0.3, opacity: 0.4)
                @TinkerbleState("Int") var intValue = 27
                @TinkerbleState("Double") var doubleValue = 2.5
                @TinkerbleState("Float") var floatValue = Float(3.5)
                @TinkerbleState("CGFloat") var cgFloatValue = CGFloat(4.5)
                @TinkerbleState("Angle") var angleValue = Angle.degrees(90.0)
                @TinkerbleState("Date") var dateValue = Date(timeIntervalSinceReferenceDate: 42.0)
                @TinkerbleState("Enum") var enumValue = TestMode.tinkerbleCase(for: "second") ?? (TestMode.first)
            }
            """
        )
    }

    func testPreservesEveryByteOutsideInitializerExpression() async throws {
        let projectRoot = try temporaryProject()
        let fileURL = projectRoot.appending(path: "Unicode.swift")
        let original = """
        // 🪽 preceding UTF-8 must not shift the byte edit
        struct Outer {
            struct Inner {
                @TinkerbleState("Value")
                var value = 1 // retained
            }
        }
        """
        try original.write(to: fileURL, atomically: true, encoding: .utf8)
        let editRequest = request(
            fileURL: fileURL,
            root: projectRoot,
            property: "value",
            initializer: "1",
            type: .int,
            value: .number(2),
            enclosingTypePath: ["Outer", "Inner"]
        )

        _ = try await TinkerbleSourceEditingService().apply([editRequest])

        XCTAssertEqual(
            try String(contentsOf: fileURL, encoding: .utf8),
            original.replacing("var value = 1 // retained", with: "var value = 2 // retained")
        )
    }

    func testMissingFileReturnsStructuredIssueWithoutWriting() async throws {
        let projectRoot = try temporaryProject()
        let fileURL = projectRoot.appending(path: "Missing.swift")
        let editRequest = request(fileURL: fileURL, root: projectRoot, property: "value", initializer: "1", type: .int, value: .number(2))

        do {
            _ = try await TinkerbleSourceEditingService().apply([editRequest])
            XCTFail("Expected missing file failure")
        } catch let error as TinkerbleSourceApplyError {
            XCTAssertTrue(error.noFilesChanged)
            XCTAssertEqual(error.issues.count, 1)
            guard case .fileMissing(fileURL.path) = error.issues[0].reason else {
                return XCTFail("Expected fileMissing issue")
            }
        }
    }

    func testSourceOutsideProjectReturnsStructuredIssue() async throws {
        let projectRoot = try temporaryProject()
        let otherRoot = try temporaryProject()
        let fileURL = otherRoot.appending(path: "Outside.swift")
        try source(property: "value", initializer: "1").write(to: fileURL, atomically: true, encoding: .utf8)
        let editRequest = request(fileURL: fileURL, root: projectRoot, property: "value", initializer: "1", type: .int, value: .number(2))

        do {
            _ = try await TinkerbleSourceEditingService().apply([editRequest])
            XCTFail("Expected outside-project failure")
        } catch let error as TinkerbleSourceApplyError {
            guard case .sourceOutsideProject(fileURL.path) = error.issues[0].reason else {
                return XCTFail("Expected sourceOutsideProject issue")
            }
        }
    }

    func testStaleInitializerReturnsIssueAndLeavesSourceUntouched() async throws {
        let projectRoot = try temporaryProject()
        let fileURL = projectRoot.appending(path: "Stale.swift")
        let original = source(property: "value", initializer: "3")
        try original.write(to: fileURL, atomically: true, encoding: .utf8)
        let editRequest = request(fileURL: fileURL, root: projectRoot, property: "value", initializer: "1", type: .int, value: .number(2))

        do {
            _ = try await TinkerbleSourceEditingService().apply([editRequest])
            XCTFail("Expected stale initializer failure")
        } catch let error as TinkerbleSourceApplyError {
            guard case .staleInitializer = error.issues[0].reason else {
                return XCTFail("Expected staleInitializer issue")
            }
            XCTAssertEqual(try String(contentsOf: fileURL, encoding: .utf8), original)
        }
    }

    func testMovedDeclarationReturnsIssue() async throws {
        let projectRoot = try temporaryProject()
        let fileURL = projectRoot.appending(path: "Ambiguous.swift")
        let original = """
        struct Fixture {
            @TinkerbleState("Value") var value = 1
        }
        struct Fixture {
            @TinkerbleState("Value") var value = 1
        }
        """
        try original.write(to: fileURL, atomically: true, encoding: .utf8)
        let editRequest = request(fileURL: fileURL, root: projectRoot, property: "value", initializer: "1", type: .int, value: .number(2))

        do {
            _ = try await TinkerbleSourceEditingService().apply([editRequest])
            XCTFail("Expected moved declaration failure")
        } catch let error as TinkerbleSourceApplyError {
            guard case .declarationMoved(fileURL.path) = error.issues[0].reason else {
                return XCTFail("Expected declarationMoved issue")
            }
        }
    }

    func testDuplicateConditionalDeclarationsUseTheCompiledAnchorLocation() async throws {
        let projectRoot = try temporaryProject()
        let fileURL = projectRoot.appending(path: "Conditional.swift")
        let original = """
        struct Fixture {
        #if DEBUG
            @TinkerbleState("Value") var value = 1
        #else
            @TinkerbleState("Value") var value = 1
        #endif
        }
        """
        try original.write(to: fileURL, atomically: true, encoding: .utf8)
        let editRequest = request(
            fileURL: fileURL,
            root: projectRoot,
            property: "value",
            initializer: "1",
            type: .int,
            value: .number(2),
            line: 3,
            column: 5
        )

        _ = try await TinkerbleSourceEditingService().apply([editRequest])

        XCTAssertEqual(
            try String(contentsOf: fileURL, encoding: .utf8),
            original.replacing(
                "#if DEBUG\n    @TinkerbleState(\"Value\") var value = 1",
                with: "#if DEBUG\n    @TinkerbleState(\"Value\") var value = 2"
            )
        )
    }

    func testBatchPreflightFailureLeavesValidEditUnwritten() async throws {
        let projectRoot = try temporaryProject()
        let fileURL = projectRoot.appending(path: "Batch.swift")
        let original = """
        struct Fixture {
            @TinkerbleState("First") var first = 1
            @TinkerbleState("Second") var second = 2
        }
        """
        try original.write(to: fileURL, atomically: true, encoding: .utf8)
        let valid = request(fileURL: fileURL, root: projectRoot, property: "first", initializer: "1", type: .int, value: .number(10))
        let stale = request(fileURL: fileURL, root: projectRoot, property: "second", initializer: "999", type: .int, value: .number(20))

        do {
            _ = try await TinkerbleSourceEditingService().apply([valid, stale])
            XCTFail("Expected preflight failure")
        } catch let error as TinkerbleSourceApplyError {
            XCTAssertTrue(error.noFilesChanged)
            XCTAssertEqual(try String(contentsOf: fileURL, encoding: .utf8), original)
        }
    }

    func testSecondFileWriteFailureRollsBackFirstFile() async throws {
        let projectRoot = try temporaryProject()
        let firstURL = projectRoot.appending(path: "A.swift")
        let secondURL = projectRoot.appending(path: "B.swift")
        let firstSource = source(typeName: "FirstFixture", property: "first", initializer: "1")
        let secondSource = source(typeName: "SecondFixture", property: "second", initializer: "2")
        try firstSource.write(to: firstURL, atomically: true, encoding: .utf8)
        try secondSource.write(to: secondURL, atomically: true, encoding: .utf8)
        let first = request(
            fileURL: firstURL,
            root: projectRoot,
            property: "first",
            initializer: "1",
            type: .int,
            value: .number(10),
            enclosingTypePath: ["FirstFixture"]
        )
        let second = request(
            fileURL: secondURL,
            root: projectRoot,
            property: "second",
            initializer: "2",
            type: .int,
            value: .number(20),
            enclosingTypePath: ["SecondFixture"]
        )
        let fileSystem = FailingReplaceSourceFileSystem(failingReplacement: 2)
        let service = TinkerbleSourceEditingService(fileSystem: fileSystem)

        do {
            _ = try await service.apply([first, second])
            XCTFail("Expected second replacement to fail")
        } catch let error as TinkerbleSourceApplyError {
            XCTAssertTrue(error.noFilesChanged)
            guard case .writeFailure(secondURL.path) = error.issues[0].reason else {
                return XCTFail("Expected writeFailure for the second file")
            }
            XCTAssertEqual(try String(contentsOf: firstURL, encoding: .utf8), firstSource)
            XCTAssertEqual(try String(contentsOf: secondURL, encoding: .utf8), secondSource)
        }
    }

    func testRollbackPreservesExternalChangeMadeAfterFirstCommit() async throws {
        let projectRoot = try temporaryProject()
        let firstURL = projectRoot.appending(path: "A.swift")
        let secondURL = projectRoot.appending(path: "B.swift")
        let firstSource = source(typeName: "FirstFixture", property: "first", initializer: "1")
        let secondSource = source(typeName: "SecondFixture", property: "second", initializer: "2")
        let externalChange = source(typeName: "FirstFixture", property: "first", initializer: "99")
        try firstSource.write(to: firstURL, atomically: true, encoding: .utf8)
        try secondSource.write(to: secondURL, atomically: true, encoding: .utf8)
        let first = request(
            fileURL: firstURL,
            root: projectRoot,
            property: "first",
            initializer: "1",
            type: .int,
            value: .number(10),
            enclosingTypePath: ["FirstFixture"]
        )
        let second = request(
            fileURL: secondURL,
            root: projectRoot,
            property: "second",
            initializer: "2",
            type: .int,
            value: .number(20),
            enclosingTypePath: ["SecondFixture"]
        )
        let service = TinkerbleSourceEditingService(
            fileSystem: MutatingCommittedFileSourceFileSystem(
                externalData: Data(externalChange.utf8),
                failsSecondReplacement: true
            )
        )

        do {
            _ = try await service.apply([first, second])
            XCTFail("Expected second replacement to fail")
        } catch let error as TinkerbleSourceApplyError {
            XCTAssertEqual(error.changedFilePaths, [firstURL.path])
            guard case .writeFailure(secondURL.path) = error.issues.first?.reason else {
                return XCTFail("Expected writeFailure for the second file")
            }
            guard case .rollbackFailure(firstURL.path) = error.issues.last?.reason else {
                return XCTFail("Expected rollbackFailure for the externally changed file")
            }
            XCTAssertEqual(try String(contentsOf: firstURL, encoding: .utf8), externalChange)
            XCTAssertEqual(try String(contentsOf: secondURL, encoding: .utf8), secondSource)
        }
    }

    func testFinalVerificationDetectsExternalChangeAfterEarlierReadback() async throws {
        let projectRoot = try temporaryProject()
        let firstURL = projectRoot.appending(path: "A.swift")
        let secondURL = projectRoot.appending(path: "B.swift")
        let firstSource = source(typeName: "FirstFixture", property: "first", initializer: "1")
        let secondSource = source(typeName: "SecondFixture", property: "second", initializer: "2")
        let externalChange = source(typeName: "FirstFixture", property: "first", initializer: "99")
        try firstSource.write(to: firstURL, atomically: true, encoding: .utf8)
        try secondSource.write(to: secondURL, atomically: true, encoding: .utf8)
        let first = request(
            fileURL: firstURL,
            root: projectRoot,
            property: "first",
            initializer: "1",
            type: .int,
            value: .number(10),
            enclosingTypePath: ["FirstFixture"]
        )
        let second = request(
            fileURL: secondURL,
            root: projectRoot,
            property: "second",
            initializer: "2",
            type: .int,
            value: .number(20),
            enclosingTypePath: ["SecondFixture"]
        )
        let service = TinkerbleSourceEditingService(
            fileSystem: MutatingCommittedFileSourceFileSystem(
                externalData: Data(externalChange.utf8),
                failsSecondReplacement: false
            )
        )

        do {
            _ = try await service.apply([first, second])
            XCTFail("Expected final verification to fail")
        } catch let error as TinkerbleSourceApplyError {
            XCTAssertEqual(error.changedFilePaths, [firstURL.path])
            guard case .verificationFailure(firstURL.path) = error.issues.first?.reason else {
                return XCTFail("Expected verificationFailure for the externally changed file")
            }
            XCTAssertEqual(try String(contentsOf: firstURL, encoding: .utf8), externalChange)
            XCTAssertEqual(try String(contentsOf: secondURL, encoding: .utf8), secondSource)
        }
    }

    func testPostWriteReadbackFailureReportsTheWrittenFileAndRollsBack() async throws {
        let projectRoot = try temporaryProject()
        let fileURL = projectRoot.appending(path: "Unreadable.swift")
        let original = source(property: "value", initializer: "1")
        try original.write(to: fileURL, atomically: true, encoding: .utf8)
        let editRequest = request(
            fileURL: fileURL,
            root: projectRoot,
            property: "value",
            initializer: "1",
            type: .int,
            value: .number(2)
        )
        let service = TinkerbleSourceEditingService(fileSystem: FailingPostWriteReadSourceFileSystem())

        do {
            _ = try await service.apply([editRequest])
            XCTFail("Expected post-write verification to fail")
        } catch let error as TinkerbleSourceApplyError {
            XCTAssertTrue(error.noFilesChanged)
            guard case .verificationFailure(fileURL.path) = error.issues.first?.reason else {
                return XCTFail("Expected verificationFailure for the written file")
            }
            XCTAssertEqual(try String(contentsOf: fileURL, encoding: .utf8), original)
        }
    }

    func testConcurrentModificationAfterStagingIsDetectedWithoutOverwriting() async throws {
        let projectRoot = try temporaryProject()
        let fileURL = projectRoot.appending(path: "Concurrent.swift")
        let original = source(property: "value", initializer: "1")
        let externalChange = source(property: "value", initializer: "99")
        try original.write(to: fileURL, atomically: true, encoding: .utf8)
        let editRequest = request(fileURL: fileURL, root: projectRoot, property: "value", initializer: "1", type: .int, value: .number(2))
        let fileSystem = MutatingAfterStageSourceFileSystem(replacementData: Data(externalChange.utf8))
        let service = TinkerbleSourceEditingService(fileSystem: fileSystem)

        do {
            _ = try await service.apply([editRequest])
            XCTFail("Expected concurrent modification failure")
        } catch let error as TinkerbleSourceApplyError {
            XCTAssertTrue(error.noFilesChanged)
            guard case .concurrentModification(fileURL.path) = error.issues[0].reason else {
                return XCTFail("Expected concurrentModification issue")
            }
            XCTAssertEqual(try String(contentsOf: fileURL, encoding: .utf8), externalChange)
        }
    }

    func testMissingAndAmbiguousSourceMetadataReturnStructuredIssues() async throws {
        let projectRoot = try temporaryProject()
        let firstURL = projectRoot.appending(path: "First.swift")
        let secondURL = projectRoot.appending(path: "Second.swift")
        try source(property: "value", initializer: "1").write(to: firstURL, atomically: true, encoding: .utf8)
        try source(property: "value", initializer: "1").write(to: secondURL, atomically: true, encoding: .utf8)
        let firstAnchor = sourceAnchor(fileURL: firstURL, property: "value", initializer: "1")
        let secondAnchor = sourceAnchor(fileURL: secondURL, property: "value", initializer: "1")
        let missingTweak = TinkerbleTweak(
            id: "missing",
            category: "Tests",
            name: "Missing",
            value: .number(2),
            valueKind: .number,
            control: .automatic,
            sourceValueType: .int
        )
        let ambiguousTweak = TinkerbleTweak(
            id: "ambiguous",
            category: "Tests",
            name: "Ambiguous",
            value: .number(2),
            valueKind: .number,
            control: .automatic,
            sourceValueType: .int,
            sourceAnchors: [firstAnchor, secondAnchor]
        )

        do {
            _ = try await TinkerbleSourceEditingService().apply(
                [
                    .init(projectID: "test.project", projectRoot: projectRoot, tweak: missingTweak),
                    .init(projectID: "test.project", projectRoot: projectRoot, tweak: ambiguousTweak)
                ]
            )
            XCTFail("Expected metadata failures")
        } catch let error as TinkerbleSourceApplyError {
            XCTAssertEqual(error.issues.count, 2)
            guard case .missingSourceMetadata = error.issues[0].reason else {
                return XCTFail("Expected missingSourceMetadata issue")
            }
            guard case .ambiguousSourceAnchors = error.issues[1].reason else {
                return XCTFail("Expected ambiguousSourceAnchors issue")
            }
        }
    }

    func testMalformedMissingInitializerAndNonUTF8FilesReturnAllIssues() async throws {
        let projectRoot = try temporaryProject()
        let malformedURL = projectRoot.appending(path: "Malformed.swift")
        let missingInitializerURL = projectRoot.appending(path: "MissingInitializer.swift")
        let nonUTF8URL = projectRoot.appending(path: "NonUTF8.swift")
        try "struct Fixture {".write(to: malformedURL, atomically: true, encoding: .utf8)
        try "struct Fixture { @TinkerbleState(\"Value\") var value: Int }".write(
            to: missingInitializerURL,
            atomically: true,
            encoding: .utf8
        )
        try Data([0xFF, 0xFE]).write(to: nonUTF8URL)
        let malformed = request(fileURL: malformedURL, root: projectRoot, property: "value", initializer: "1", type: .int, value: .number(2))
        let missingInitializer = request(
            fileURL: missingInitializerURL,
            root: projectRoot,
            property: "value",
            initializer: "1",
            type: .int,
            value: .number(2)
        )
        let nonUTF8 = request(fileURL: nonUTF8URL, root: projectRoot, property: "value", initializer: "1", type: .int, value: .number(2))

        do {
            _ = try await TinkerbleSourceEditingService().apply([malformed, missingInitializer, nonUTF8])
            XCTFail("Expected three preflight issues")
        } catch let error as TinkerbleSourceApplyError {
            XCTAssertEqual(error.issues.count, 3)
            guard case .parseFailure(malformedURL.path) = error.issues[0].reason else {
                return XCTFail("Expected parseFailure issue")
            }
            guard case .initializerMissing(missingInitializerURL.path) = error.issues[1].reason else {
                return XCTFail("Expected initializerMissing issue")
            }
            guard case .invalidUTF8(nonUTF8URL.path) = error.issues[2].reason else {
                return XCTFail("Expected invalidUTF8 issue")
            }
        }
    }

    func testRollbackFailureReportsFileThatRemainsChanged() async throws {
        let projectRoot = try temporaryProject()
        let firstURL = projectRoot.appending(path: "A.swift")
        let secondURL = projectRoot.appending(path: "B.swift")
        let firstSource = source(typeName: "FirstFixture", property: "first", initializer: "1")
        let secondSource = source(typeName: "SecondFixture", property: "second", initializer: "2")
        try firstSource.write(to: firstURL, atomically: true, encoding: .utf8)
        try secondSource.write(to: secondURL, atomically: true, encoding: .utf8)
        let first = request(
            fileURL: firstURL,
            root: projectRoot,
            property: "first",
            initializer: "1",
            type: .int,
            value: .number(10),
            enclosingTypePath: ["FirstFixture"]
        )
        let second = request(
            fileURL: secondURL,
            root: projectRoot,
            property: "second",
            initializer: "2",
            type: .int,
            value: .number(20),
            enclosingTypePath: ["SecondFixture"]
        )
        let service = TinkerbleSourceEditingService(
            fileSystem: FailingReplaceSourceFileSystem(failingReplacements: [2, 3])
        )

        do {
            _ = try await service.apply([first, second])
            XCTFail("Expected write and rollback failures")
        } catch let error as TinkerbleSourceApplyError {
            XCTAssertEqual(error.changedFilePaths, [firstURL.path])
            XCTAssertEqual(error.issues.count, 2)
            guard case .rollbackFailure(firstURL.path) = error.issues[1].reason else {
                return XCTFail("Expected rollbackFailure issue")
            }
            XCTAssertEqual(try String(contentsOf: firstURL, encoding: .utf8), source(typeName: "FirstFixture", property: "first", initializer: "10"))
            XCTAssertEqual(try String(contentsOf: secondURL, encoding: .utf8), secondSource)
        }
    }

    func testAcceptedAppliedInitializerAllowsRepeatedEditBeforeRebuild() async throws {
        let projectRoot = try temporaryProject()
        let fileURL = projectRoot.appending(path: "Repeated.swift")
        try source(property: "value", initializer: "2").write(to: fileURL, atomically: true, encoding: .utf8)
        var editRequest = request(fileURL: fileURL, root: projectRoot, property: "value", initializer: "1", type: .int, value: .number(3))
        editRequest.acceptedInitializerExpressions = ["2"]

        _ = try await TinkerbleSourceEditingService().apply([editRequest])

        XCTAssertEqual(try String(contentsOf: fileURL, encoding: .utf8), source(property: "value", initializer: "3"))
    }

    func testSerializerEscapesStringAndRejectsFractionalInt() throws {
        let serializer = TinkerbleValueExpressionSerializer()
        let root = URL(fileURLWithPath: "/tmp")
        let anchor = sourceAnchor(fileURL: root.appending(path: "Fixture.swift"), property: "value", initializer: "\"old\"")
        let stringTweak = tweak(property: "value", type: .string, value: .string("quote \" slash \\ interpolation \\(x)\n"), anchor: anchor)

        let expression = try serializer.expression(for: stringTweak, anchor: anchor, currentInitializer: "\"old\"")

        XCTAssertNotNil(TinkerbleSwiftSourceLocator().canonicalExpression(expression))

        let intAnchor = sourceAnchor(fileURL: root.appending(path: "Fixture.swift"), property: "count", initializer: "1")
        let intTweak = tweak(property: "count", type: .int, value: .number(1.5), anchor: intAnchor)
        XCTAssertThrowsError(try serializer.expression(for: intTweak, anchor: intAnchor, currentInitializer: "1"))
    }

    func testSerializerWritesTheNumericPrecisionShownInTheCompanion() throws {
        let control = TinkerbleControlDescriptor.plain(.init(decimalPlaces: 2))
        let floatingPointArtifact = 0.300_000_000_000_000_04

        XCTAssertEqual(
            try serializedNumericExpression(
                type: .double,
                value: floatingPointArtifact,
                control: control,
                initializer: "0"
            ),
            "0.3"
        )
        XCTAssertEqual(
            try serializedNumericExpression(
                type: .double,
                value: 0.123_45,
                control: .plain(.init(decimalPlaces: 5)),
                initializer: "0"
            ),
            "0.12345"
        )
        XCTAssertEqual(
            try serializedNumericExpression(
                type: .float,
                value: floatingPointArtifact,
                control: control,
                initializer: "Float(0)"
            ),
            "Float(0.3)"
        )
        XCTAssertEqual(
            try serializedNumericExpression(
                type: .cgFloat,
                value: floatingPointArtifact,
                control: control,
                initializer: "CGFloat(0)"
            ),
            "CGFloat(0.3)"
        )

        let angleControl = TinkerbleControlDescriptor.plain(
            .init(decimalPlaces: 2, angleUnit: .degrees)
        )
        XCTAssertEqual(
            try serializedNumericExpression(
                type: .angle,
                value: floatingPointArtifact * .pi / 180,
                control: angleControl,
                initializer: "Angle.degrees(0)"
            ),
            "Angle.degrees(0.3)"
        )
    }

    func testSerializerResolvesIdentifierShapedEnumIDsThroughTinkerbleEnum() throws {
        let serializer = TinkerbleValueExpressionSerializer()
        let root = URL(fileURLWithPath: "/tmp")
        let anchor = sourceAnchor(
            fileURL: root.appending(path: "Fixture.swift"),
            property: "mode",
            initializer: "CustomIdentifierMode.quiet"
        )
        let enumTweak = tweak(
            property: "mode",
            type: .enumeration(typeName: "TinkerbleTests.CustomIdentifierMode"),
            value: .enumCase("celebratory"),
            anchor: anchor
        )

        let expression = try serializer.expression(
            for: enumTweak,
            anchor: anchor,
            currentInitializer: "CustomIdentifierMode.quiet"
        )

        XCTAssertEqual(
            expression,
            "CustomIdentifierMode.tinkerbleCase(for: \"celebratory\") ?? (CustomIdentifierMode.quiet)"
        )
        XCTAssertEqual(CustomIdentifierMode.tinkerbleCase(for: "celebratory") ?? .quiet, .happy)
    }

    func testLegacyTweakDecodingUsesCurrentValueAsCodeDefault() throws {
        let data = Data(
            #"{"id":"Value","screen":"default","name":"Value","value":{"number":{"_0":2}},"valueKind":"number","control":{"automatic":{}}}"#.utf8
        )

        let tweak = try JSONDecoder().decode(TinkerbleTweak.self, from: data)

        XCTAssertEqual(tweak.codeDefaultValue, tweak.value)
        XCTAssertNil(tweak.sourceValueType)
        XCTAssertTrue(tweak.sourceAnchors.isEmpty)
    }

    private func request(
        fileURL: URL,
        root: URL,
        property: String,
        initializer: String,
        type: TinkerbleSourceValueType,
        value: TinkerbleValue,
        control: TinkerbleControlDescriptor = .automatic,
        enclosingTypePath: [String] = ["Fixture"],
        line: Int = 1,
        column: Int = 1
    ) -> TinkerbleSourceApplyRequest {
        let anchor = sourceAnchor(
            fileURL: fileURL,
            property: property,
            initializer: initializer,
            enclosingTypePath: enclosingTypePath,
            line: line,
            column: column
        )
        return .init(
            projectID: "test.project",
            projectRoot: root,
            tweak: tweak(property: property, type: type, value: value, anchor: anchor, control: control)
        )
    }

    private func serializedNumericExpression(
        type: TinkerbleSourceValueType,
        value: Double,
        control: TinkerbleControlDescriptor,
        initializer: String
    ) throws -> String {
        let anchor = sourceAnchor(
            fileURL: URL(fileURLWithPath: "/tmp/Fixture.swift"),
            property: "value",
            initializer: initializer
        )
        let numericTweak = tweak(
            property: "value",
            type: type,
            value: .number(value),
            anchor: anchor,
            control: control
        )
        return try TinkerbleValueExpressionSerializer().expression(
            for: numericTweak,
            anchor: anchor,
            currentInitializer: initializer
        )
    }

    private func tweak(
        property: String,
        type: TinkerbleSourceValueType,
        value: TinkerbleValue,
        anchor: TinkerbleSourceAnchor,
        control: TinkerbleControlDescriptor = .automatic
    ) -> TinkerbleTweak {
        TinkerbleTweak(
            id: property,
            category: "Tests",
            name: property,
            value: value,
            valueKind: value.kind,
            control: control,
            sourceValueType: type,
            sourceAnchors: [anchor]
        )
    }

    private func sourceAnchor(
        fileURL: URL,
        property: String,
        initializer: String,
        enclosingTypePath: [String] = ["Fixture"],
        line: Int = 1,
        column: Int = 1
    ) -> TinkerbleSourceAnchor {
        .init(
            filePath: fileURL.path,
            line: line,
            column: column,
            enclosingTypePath: enclosingTypePath,
            propertyName: property,
            initializerExpression: initializer
        )
    }

    private func source(property: String, initializer: String) -> String {
        source(typeName: "Fixture", property: property, initializer: initializer)
    }

    private func source(typeName: String, property: String, initializer: String) -> String {
        """
        struct \(typeName) {
            @TinkerbleState("Value") var \(property) = \(initializer)
        }
        """
    }

    private func temporaryProject() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appending(
            path: "TinkerbleSourceEditingTests-\(UUID().uuidString)",
            directoryHint: .isDirectory
        )
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: url)
        }
        return url
    }
}

private final class FailingReplaceSourceFileSystem: TinkerbleSourceFileSystem, @unchecked Sendable {
    private let base = TinkerbleLocalSourceFileSystem()
    private let lock = NSLock()
    private let failingReplacements: Set<Int>
    private var replacementCount = 0

    init(failingReplacement: Int) {
        failingReplacements = [failingReplacement]
    }

    init(failingReplacements: Set<Int>) {
        self.failingReplacements = failingReplacements
    }

    func canonicalURL(_ url: URL) -> URL { base.canonicalURL(url) }
    func information(at url: URL) -> TinkerbleSourceFileInformation { base.information(at: url) }
    func data(at url: URL) throws -> Data { try base.data(at: url) }
    func stage(_ data: Data, beside originalURL: URL) throws -> URL { try base.stage(data, beside: originalURL) }

    func replaceItem(at originalURL: URL, with stagedURL: URL) throws {
        let shouldFail = lock.withLock { () -> Bool in
            replacementCount += 1
            return failingReplacements.contains(replacementCount)
        }
        if shouldFail {
            throw CocoaError(.fileWriteUnknown)
        }
        try base.replaceItem(at: originalURL, with: stagedURL)
    }

    func removeItemIfPresent(at url: URL) { base.removeItemIfPresent(at: url) }
}

private final class MutatingAfterStageSourceFileSystem: TinkerbleSourceFileSystem, @unchecked Sendable {
    private let base = TinkerbleLocalSourceFileSystem()
    private let lock = NSLock()
    private let replacementData: Data
    private var didMutate = false

    init(replacementData: Data) {
        self.replacementData = replacementData
    }

    func canonicalURL(_ url: URL) -> URL { base.canonicalURL(url) }
    func information(at url: URL) -> TinkerbleSourceFileInformation { base.information(at: url) }
    func data(at url: URL) throws -> Data { try base.data(at: url) }

    func stage(_ data: Data, beside originalURL: URL) throws -> URL {
        let stageURL = try base.stage(data, beside: originalURL)
        let shouldMutate = lock.withLock { () -> Bool in
            guard !didMutate else { return false }
            didMutate = true
            return true
        }
        if shouldMutate {
            try replacementData.write(to: originalURL, options: .atomic)
        }
        return stageURL
    }

    func replaceItem(at originalURL: URL, with stagedURL: URL) throws {
        try base.replaceItem(at: originalURL, with: stagedURL)
    }

    func removeItemIfPresent(at url: URL) { base.removeItemIfPresent(at: url) }
}

private final class MutatingCommittedFileSourceFileSystem: TinkerbleSourceFileSystem, @unchecked Sendable {
    private let base = TinkerbleLocalSourceFileSystem()
    private let lock = NSLock()
    private let externalData: Data
    private let failsSecondReplacement: Bool
    private var replacementCount = 0
    private var firstCommittedURL: URL?

    init(externalData: Data, failsSecondReplacement: Bool) {
        self.externalData = externalData
        self.failsSecondReplacement = failsSecondReplacement
    }

    func canonicalURL(_ url: URL) -> URL { base.canonicalURL(url) }
    func information(at url: URL) -> TinkerbleSourceFileInformation { base.information(at: url) }
    func data(at url: URL) throws -> Data { try base.data(at: url) }
    func stage(_ data: Data, beside originalURL: URL) throws -> URL { try base.stage(data, beside: originalURL) }

    func replaceItem(at originalURL: URL, with stagedURL: URL) throws {
        let replacement = lock.withLock { () -> (count: Int, firstURL: URL?) in
            replacementCount += 1
            return (replacementCount, firstCommittedURL)
        }
        if replacement.count == 1 {
            try base.replaceItem(at: originalURL, with: stagedURL)
            lock.withLock {
                firstCommittedURL = originalURL
            }
            return
        }
        if replacement.count == 2, let firstURL = replacement.firstURL {
            if !failsSecondReplacement {
                try base.replaceItem(at: originalURL, with: stagedURL)
            }
            try externalData.write(to: firstURL, options: .atomic)
            if failsSecondReplacement {
                throw CocoaError(.fileWriteUnknown)
            }
            return
        }
        try base.replaceItem(at: originalURL, with: stagedURL)
    }

    func removeItemIfPresent(at url: URL) { base.removeItemIfPresent(at: url) }
}

private final class FailingPostWriteReadSourceFileSystem: TinkerbleSourceFileSystem, @unchecked Sendable {
    private let base = TinkerbleLocalSourceFileSystem()
    private let lock = NSLock()
    private var failsNextRead = false
    private var replacementCount = 0

    func canonicalURL(_ url: URL) -> URL { base.canonicalURL(url) }
    func information(at url: URL) -> TinkerbleSourceFileInformation { base.information(at: url) }

    func data(at url: URL) throws -> Data {
        let shouldFail = lock.withLock { () -> Bool in
            defer { failsNextRead = false }
            return failsNextRead
        }
        if shouldFail {
            throw CocoaError(.fileReadUnknown)
        }
        return try base.data(at: url)
    }

    func stage(_ data: Data, beside originalURL: URL) throws -> URL {
        try base.stage(data, beside: originalURL)
    }

    func replaceItem(at originalURL: URL, with stagedURL: URL) throws {
        try base.replaceItem(at: originalURL, with: stagedURL)
        lock.withLock {
            replacementCount += 1
            if replacementCount == 1 {
                failsNextRead = true
            }
        }
    }

    func removeItemIfPresent(at url: URL) { base.removeItemIfPresent(at: url) }
}

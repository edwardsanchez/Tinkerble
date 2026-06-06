import XCTest
@testable import Tinkerble
@testable import TinkerbleCompanionCore

final class TinkerbleComponentPreviewFixtureTests: XCTestCase {
    func testPreviewFixtureIncludesEveryCompanionComponent() {
        let tweaks = TinkerbleComponentPreviewFixture.tweaks

        XCTAssertEqual(
            tweaks.map(\.id),
            [
                "Text/String Field",
                "Text/String Area",
                "Text/Automatic Text Field",
                "Text/Automatic Text Area",
                "Values/Bool Toggle",
                "Values/Color Picker",
                "Numbers/Number Field",
                "Numbers/Number Slider",
                "Values/Enum Picker",
            ]
        )

        XCTAssertEqual(
            Set(tweaks.map(\.valueKind)),
            [.string, .bool, .color, .number, .enumeration]
        )
        XCTAssertTrue(tweaks.contains { $0.control == .text(.init(style: .field)) })
        XCTAssertTrue(tweaks.contains { $0.control == .text(.init(style: .area)) })
        XCTAssertTrue(tweaks.contains { $0.control == .automatic && $0.valueKind == .bool })
        XCTAssertTrue(tweaks.contains { $0.control == .automatic && $0.valueKind == .color })
        XCTAssertTrue(tweaks.contains { $0.control == .plain(.init(decimalPlaces: 0)) && $0.valueKind == .number })
        XCTAssertTrue(tweaks.contains { $0.control == .slider(.init(minimum: 0, maximum: 1, step: 0.01, decimalPlaces: 2)) })
        XCTAssertTrue(tweaks.contains { $0.valueKind == .enumeration && $0.enumOptions.count == 3 })
    }

    func testAutomaticTextFixturesPreviewFieldAndAreaResolutions() {
        let resolvedAutomaticStyles = TinkerbleComponentPreviewFixture.tweaks.compactMap { tweak -> TinkerbleTextControlStyle? in
            guard case let .text(configuration) = tweak.control,
                  configuration.style == .automatic,
                  case let .string(value) = tweak.value else {
                return nil
            }
            return configuration.resolvedStyle(for: value)
        }

        XCTAssertEqual(Set(resolvedAutomaticStyles), [.field, .area])
    }

    func testPreviewFixtureBuildsScrollableGroups() {
        let groups = TinkerbleComponentPreviewFixture.groups

        XCTAssertEqual(groups.map(\.category), ["Numbers", "Text", "Values"])
        XCTAssertEqual(groups.flatMap(\.tweaks).count, TinkerbleComponentPreviewFixture.tweaks.count)
    }

    func testPreviewPageUsesScrollViewAndVStack() throws {
        let projectRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let previewPage = projectRoot.appending(path: "Sources/TinkerbleCompanionUI/TinkerbleComponentPreviewPageView.swift")
        let source = try String(contentsOf: previewPage, encoding: .utf8)

        XCTAssertTrue(source.contains("private struct TinkerbleComponentPreviewPageView: View"))
        XCTAssertTrue(source.contains("ScrollView {\n            VStack(alignment: .leading, spacing: 0)"))
        XCTAssertTrue(source.contains("#Preview(\"All Tinkerble Components\")"))
    }
}

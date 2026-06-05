import Foundation
import XCTest

final class TinkerbleSwiftUIRuleTests: XCTestCase {
    func testProductionSwiftSourcesDoNotUseBannedSwiftUIPatterns() throws {
        let projectRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let sourceRoots = [
            projectRoot.appending(path: "Sources"),
            projectRoot.appending(path: "Tinkerble Demo"),
        ]
        let bannedSnippets = [
            "ObservableObject",
            "@Published",
            "@StateObject",
            "@ObservedObject",
            "GeometryReader",
            "DispatchQueue.main.async",
            "Task.sleep(nanoseconds:",
            ".foregroundColor(",
            ".cornerRadius(",
            ".tabItem",
            ".fontWeight(",
            "String(format:",
            "replacingOccurrences(",
            "UIGraphicsImageRenderer",
            "UIScreen.main.bounds",
            "AnyView",
            ".easeInOut",
        ]

        let violations = try sourceRoots.flatMap { root in
            try swiftFiles(in: root).flatMap { file in
                let source = try String(contentsOf: file, encoding: .utf8)
                return bannedSnippets.compactMap { snippet -> String? in
                    source.contains(snippet) ? "\(relativePath(for: file, from: projectRoot)): \(snippet)" : nil
                }
            }
        }

        XCTAssertTrue(
            violations.isEmpty,
            "Banned SwiftUI patterns found:\n\(violations.joined(separator: "\n"))"
        )
    }

    private func swiftFiles(in root: URL) throws -> [URL] {
        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        return try enumerator.compactMap { item in
            guard let url = item as? URL, url.pathExtension == "swift" else { return nil }
            let values = try url.resourceValues(forKeys: [.isRegularFileKey])
            return values.isRegularFile == true ? url : nil
        }
    }

    private func relativePath(for file: URL, from projectRoot: URL) -> String {
        String(file.path.dropFirst(projectRoot.path.count + 1))
    }
}

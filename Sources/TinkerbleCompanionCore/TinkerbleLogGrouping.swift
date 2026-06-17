import Foundation
import Tinkerble

public struct TinkerbleLogRow: Equatable, Identifiable {
    public var id: String { latest.valueID }
    public var name: String { latest.name }
    public var displayValue: String { latest.value.displayValue }
    public var latest: TinkerbleLogEntry
    public var history: [TinkerbleLogEntry]

    public init(latest: TinkerbleLogEntry, history: [TinkerbleLogEntry]) {
        self.latest = latest
        self.history = history
    }
}

public struct TinkerbleLogCard: Equatable, Identifiable {
    public var id: String { "\(screen)/\(category)" }
    public var screen: String
    public var category: String
    public var rows: [TinkerbleLogRow]

    public var lastUpdated: Date {
        rows.map(\.latest.date).max() ?? .distantPast
    }

    public var exportFilename: String {
        let baseName = [screen, category]
            .map(Self.sanitizedFilenameComponent)
            .filter { !$0.isEmpty }
            .joined(separator: "-")

        return baseName.isEmpty ? "Tinkerble-Log" : "Tinkerble-\(baseName)-Log"
    }

    public var exportText: String {
        let entries = rows.flatMap(\.history).sorted { $0.date < $1.date }
        let header = "Timestamp\tScreen\tCategory\tName\tValue"
        let body = entries.map { entry in
            [
                Self.exportTimestamp(for: entry.date),
                entry.screen,
                entry.category,
                entry.name,
                entry.value.displayValue
            ]
            .map(Self.escapedTSVField)
            .joined(separator: "\t")
        }

        return ([header] + body).joined(separator: "\n")
    }

    public init(screen: String, category: String, rows: [TinkerbleLogRow]) {
        self.screen = screen
        self.category = category
        self.rows = rows
    }

    private static func exportTimestamp(for date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }

    private static func escapedTSVField(_ field: String) -> String {
        field
            .replacing("\t", with: " ")
            .replacing("\n", with: "\\n")
    }

    private static func sanitizedFilenameComponent(_ component: String) -> String {
        component
            .replacing("/", with: "-")
            .replacing(":", with: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

public enum TinkerbleLogGrouping {
    public static func screens(from entries: [TinkerbleLogEntry]) -> [String] {
        var screens: [String] = []
        for entry in entries where !screens.contains(entry.screen) {
            screens.append(entry.screen)
        }
        return screens
    }

    public static func cards(from entries: [TinkerbleLogEntry], screen: String) -> [TinkerbleLogCard] {
        let screenEntries = entries.filter { $0.screen == screen }
        var categories: [String] = []
        var rowIDsByCategory: [String: [String]] = [:]
        var historyByRowID: [String: [TinkerbleLogEntry]] = [:]

        for entry in screenEntries {
            if !categories.contains(entry.category) {
                categories.append(entry.category)
            }
            if rowIDsByCategory[entry.category] == nil {
                rowIDsByCategory[entry.category] = []
            }
            if rowIDsByCategory[entry.category]?.contains(entry.valueID) == false {
                rowIDsByCategory[entry.category]?.append(entry.valueID)
            }
            historyByRowID[entry.valueID, default: []].append(entry)
        }

        return categories.map { category in
            let rows = rowIDsByCategory[category, default: []].compactMap { rowID -> TinkerbleLogRow? in
                guard let history = historyByRowID[rowID], let latest = history.last else { return nil }
                return TinkerbleLogRow(latest: latest, history: history)
            }
            return TinkerbleLogCard(screen: screen, category: category, rows: rows)
        }
        .filter { !$0.rows.isEmpty }
    }
}

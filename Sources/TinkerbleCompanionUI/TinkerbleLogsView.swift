import AppKit
import SwiftUI
import Tinkerble
import TinkerbleCompanionCore
import UniformTypeIdentifiers

public struct TinkerbleLogsView: View {
    private var logs: [TinkerbleLogEntry]
    @State private var selectedScreen = TinkerbleTweak.defaultScreenName
    @State private var exportDocument = TinkerbleLogExportDocument(text: "")
    @State private var exportFilename = "Tinkerble-Log"
    @State private var isExporting = false

    public init(logs: [TinkerbleLogEntry]) {
        self.logs = logs
    }

    public var body: some View {
        TinkerbleLogContentView(
            screens: screens,
            selectedScreen: $selectedScreen,
            cards: cards,
            copyLog: copyLog,
            exportLog: exportLog
        )
        .frame(minWidth: 360, minHeight: 240)
        .fileExporter(
            isPresented: $isExporting,
            document: exportDocument,
            contentType: .plainText,
            defaultFilename: exportFilename
        ) { _ in }
    }

    private var screens: [String] {
        TinkerbleLogGrouping.screens(from: logs)
    }

    private var activeScreen: String? {
        if screens.contains(selectedScreen) {
            return selectedScreen
        }
        return screens.first
    }

    private var cards: [TinkerbleLogCard] {
        guard let activeScreen else { return [] }
        return TinkerbleLogGrouping.cards(from: logs, screen: activeScreen)
    }

    private func copyLog(_ card: TinkerbleLogCard) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(card.exportText, forType: .string)
    }

    private func exportLog(_ card: TinkerbleLogCard) {
        exportDocument = TinkerbleLogExportDocument(text: card.exportText)
        exportFilename = card.exportFilename
        isExporting = true
    }
}

private struct TinkerbleLogContentView: View {
    var screens: [String]
    @Binding var selectedScreen: String
    var cards: [TinkerbleLogCard]
    var copyLog: (TinkerbleLogCard) -> Void
    var exportLog: (TinkerbleLogCard) -> Void
    @State private var componentWidthCache = TinkerbleLogComponentWidthCache()

    var body: some View {
        VStack(spacing: 0) {
            if screens.count > 1 {
                TinkerbleScreenSegmentedControlView(screens: screens, selectedScreen: $selectedScreen)
                    .padding(.horizontal)
                    .padding(.top)
                    .padding(.bottom, 8)
            }

            if !cards.isEmpty {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(cards) { card in
                            TinkerbleLogCardView(
                                card: card,
                                componentWidthCache: $componentWidthCache,
                                copyLog: copyLog,
                                exportLog: exportLog
                            )
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 12)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

private struct TinkerbleLogCardView: View {
    var card: TinkerbleLogCard
    @Binding var componentWidthCache: TinkerbleLogComponentWidthCache
    var copyLog: (TinkerbleLogCard) -> Void
    var exportLog: (TinkerbleLogCard) -> Void

    var body: some View {
        VStack(spacing: 0) {
            TinkerbleLogCardHeaderView(card: card, copyLog: copyLog, exportLog: exportLog)

            VStack(spacing: 0) {
                ForEach(card.rows) { row in
                    TinkerbleLogRowView(row: row, componentWidthCache: $componentWidthCache)
                }
            }
        }
        .background(Material.regular)
        .clipShape(.rect(cornerRadius: 15))
        .frame(maxWidth: .infinity)
    }
}

private struct TinkerbleLogCardHeaderView: View {
    var card: TinkerbleLogCard
    var copyLog: (TinkerbleLogCard) -> Void
    var exportLog: (TinkerbleLogCard) -> Void

    private static let lastUpdatedFormat = Date.FormatStyle.dateTime
        .hour(.twoDigits(amPM: .omitted))
        .minute(.twoDigits)
        .second(.twoDigits)

    var body: some View {
        HStack(spacing: 8) {
            Text(card.category)
                .bold()
                .lineLimit(1)

            Spacer(minLength: 12)

            Text("Last updated \(card.lastUpdated, format: Self.lastUpdatedFormat)")
                .font(.caption)
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Menu {
                Button("Copy Log", systemImage: "document.on.document") {
                    copyLog(card)
                }
                Button("Export Log", systemImage: "rectangle.portrait.and.arrow.right") {
                    exportLog(card)
                }
            } label: {
                Label("Log actions", systemImage: "ellipsis")
                    .labelStyle(.iconOnly)
            }
            .menuIndicator(.hidden)
            .menuStyle(.borderlessButton)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(.primary.opacity(0.04))
    }
}

private struct TinkerbleLogRowView: View {
    var row: TinkerbleLogRow
    @Binding var componentWidthCache: TinkerbleLogComponentWidthCache

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(row.name)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            TinkerbleLogValueView(entry: row.latest, componentWidthCache: $componentWidthCache)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal)
        .padding(.vertical, 7)
    }
}

private struct TinkerbleLogValueView: View {
    var entry: TinkerbleLogEntry
    @Binding var componentWidthCache: TinkerbleLogComponentWidthCache

    var body: some View {
        switch entry.value {
        case let .color(color):
            TinkerbleLogColorValueView(color: color)
        case let .components(components):
            TinkerbleLogComponentsValueView(
                entry: entry,
                components: components,
                componentWidthCache: $componentWidthCache
            )
        case .string, .int, .double:
            Text(entry.displayValue)
                .monospacedDigit()
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }
}

private struct TinkerbleLogComponentsValueView: View {
    var entry: TinkerbleLogEntry
    var components: [TinkerbleLogNumericComponent]
    @Binding var componentWidthCache: TinkerbleLogComponentWidthCache

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            ForEach(components.indices, id: \.self) { index in
                let component = components[index]
                TinkerbleLogNumericComponentView(
                    rowID: entry.valueID,
                    component: component,
                    decimalPlaces: entry.decimalPlaces,
                    componentWidthCache: $componentWidthCache
                )

                if index < components.index(before: components.endIndex) {
                    TinkerbleLogComponentDividerView()
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
    }
}

private struct TinkerbleLogNumericComponentView: View {
    var rowID: String
    var component: TinkerbleLogNumericComponent
    var decimalPlaces: Int
    @Binding var componentWidthCache: TinkerbleLogComponentWidthCache

    private var widthKey: String {
        TinkerbleLogComponentWidthCache.key(rowID: rowID, componentID: component.id)
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text(component.label)
                .bold()

            HStack(spacing: 0) {
                if component.isNegative {
                    Text("-")
                }

                Text(component.magnitudeDisplayValue(decimalPlaces: decimalPlaces))
                    .monospacedDigit()
            }
            .frame(width: componentWidthCache.width(for: widthKey), alignment: .trailing)
            .background {
                HStack(spacing: 0) {
                    if component.isNegative {
                        Text("-")
                    }

                    Text(component.magnitudeDisplayValue(decimalPlaces: decimalPlaces))
                        .monospacedDigit()
                }
                .fixedSize(horizontal: true, vertical: false)
                .hidden()
                .onGeometryChange(for: CGFloat.self) { proxy in
                    proxy.size.width
                } action: { width in
                    componentWidthCache.record(width: width, for: widthKey)
                }
            }
        }
        .lineLimit(1)
    }
}

private struct TinkerbleLogExportDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.plainText] }

    var text: String

    init(text: String) {
        self.text = text
    }

    init(configuration: ReadConfiguration) throws {
        if let data = configuration.file.regularFileContents,
           let text = String(data: data, encoding: .utf8) {
            self.text = text
        } else {
            text = ""
        }
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(text.utf8))
    }
}

#Preview("Logs") {
    TinkerbleLogsView(logs: [
        .init(screen: "Cards", category: "Deck", name: "Visible Cards", value: 7),
        .init(screen: "Cards", category: "Deck", name: "Selected Suit", value: "Hearts"),
        .init(screen: "Cards", category: nil, name: "FPS", value: 58.8),
        .init(
            screen: "Cards",
            category: "Color",
            name: "Resolved Color",
            value: TinkerbleColor(red: 1, green: 0.31, blue: 0.64)
        ),
        .init(
            screen: "Cards",
            category: "Motion",
            name: "Position",
            value: CGPoint(x: 24.5, y: -128.75)
        ),
        .init(screen: "Scroll View", category: "Offsets", name: "Y Offset", value: 184.5)
    ])
}

#Preview("Empty Logs") {
    TinkerbleLogsView(logs: [])
}

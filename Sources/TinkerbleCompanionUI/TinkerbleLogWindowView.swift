import AppKit
import SwiftUI
import Tinkerble

public struct TinkerbleLogWindowView: View {
    private var logs: [TinkerbleLogEntry]

    public init(logs: [TinkerbleLogEntry]) {
        self.logs = logs
    }

    public var body: some View {
        TinkerbleLogsView(logs: logs)
            .background {
                HudMaterialBackground()
                    .ignoresSafeArea()
                    .overlay {
                        Rectangle()
                            .fill(.black.opacity(0.4))
                            .ignoresSafeArea()
                    }
            }
            .background(TinkerbleLogWindowConfigurator())
            .preferredColorScheme(.dark)
    }
}

private struct TinkerbleLogWindowConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        Task { @MainActor in
            configure(view.window)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        Task { @MainActor in
            configure(nsView.window)
        }
    }

    private func configure(_ window: NSWindow?) {
        guard let window else { return }

        window.title = "Tinkerble Logs"
        window.titlebarAppearsTransparent = true
        window.isOpaque = false
        window.backgroundColor = .clear
        window.appearance = NSAppearance(named: .darkAqua)
        window.styleMask.insert(.titled)
        window.styleMask.insert(.resizable)
        window.styleMask.insert(.fullSizeContentView)
        window.styleMask.insert(.hudWindow)
    }
}

#Preview("Log Window") {
    TinkerbleLogWindowView(logs: [
        .init(screen: "Cards", category: "Deck", name: "Visible Cards", value: 7),
        .init(screen: "Cards", category: "Deck", name: "Selected Suit", value: "Hearts"),
        .init(screen: "Cards", category: nil, name: "Dock Size", value: 362),
        .init(screen: "Scroll View", category: "Offsets", name: "Y Offset", value: 184.5)
    ])
}

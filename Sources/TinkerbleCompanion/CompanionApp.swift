import AppKit
import Observation
import SwiftUI
import TinkerbleCompanionCore
import TinkerbleCompanionUI

@main
@MainActor
struct TinkerbleCompanionApp: App {
    @NSApplicationDelegateAdaptor(CompanionAppDelegate.self) private var appDelegate
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow
    @State private var store: TinkerbleCompanionStore
    @State private var windowLevel = HudWindowLevelState()
    @State private var logWindowPresentation = TinkerbleLogWindowPresentationState()
    private let launchMode: CompanionLaunchMode

    init() {
        let store = TinkerbleCompanionStore(versionRepository: Self.makeVersionRepository())
        _store = State(wrappedValue: store)
        launchMode = CompanionLaunchMode(arguments: ProcessInfo.processInfo.arguments)
        if launchMode == .companion {
            store.start()
        }
    }

    var body: some Scene {
        WindowGroup {
            switch launchMode {
            case .companion:
                CompanionRootView(
                    store: store,
                    keepsWindowOnTop: windowLevel.keepsWindowOnTop
                )
                .onChange(of: store.logs.count, initial: true) { _, logCount in
                    if logWindowPresentation.shouldCloseLogsWindow(logCount: logCount) {
                        dismissWindow(id: "logs")
                    } else if logWindowPresentation.shouldOpenLogsWindow(logCount: logCount) {
                        openWindow(id: "logs")
                    }
                }
            case .allComponents:
                TinkerbleComponentPreviewPageView()
            }
        }
        .defaultSize(
            width: TinkerbleCompanionWindowLayout.width,
            height: TinkerbleCompanionWindowLayout.idealMaximumHeight
        )
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandGroup(replacing: .undoRedo) {
                Button("Undo") {
                    store.undo()
                }
                .keyboardShortcut("z", modifiers: .command)
                .disabled(!store.canUndo)

                Button("Redo") {
                    store.redo()
                }
                .keyboardShortcut("z", modifiers: [.command, .shift])
                .disabled(!store.canRedo)
            }
            CommandGroup(replacing: .pasteboard) {
                Button("Copy") {
                    NSApp.sendAction(#selector(NSText.copy(_:)), to: nil, from: nil)
                }
                .keyboardShortcut("c", modifiers: .command)
            }
            CommandGroup(replacing: .textEditing) {
                Button("Select All") {
                    NSApp.sendAction(#selector(NSResponder.selectAll(_:)), to: nil, from: nil)
                }
                .keyboardShortcut("a", modifiers: .command)
            }
            CommandGroup(replacing: .textFormatting) {}
            CommandGroup(replacing: .toolbar) {}
            CommandGroup(replacing: .help) {}
            CommandGroup(after: .windowArrangement) {
                Toggle("Keep Window on Top", isOn: $windowLevel.keepsWindowOnTop)
            }
        }

        Window("Tinkerble Logs", id: "logs") {
            TinkerbleLogWindowView(logs: store.logs)
                .onChange(of: store.logs.count, initial: true) { _, logCount in
                    if logWindowPresentation.shouldCloseLogsWindow(logCount: logCount) {
                        dismissWindow(id: "logs")
                    }
                }
        }
        .defaultSize(width: 640, height: 480)
        .restorationBehavior(.disabled)
    }

    private static func makeVersionRepository() -> any TinkerbleVersionRepository {
        do {
            return try TinkerbleSwiftDataVersionRepository()
        } catch {
            return TinkerbleInMemoryVersionRepository()
        }
    }
}

private enum CompanionLaunchMode: Equatable {
    case companion
    case allComponents

    init(arguments: [String]) {
        self = arguments.contains("--all-components") ? .allComponents : .companion
    }
}

@Observable
@MainActor
private final class HudWindowLevelState {
    var keepsWindowOnTop = false
}

private final class CompanionAppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillFinishLaunching(_ notification: Notification) {
        NSApp.appearance = NSAppearance(named: .darkAqua)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        applyMenuPolicy()

        Task { @MainActor in
            await Task.yield()
            applyMenuPolicy()
        }
    }

    func applicationDidUpdate(_ notification: Notification) {
        applyMenuPolicy()
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        false
    }

    func applicationShouldSaveApplicationState(_ app: NSApplication, coder: NSCoder) -> Bool {
        false
    }

    func applicationShouldRestoreApplicationState(_ app: NSApplication, coder: NSCoder) -> Bool {
        false
    }

    private func applyMenuPolicy() {
        TinkerbleCompanionMenuPolicy.apply(to: NSApp.mainMenu)
    }
}

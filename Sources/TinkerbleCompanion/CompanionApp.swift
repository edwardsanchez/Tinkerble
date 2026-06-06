import AppKit
import Observation
import SwiftUI
import TinkerbleCompanionCore
import TinkerbleCompanionUI

@main
@MainActor
struct TinkerbleCompanionApp: App {
    @NSApplicationDelegateAdaptor(CompanionAppDelegate.self) private var appDelegate
    @State private var store: TinkerbleCompanionStore
    @State private var windowLevel = HudWindowLevelState()

    init() {
        let store = TinkerbleCompanionStore()
        _store = State(wrappedValue: store)
        store.start()
    }

    var body: some Scene {
        WindowGroup {
            CompanionRootView(
                store: store,
                keepsWindowOnTop: windowLevel.keepsWindowOnTop
            )
        }
        .defaultSize(
            width: TinkerbleCompanionWindowLayout.width,
            height: TinkerbleCompanionWindowLayout.idealMaximumHeight
        )
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandGroup(replacing: .undoRedo) {}
            CommandGroup(replacing: .pasteboard) {}
            CommandGroup(replacing: .textEditing) {}
            CommandGroup(replacing: .textFormatting) {}
            CommandGroup(replacing: .toolbar) {}
            CommandGroup(replacing: .help) {}
            CommandGroup(after: .windowArrangement) {
                Toggle("Keep Window on Top", isOn: $windowLevel.keepsWindowOnTop)
            }
        }
    }
}

@Observable
@MainActor
private final class HudWindowLevelState {
    var keepsWindowOnTop = false
}

private final class CompanionAppDelegate: NSObject, NSApplicationDelegate {
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

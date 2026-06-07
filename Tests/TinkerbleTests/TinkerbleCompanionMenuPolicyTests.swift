import AppKit
@testable import TinkerbleCompanionUI
import XCTest

final class TinkerbleCompanionMenuPolicyTests: XCTestCase {
    @MainActor
    func testMenuPolicyRemovesUnwantedMenusAndKeepsWindowMenu() {
        let menu = NSMenu()
        let appMenu = NSMenu(title: "Tinkerble")
        let fileMenu = NSMenu(title: "File")
        let editMenu = NSMenu(title: "Edit")
        let formatMenu = NSMenu(title: "Format")
        let viewMenu = NSMenu(title: "View")
        let windowMenu = NSMenu(title: "Window")
        let helpMenu = NSMenu(title: "Help")

        fileMenu.addItem(withTitle: "New Window", action: nil, keyEquivalent: "n")
        fileMenu.addItem(.separator())
        fileMenu.addItem(withTitle: "Close", action: nil, keyEquivalent: "w")
        windowMenu.addItem(withTitle: "Minimize", action: nil, keyEquivalent: "m")
        windowMenu.addItem(withTitle: "Keep Window on Top", action: nil, keyEquivalent: "")

        menu.addItem(menuItem(title: "Tinkerble", submenu: appMenu))
        menu.addItem(menuItem(title: "File", submenu: fileMenu))
        menu.addItem(menuItem(title: "Edit", submenu: editMenu))
        menu.addItem(menuItem(title: "Format", submenu: formatMenu))
        menu.addItem(menuItem(title: "View", submenu: viewMenu))
        menu.addItem(menuItem(title: "Window", submenu: windowMenu))
        menu.addItem(menuItem(title: "Help", submenu: helpMenu))

        TinkerbleCompanionMenuPolicy.apply(to: menu)

        XCTAssertEqual(menu.items.map(\.title), ["Tinkerble", "File", "Window"])
        XCTAssertEqual(fileMenu.items.map(\.title), ["Close"])
        XCTAssertEqual(windowMenu.items.map(\.title), ["Minimize", "Keep Window on Top"])
    }

    func testCompanionAppAppliesMenuPolicyAndReplacesDefaultCommandGroups() throws {
        let source = try readText("Sources/TinkerbleCompanion/CompanionApp.swift")

        XCTAssertTrue(source.contains("CompanionLaunchMode(arguments: ProcessInfo.processInfo.arguments)"))
        XCTAssertTrue(source.contains("arguments.contains(\"--all-components\")"))
        XCTAssertTrue(source.contains("TinkerbleComponentPreviewPageView()"))
        XCTAssertTrue(source.contains("NSApp.appearance = NSAppearance(named: .darkAqua)"))
        XCTAssertTrue(source.contains("TinkerbleCompanionMenuPolicy.apply(to: NSApp.mainMenu)"))
        XCTAssertTrue(source.contains("CommandGroup(replacing: .newItem) {}"))
        XCTAssertTrue(source.contains("CommandGroup(replacing: .undoRedo) {}"))
        XCTAssertTrue(source.contains("CommandGroup(replacing: .pasteboard) {}"))
        XCTAssertTrue(source.contains("CommandGroup(replacing: .textEditing) {}"))
        XCTAssertTrue(source.contains("CommandGroup(replacing: .textFormatting) {}"))
        XCTAssertTrue(source.contains("CommandGroup(replacing: .toolbar) {}"))
        XCTAssertTrue(source.contains("CommandGroup(replacing: .help) {}"))
        XCTAssertTrue(source.contains("CommandGroup(after: .windowArrangement)"))
    }

    private func menuItem(title: String, submenu: NSMenu) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.submenu = submenu
        return item
    }

    private func readText(_ relativePath: String) throws -> String {
        try String(
            contentsOf: repoRoot.appending(path: relativePath),
            encoding: .utf8
        )
    }

    private var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}

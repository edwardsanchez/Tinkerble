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
        editMenu.addItem(withTitle: "Undo", action: nil, keyEquivalent: "z")
        editMenu.addItem(withTitle: "Redo", action: nil, keyEquivalent: "Z")
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: "AutoFill", action: nil, keyEquivalent: "")
        editMenu.addItem(withTitle: "Start Dictation…", action: nil, keyEquivalent: "")
        editMenu.addItem(withTitle: "Emoji & Symbols", action: nil, keyEquivalent: "")
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

        XCTAssertEqual(menu.items.map(\.title), ["Tinkerble", "File", "Edit", "Window"])
        XCTAssertEqual(fileMenu.items.map(\.title), ["Close"])
        XCTAssertEqual(editMenu.items.map(\.title), ["Undo", "Redo"])
        XCTAssertEqual(windowMenu.items.map(\.title), ["Minimize", "Keep Window on Top"])
    }

    private func menuItem(title: String, submenu: NSMenu) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.submenu = submenu
        return item
    }
}

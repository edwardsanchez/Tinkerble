import AppKit

public enum TinkerbleCompanionMenuPolicy {
    static let hiddenTopLevelMenuTitles: Set<String> = [
        "Format",
        "View",
        "Help",
    ]

    static let hiddenMenuItemTitles: Set<String> = [
        "AutoFill",
        "Emoji & Symbols",
        "New Window",
        "Start Dictation",
    ]

    public static func apply(to mainMenu: NSMenu?) {
        guard let mainMenu else { return }

        for item in mainMenu.items where hiddenTopLevelMenuTitles.contains(normalizedTitle(item.title)) {
            mainMenu.removeItem(item)
        }

        for item in mainMenu.items {
            pruneHiddenItems(in: item.submenu)
        }
    }

    private static func pruneHiddenItems(in menu: NSMenu?) {
        guard let menu else { return }

        for item in menu.items {
            if hiddenMenuItemTitles.contains(normalizedTitle(item.title)) {
                menu.removeItem(item)
            } else {
                pruneHiddenItems(in: item.submenu)
            }
        }

        removeStraySeparators(from: menu)
    }

    private static func removeStraySeparators(from menu: NSMenu) {
        while menu.items.first?.isSeparatorItem == true {
            menu.removeItem(at: 0)
        }

        while menu.items.last?.isSeparatorItem == true {
            menu.removeItem(at: menu.items.count - 1)
        }

        var previousWasSeparator = false
        for item in menu.items {
            if item.isSeparatorItem, previousWasSeparator {
                menu.removeItem(item)
            }
            previousWasSeparator = item.isSeparatorItem
        }
    }

    private static func normalizedTitle(_ title: String) -> String {
        title
            .replacing("…", with: "")
            .replacing("...", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

import Foundation

/// The single ordering rule for controls, shared by the app registry and the companion.
///
/// Screens are ordered by name. Within a screen:
/// 1. Uncategorized controls come first.
/// 2. Controls are ordered by where they are declared: file path, then line, then column.
///    A control with several source anchors uses its earliest one; an action uses
///    `declarationLocation`.
/// 3. Categories are ordered by their earliest declared control, and their controls follow rule 2.
/// 4. Controls (and categories) with no known location go after located ones, by name.
public enum TinkerbleTweakOrdering {
    public static func sorted(_ tweaks: some Sequence<TinkerbleTweak>) -> [TinkerbleTweak] {
        let entriesByScreen = Dictionary(grouping: tweaks.map(Entry.init), by: \.tweak.screen)
        return entriesByScreen.keys
            .sorted(by: isScreenOrderedBefore)
            .flatMap { screen in orderedWithinScreen(entriesByScreen[screen] ?? []) }
    }

    /// The earliest place a control is declared, or `nil` when it carries no location.
    public static func earliestLocation(of tweak: TinkerbleTweak) -> TinkerbleSourceLocation? {
        (tweak.sourceAnchors.map(\.location) + [tweak.declarationLocation].compactMap(\.self)).min()
    }

    private static func orderedWithinScreen(_ entries: [Entry]) -> [TinkerbleTweak] {
        let uncategorized = entries
            .filter { $0.tweak.category == nil }
            .sorted { $0.key.isOrdered(before: $1.key) }
        let categories = Dictionary(grouping: entries.filter { $0.tweak.category != nil }) { $0.tweak.category ?? "" }
            .map { category, members in
                CategoryEntry(name: category, members: members.sorted { $0.key.isOrdered(before: $1.key) })
            }
            .sorted { $0.key.isOrdered(before: $1.key) }

        return uncategorized.map(\.tweak) + categories.flatMap { $0.members.map(\.tweak) }
    }

    private static func isScreenOrderedBefore(_ left: String, _ right: String) -> Bool {
        let comparison = left.localizedCaseInsensitiveCompare(right)
        return comparison == .orderedSame ? left < right : comparison == .orderedAscending
    }

    private struct SortKey {
        var location: TinkerbleSourceLocation?
        var name: String
        var tiebreaker: String

        func isOrdered(before other: SortKey) -> Bool {
            switch (location, other.location) {
            case let (left?, right?) where left != right:
                return left < right
            case (_?, nil):
                return true
            case (nil, _?):
                return false
            default:
                let comparison = name.localizedCaseInsensitiveCompare(other.name)
                if comparison != .orderedSame {
                    return comparison == .orderedAscending
                }
                return (name, tiebreaker) < (other.name, other.tiebreaker)
            }
        }
    }

    private struct Entry {
        var tweak: TinkerbleTweak
        var key: SortKey

        init(_ tweak: TinkerbleTweak) {
            self.tweak = tweak
            key = .init(
                location: TinkerbleTweakOrdering.earliestLocation(of: tweak),
                name: tweak.name,
                tiebreaker: tweak.id
            )
        }
    }

    private struct CategoryEntry {
        var members: [Entry]
        var key: SortKey

        /// `members` must already be sorted, so the first member holds the category's earliest location.
        init(name: String, members: [Entry]) {
            self.members = members
            key = .init(location: members.first?.key.location, name: name, tiebreaker: name)
        }
    }
}

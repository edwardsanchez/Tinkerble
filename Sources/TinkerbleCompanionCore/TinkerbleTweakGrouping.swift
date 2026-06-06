import Foundation
import Tinkerble

public enum TinkerbleTweakGrouping {
    public static func groupedTweaks(from tweaks: [TinkerbleTweak]) -> [TinkerbleTweakGroup] {
        let uncategorized = tweaks.filter { $0.category == nil }
        let categorized = Dictionary(grouping: tweaks.filter { $0.category != nil }, by: \.category)

        var groups: [TinkerbleTweakGroup] = []
        if !uncategorized.isEmpty {
            groups.append(.init(category: nil, tweaks: uncategorized))
        }

        groups.append(
            contentsOf: categorized.keys.compactMap { category -> TinkerbleTweakGroup? in
                guard let category else { return nil }
                return TinkerbleTweakGroup(
                    category: category,
                    tweaks: categorized[category] ?? []
                )
            }
            .sorted { $0.category ?? "" < $1.category ?? "" }
        )

        return groups
    }
}

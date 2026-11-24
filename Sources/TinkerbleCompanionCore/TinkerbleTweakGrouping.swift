import Foundation
import Tinkerble

public enum TinkerbleTweakGrouping {
    /// Groups tweaks into the uncategorized group followed by one group per category.
    /// Order comes from `TinkerbleTweakOrdering`: categories by their first declared control.
    public static func groupedTweaks(from tweaks: [TinkerbleTweak]) -> [TinkerbleTweakGroup] {
        let orderedTweaks = TinkerbleTweakOrdering.sorted(tweaks)
        let uncategorized = orderedTweaks.filter { $0.category == nil }

        var categorizedGroups: [TinkerbleTweakGroup] = []
        var groupIndexByCategory: [String: Int] = [:]
        for tweak in orderedTweaks {
            guard let category = tweak.category else { continue }
            if let index = groupIndexByCategory[category] {
                categorizedGroups[index].tweaks.append(tweak)
            } else {
                groupIndexByCategory[category] = categorizedGroups.count
                categorizedGroups.append(.init(category: category, tweaks: [tweak]))
            }
        }

        return (uncategorized.isEmpty ? [] : [.init(category: nil, tweaks: uncategorized)]) + categorizedGroups
    }
}

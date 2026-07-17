import Foundation

@MainActor
public protocol TinkerbleAutoApplyPreference: AnyObject {
    var isEnabled: Bool { get set }
}

@MainActor
public final class TinkerbleUserDefaultsAutoApplyPreference: TinkerbleAutoApplyPreference {
    private static let isEnabledKey = "TinkerbleAutoApplyEnabled"

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public var isEnabled: Bool {
        get { defaults.bool(forKey: Self.isEnabledKey) }
        set { defaults.set(newValue, forKey: Self.isEnabledKey) }
    }
}

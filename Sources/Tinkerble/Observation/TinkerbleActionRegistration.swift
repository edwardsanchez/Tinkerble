import Foundation

@MainActor
public final class TinkerbleActionRegistration {
    private var registrationToken: TinkerbleRegistrationToken?
    private var isRegistered = false

    public init() {}

    deinit {
        if let registrationToken {
            Task { @MainActor in
                Tinkerble.shared.unregister(registrationToken)
            }
        }
    }

    public func activate<Owner: AnyObject>(
        owner: Owner,
        name: String,
        screen: String? = nil,
        category: String? = nil,
        perform: @escaping (Owner) -> Void
    ) {
        guard !isRegistered else { return }

        isRegistered = true
        registrationToken = Tinkerble.shared.registerAction(
            id: TinkerbleTweak.makeID(screen: screen, category: category, name: name),
            screen: screen,
            category: category,
            name: name,
            perform: { [weak owner] in
                guard let owner else { return }
                perform(owner)
            }
        )
    }

    public func activate<Owner: AnyObject>(
        owner: Owner,
        category: String,
        name: String,
        screen: String? = nil,
        perform: @escaping (Owner) -> Void
    ) {
        activate(owner: owner, name: name, screen: screen, category: category, perform: perform)
    }

    public func activate<Owner: AnyObject>(
        owner: Owner,
        _ category: String,
        name: String,
        screen: String? = nil,
        perform: @escaping (Owner) -> Void
    ) {
        activate(owner: owner, name: name, screen: screen, category: category, perform: perform)
    }
}

import Foundation

@MainActor
public final class TinkerbleObservableStateRegistration {
    private var id: String?
    private var isRegistered = false
    private var isApplyingRemoteValue = false
    private var registrationToken: TinkerbleRegistrationToken?

    public init() {}

    deinit {
        if let registrationToken {
            Task { @MainActor in
                Tinkerble.shared.unregister(registrationToken)
            }
        }
    }

    public func activate<Owner: AnyObject, Value: TinkerbleValueConvertible>(
        owner: Owner,
        initialValue: Value,
        name: String,
        category: String? = nil,
        control: TinkerbleControl<Value> = .automatic,
        applyRemoteValue: @escaping (Owner, Value) -> Void
    ) {
        guard !isRegistered else { return }

        let id = Self.makeID(category: category, name: name)
        self.id = id
        isRegistered = true

        registrationToken = Tinkerble.shared.register(
            id: id,
            category: category,
            name: name,
            value: initialValue,
            control: control,
            applyRemoteValue: { [weak self, weak owner] newValue in
                guard let self, let owner else { return }
                self.isApplyingRemoteValue = true
                applyRemoteValue(owner, newValue)
                self.isApplyingRemoteValue = false
            }
        )
    }

    public func activate<Owner: AnyObject, Value: TinkerbleValueConvertible>(
        owner: Owner,
        initialValue: Value,
        category: String,
        name: String,
        control: TinkerbleControl<Value> = .automatic,
        applyRemoteValue: @escaping (Owner, Value) -> Void
    ) {
        activate(
            owner: owner,
            initialValue: initialValue,
            name: name,
            category: category,
            control: control,
            applyRemoteValue: applyRemoteValue
        )
    }

    public func activate<Owner: AnyObject, Value: TinkerbleValueConvertible>(
        owner: Owner,
        initialValue: Value,
        _ category: String,
        name: String,
        control: TinkerbleControl<Value> = .automatic,
        applyRemoteValue: @escaping (Owner, Value) -> Void
    ) {
        activate(
            owner: owner,
            initialValue: initialValue,
            name: name,
            category: category,
            control: control,
            applyRemoteValue: applyRemoteValue
        )
    }

    public func updateLocalValue<Value: TinkerbleValueConvertible>(_ value: Value) {
        guard let id, !isApplyingRemoteValue else { return }
        Tinkerble.shared.updateLocalValue(id: id, value: value)
    }

    private static func makeID(category: String?, name: String) -> String {
        let normalizedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let category = category?.trimmingCharacters(in: .whitespacesAndNewlines),
              !category.isEmpty
        else {
            return normalizedName
        }
        return "\(category)/\(normalizedName)"
    }
}

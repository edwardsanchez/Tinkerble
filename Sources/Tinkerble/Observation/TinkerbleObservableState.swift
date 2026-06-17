import Foundation
import Observation

@MainActor
public final class TinkerbleObservableStateRegistration {
#if DEBUG
    private var id: String?
    private var isRegistered = false
    private var isApplyingRemoteValue = false
    private var lastObservedValue: TinkerbleValue?
    private var trackedValueReader: (() -> TinkerbleValue)?
    private var trackedValueObserver: (() -> Void)?
    private var registrationToken: TinkerbleRegistrationToken?
#endif

    public init() {}

#if DEBUG
    deinit {
        if let registrationToken {
            Task { @MainActor in
                Tinkerble.shared.unregister(registrationToken)
            }
        }
    }
#endif

    public func activate<Owner: AnyObject, Value: TinkerbleValueConvertible>(
        owner: Owner,
        initialValue: Value,
        name: String,
        screen: String? = nil,
        category: String? = nil,
        control: TinkerbleControl<Value> = .automatic,
        readValue: ((Owner) -> Value)? = nil,
        applyRemoteValue: @escaping (Owner, Value) -> Void
    ) {
#if DEBUG
        guard !isRegistered else { return }

        let id = TinkerbleTweak.makeID(screen: screen, category: category, name: name)
        self.id = id
        isRegistered = true
        lastObservedValue = initialValue.tinkerbleValue

        registrationToken = Tinkerble.shared.register(
            id: id,
            screen: screen,
            category: category,
            name: name,
            value: initialValue,
            control: control,
            applyRemoteValue: { [weak self, weak owner] newValue in
                guard let self, let owner else { return }
                self.isApplyingRemoteValue = true
                self.lastObservedValue = newValue.tinkerbleValue
                applyRemoteValue(owner, newValue)
                self.isApplyingRemoteValue = false
            }
        )

        if let readValue {
            trackedValueReader = { [weak owner] in
                guard let owner else { return initialValue.tinkerbleValue }
                return readValue(owner).tinkerbleValue
            }
            trackedValueObserver = { [weak self, weak owner] in
                guard let self, let owner else { return }
                self.observe(owner: owner, readValue: readValue)
            }
            observe(owner: owner, readValue: readValue)
        }
#else
        _ = owner
        _ = initialValue
        _ = name
        _ = screen
        _ = category
        _ = control
        _ = readValue
        _ = applyRemoteValue
#endif
    }

    public func activate<Owner: AnyObject, Value: TinkerbleValueConvertible>(
        owner: Owner,
        initialValue: Value,
        category: String,
        name: String,
        screen: String? = nil,
        control: TinkerbleControl<Value> = .automatic,
        readValue: ((Owner) -> Value)? = nil,
        applyRemoteValue: @escaping (Owner, Value) -> Void
    ) {
        activate(
            owner: owner,
            initialValue: initialValue,
            name: name,
            screen: screen,
            category: category,
            control: control,
            readValue: readValue,
            applyRemoteValue: applyRemoteValue
        )
    }

    public func activate<Owner: AnyObject, Value: TinkerbleValueConvertible>(
        owner: Owner,
        initialValue: Value,
        _ category: String,
        name: String,
        screen: String? = nil,
        control: TinkerbleControl<Value> = .automatic,
        readValue: ((Owner) -> Value)? = nil,
        applyRemoteValue: @escaping (Owner, Value) -> Void
    ) {
        activate(
            owner: owner,
            initialValue: initialValue,
            name: name,
            screen: screen,
            category: category,
            control: control,
            readValue: readValue,
            applyRemoteValue: applyRemoteValue
        )
    }

    public func updateLocalValue<Value: TinkerbleValueConvertible>(_ value: Value) {
#if DEBUG
        updateLocalTinkerbleValue(value.tinkerbleValue)
#else
        _ = value
#endif
    }

#if DEBUG
    private func updateLocalTinkerbleValue(_ value: TinkerbleValue) {
        guard let id, !isApplyingRemoteValue else { return }
        guard value != lastObservedValue else { return }
        lastObservedValue = value
        Tinkerble.shared.updateLocalValue(id: id, value: value)
    }

    private func handleObservedChange() {
        guard isRegistered, let trackedValueReader else { return }
        updateLocalTinkerbleValue(trackedValueReader())
        trackedValueObserver?()
    }

    private func observe<Owner: AnyObject, Value: TinkerbleValueConvertible>(
        owner: Owner,
        readValue: @escaping (Owner) -> Value
    ) {
        withObservationTracking {
            _ = readValue(owner)
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                self?.handleObservedChange()
            }
        }
    }
#endif
}

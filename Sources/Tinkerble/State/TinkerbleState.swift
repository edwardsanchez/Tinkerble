import Foundation
import Observation
import SwiftUI

#if DEBUG
@Observable
@MainActor
final class TinkerbleStateBox<Value: TinkerbleValueConvertible> {
    var value: Value

    @ObservationIgnored
    private let id: String
    @ObservationIgnored
    private var registrationToken: TinkerbleRegistrationToken?

    init(
        initialValue: Value,
        screen: String? = nil,
        category: String?,
        name: String,
        control: TinkerbleControl<Value>,
        sourceAnchor: TinkerbleSourceAnchor? = nil
    ) {
        self.value = initialValue
        self.id = TinkerbleTweak.makeID(screen: screen, category: category, name: name)

        registrationToken = Tinkerble.shared.register(
            id: id,
            screen: screen,
            category: category,
            name: name,
            value: initialValue,
            control: control,
            sourceAnchor: sourceAnchor,
            applyRemoteValue: { [weak self] newValue in
                self?.value = newValue
            }
        )
    }

    deinit {
        if let registrationToken {
            Task { @MainActor in
                Tinkerble.shared.unregister(registrationToken)
            }
        }
    }

    func set(_ newValue: Value) {
        value = newValue
        Tinkerble.shared.updateLocalValue(id: id, value: newValue)
    }

}
#endif

@propertyWrapper
@MainActor
public struct TinkerbleState<Value: TinkerbleValueConvertible>: DynamicProperty {
    private let initialValue: Value

#if DEBUG
    @State private var box: TinkerbleStateBox<Value>
#else
    @State private var storage: Value
#endif

    /// Preserves property-wrapper backing assignment semantics for the `@TinkerbleState` macro.
    public var _tinkerbleInitializationValue: Value {
        initialValue
    }

#if DEBUG
    public var wrappedValue: Value {
        get { box.value }
        nonmutating set { box.set(newValue) }
    }
#else
    public var wrappedValue: Value {
        get { storage }
        nonmutating set { storage = newValue }
    }
#endif

#if DEBUG
    public var projectedValue: Binding<Value> {
        Binding(
            get: { box.value },
            set: { box.set($0) }
        )
    }
#else
    public var projectedValue: Binding<Value> {
        $storage
    }
#endif

    public init(
        wrappedValue: Value,
        _ name: String,
        screen: String? = nil,
        category: String? = nil,
        control: TinkerbleControl<Value> = .automatic,
        _sourceAnchor: TinkerbleSourceAnchor? = nil
    ) {
        initialValue = wrappedValue
#if DEBUG
        _box = State(
            wrappedValue: TinkerbleStateBox(
                initialValue: wrappedValue,
                screen: screen,
                category: category,
                name: name,
                control: control,
                sourceAnchor: _sourceAnchor
            )
        )
#else
        _ = name
        _ = screen
        _ = category
        _ = control
        _ = _sourceAnchor
        _storage = State(wrappedValue: wrappedValue)
#endif
    }

    @available(*, deprecated, message: "Use @TinkerbleState(\"Name\", screen: ..., category: ...) instead.")
    public init(
        wrappedValue: Value,
        name: String,
        screen: String? = nil,
        category: String? = nil,
        control: TinkerbleControl<Value> = .automatic,
        _sourceAnchor: TinkerbleSourceAnchor? = nil
    ) {
        self.init(
            wrappedValue: wrappedValue,
            name,
            screen: screen,
            category: category,
            control: control,
            _sourceAnchor: _sourceAnchor
        )
    }

    @available(*, deprecated, message: "Use @TinkerbleState(\"Name\", category: \"Category\") instead.")
    public init(
        wrappedValue: Value,
        category: String,
        name: String,
        screen: String? = nil,
        control: TinkerbleControl<Value> = .automatic,
        _sourceAnchor: TinkerbleSourceAnchor? = nil
    ) {
        self.init(
            wrappedValue: wrappedValue,
            name,
            screen: screen,
            category: category,
            control: control,
            _sourceAnchor: _sourceAnchor
        )
    }

    @available(*, deprecated, message: "Use @TinkerbleState(\"Name\", category: \"Category\"). The unlabeled argument is now the tweak name.")
    public init(
        wrappedValue: Value,
        _ category: String,
        name: String,
        screen: String? = nil,
        control: TinkerbleControl<Value> = .automatic,
        _sourceAnchor: TinkerbleSourceAnchor? = nil
    ) {
        self.init(
            wrappedValue: wrappedValue,
            name,
            screen: screen,
            category: category,
            control: control,
            _sourceAnchor: _sourceAnchor
        )
    }
}

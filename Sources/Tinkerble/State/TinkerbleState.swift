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

    init(initialValue: Value, screen: String? = nil, category: String?, name: String, control: TinkerbleControl<Value>) {
        self.value = initialValue
        self.id = TinkerbleTweak.makeID(screen: screen, category: category, name: name)

        registrationToken = Tinkerble.shared.register(
            id: id,
            screen: screen,
            category: category,
            name: name,
            value: initialValue,
            control: control,
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
#if DEBUG
    @State private var box: TinkerbleStateBox<Value>
#else
    @State private var storage: Value
#endif

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
        name: String,
        screen: String? = nil,
        category: String? = nil,
        control: TinkerbleControl<Value> = .automatic
    ) {
#if DEBUG
        _box = State(
            wrappedValue: TinkerbleStateBox(
                initialValue: wrappedValue,
                screen: screen,
                category: category,
                name: name,
                control: control
            )
        )
#else
        _ = name
        _ = screen
        _ = category
        _ = control
        _storage = State(wrappedValue: wrappedValue)
#endif
    }

    public init(
        wrappedValue: Value,
        category: String,
        name: String,
        screen: String? = nil,
        control: TinkerbleControl<Value> = .automatic
    ) {
        self.init(wrappedValue: wrappedValue, name: name, screen: screen, category: category, control: control)
    }

    public init(
        wrappedValue: Value,
        _ category: String,
        name: String,
        screen: String? = nil,
        control: TinkerbleControl<Value> = .automatic
    ) {
        self.init(wrappedValue: wrappedValue, name: name, screen: screen, category: category, control: control)
    }
}

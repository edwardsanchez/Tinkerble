import Combine
import Foundation
import SwiftUI

@MainActor
final class TinkerbleStateBox<Value: TinkerbleValueConvertible>: ObservableObject {
    @Published var value: Value

    private let id: String

    init(initialValue: Value, category: String?, name: String, control: TinkerbleControl<Value>) {
        self.value = initialValue
        self.id = Self.makeID(category: category, name: name)

        Tinkerble.shared.register(
            id: id,
            category: category,
            name: name,
            value: initialValue,
            control: control,
            applyRemoteValue: { [weak self] newValue in
                self?.value = newValue
            }
        )
    }

    func set(_ newValue: Value) {
        value = newValue
        Tinkerble.shared.updateLocalValue(id: id, value: newValue)
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

@propertyWrapper
@MainActor
public struct TinkerbleState<Value: TinkerbleValueConvertible>: DynamicProperty {
    @StateObject private var box: TinkerbleStateBox<Value>

    public var wrappedValue: Value {
        get { box.value }
        nonmutating set { box.set(newValue) }
    }

    public var projectedValue: Binding<Value> {
        Binding(
            get: { box.value },
            set: { box.set($0) }
        )
    }

    public init(
        wrappedValue: Value,
        name: String,
        category: String? = nil,
        control: TinkerbleControl<Value> = .automatic
    ) {
        _box = StateObject(
            wrappedValue: TinkerbleStateBox(
                initialValue: wrappedValue,
                category: category,
                name: name,
                control: control
            )
        )
    }

    public init(
        wrappedValue: Value,
        category: String,
        name: String,
        control: TinkerbleControl<Value> = .automatic
    ) {
        self.init(wrappedValue: wrappedValue, name: name, category: category, control: control)
    }

    public init(
        wrappedValue: Value,
        _ category: String,
        name: String,
        control: TinkerbleControl<Value> = .automatic
    ) {
        self.init(wrappedValue: wrappedValue, name: name, category: category, control: control)
    }
}

import Combine
import Foundation

@MainActor
public final class Tinkerble: ObservableObject {
    public static let shared = Tinkerble()

    @Published public private(set) var connectionStatus: TinkerbleConnectionStatus = .disconnected
    @Published public private(set) var registeredTweaks: [TinkerbleTweak] = []

    private var tweaksByID: [String: TinkerbleTweak] = [:]
    private var remoteAppliers: [String: (TinkerbleValue) -> Void] = [:]
    private var transport: TinkerbleClientTransport

    public init(transport: TinkerbleClientTransport = TinkerbleRSocketClientTransport()) {
        self.transport = transport
        bindTransport(transport)
    }

    public func useTransport(_ transport: TinkerbleClientTransport) {
        self.transport.disconnect()
        self.transport = transport
        bindTransport(transport)
    }

    internal func resetForTesting(transport: TinkerbleClientTransport = TinkerbleRSocketClientTransport()) {
        self.transport.disconnect()
        self.transport = transport
        tweaksByID.removeAll()
        remoteAppliers.removeAll()
        registeredTweaks.removeAll()
        connectionStatus = .disconnected
        bindTransport(transport)
    }

    public func connect(host: String = "127.0.0.1", port: Int = 7777) {
        transport.connect(host: host, port: port)
    }

    public func disconnect() {
        transport.disconnect()
    }

    internal func register<Value: TinkerbleValueConvertible>(
        id: String,
        category: String?,
        name: String,
        value: Value,
        control: TinkerbleControl<Value>,
        applyRemoteValue: @escaping (Value) -> Void
    ) {
        let tweak = TinkerbleTweak(
            id: id,
            category: normalizedCategory(category),
            name: name,
            value: value.tinkerbleValue,
            valueKind: Value.tinkerbleValueKind,
            control: control.descriptor,
            enumOptions: Value.tinkerbleEnumOptions ?? []
        )

        tweaksByID[id] = tweak
        remoteAppliers[id] = { incomingValue in
            guard let typedValue = Value.fromTinkerbleValue(incomingValue) else { return }
            applyRemoteValue(typedValue)
        }

        publishTweaks()
        transport.send(.register(tweak))
    }

    internal func updateLocalValue<Value: TinkerbleValueConvertible>(id: String, value: Value) {
        updateStoredValue(id: id, value: value.tinkerbleValue)
        transport.send(.update(id: id, value: value.tinkerbleValue))
    }

    public func log(_ message: String) {
        transport.send(.log(.init(message: message)))
    }

    private func bindTransport(_ transport: TinkerbleClientTransport) {
        transport.onMessage = { [weak self] message in
            Task { @MainActor in
                self?.handle(message)
            }
        }
        transport.onStatusChange = { [weak self] status in
            Task { @MainActor in
                self?.connectionStatus = status
                if case .connected = status {
                    self?.transport.send(.snapshot(self?.sortedTweaks() ?? []))
                }
            }
        }
    }

    private func handle(_ message: TinkerbleWireMessage) {
        switch message {
        case let .update(id, value):
            updateStoredValue(id: id, value: value)
            remoteAppliers[id]?(value)
        case .hello, .snapshot, .register, .log:
            break
        }
    }

    private func updateStoredValue(id: String, value: TinkerbleValue) {
        guard var tweak = tweaksByID[id] else { return }
        tweak.value = value
        tweaksByID[id] = tweak
        publishTweaks()
    }

    private func publishTweaks() {
        registeredTweaks = sortedTweaks()
    }

    private func sortedTweaks() -> [TinkerbleTweak] {
        tweaksByID.values.sorted { left, right in
            switch (left.category, right.category) {
            case (nil, nil):
                return left.name.localizedCaseInsensitiveCompare(right.name) == .orderedAscending
            case (nil, _?):
                return true
            case (_?, nil):
                return false
            case let (leftCategory?, rightCategory?):
                if leftCategory == rightCategory {
                    return left.name.localizedCaseInsensitiveCompare(right.name) == .orderedAscending
                }
                return leftCategory.localizedCaseInsensitiveCompare(rightCategory) == .orderedAscending
            }
        }
    }

    private func normalizedCategory(_ category: String?) -> String? {
        guard let category = category?.trimmingCharacters(in: .whitespacesAndNewlines),
              !category.isEmpty
        else {
            return nil
        }
        return category
    }
}

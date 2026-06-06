import Foundation
import Observation

@Observable
@MainActor
public final class Tinkerble {
    @ObservationIgnored
    public static let shared = Tinkerble()

    public private(set) var connectionStatus: TinkerbleConnectionStatus = .disconnected
    public private(set) var registeredTweaks: [TinkerbleTweak] = []

    @ObservationIgnored
    private var liveRegistrationsByID: [String: LiveTweakRegistration] = [:]
    @ObservationIgnored
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
        liveRegistrationsByID.removeAll()
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

    @discardableResult
    internal func register<Value: TinkerbleValueConvertible>(
        id: String,
        category: String?,
        name: String,
        value: Value,
        control: TinkerbleControl<Value>,
        applyRemoteValue: @escaping (Value) -> Void
    ) -> TinkerbleRegistrationToken {
        let tweak = TinkerbleTweak(
            id: id,
            category: normalizedCategory(category),
            name: name,
            value: value.tinkerbleValue,
            valueKind: Value.tinkerbleValueKind,
            control: resolvedControlDescriptor(control.descriptor, for: Value.self),
            enumOptions: Value.tinkerbleEnumOptions ?? []
        )
        let token = TinkerbleRegistrationToken(tweakID: id)
        let remoteApplier: (TinkerbleValue) -> Void = { incomingValue in
            guard let typedValue = Value.fromTinkerbleValue(incomingValue) else { return }
            applyRemoteValue(typedValue)
        }

        if var liveRegistration = liveRegistrationsByID[id] {
            let currentValue = liveRegistration.tweak.value
            liveRegistration.remoteAppliers[token.instanceID] = remoteApplier
            liveRegistrationsByID[id] = liveRegistration
            remoteApplier(currentValue)
            return token
        }

        liveRegistrationsByID[id] = LiveTweakRegistration(
            tweak: tweak,
            remoteAppliers: [token.instanceID: remoteApplier]
        )
        publishTweaks()
        transport.send(.register(tweak))
        return token
    }

    private func resolvedControlDescriptor<Value: TinkerbleValueConvertible>(
        _ descriptor: TinkerbleControlDescriptor,
        for valueType: Value.Type
    ) -> TinkerbleControlDescriptor {
        switch descriptor {
        case .automatic:
            Value.tinkerbleDefaultControlDescriptor
        case .text, .plain, .slider:
            descriptor
        }
    }

    internal func unregister(_ token: TinkerbleRegistrationToken) {
        guard var liveRegistration = liveRegistrationsByID[token.tweakID] else { return }

        liveRegistration.remoteAppliers.removeValue(forKey: token.instanceID)
        guard liveRegistration.remoteAppliers.isEmpty else {
            liveRegistrationsByID[token.tweakID] = liveRegistration
            return
        }

        liveRegistrationsByID.removeValue(forKey: token.tweakID)
        publishTweaks()
        transport.send(.unregister(id: token.tweakID))
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
            let appliers = liveRegistrationsByID[id].map { Array($0.remoteAppliers.values) } ?? []
            for applier in appliers {
                applier(value)
            }
        case .hello, .snapshot, .register, .unregister, .log:
            break
        }
    }

    private func updateStoredValue(id: String, value: TinkerbleValue) {
        guard var liveRegistration = liveRegistrationsByID[id] else { return }
        liveRegistration.tweak.value = value
        liveRegistrationsByID[id] = liveRegistration
        publishTweaks()
    }

    private func publishTweaks() {
        registeredTweaks = sortedTweaks()
    }

    private func sortedTweaks() -> [TinkerbleTweak] {
        liveRegistrationsByID.values.map(\.tweak).sorted { left, right in
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

    private struct LiveTweakRegistration {
        var tweak: TinkerbleTweak
        var remoteAppliers: [UUID: (TinkerbleValue) -> Void]
    }
}

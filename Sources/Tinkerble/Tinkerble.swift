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

    public init(transport: TinkerbleClientTransport = TinkerbleSocketClientTransport()) {
        self.transport = transport
        bindTransport(transport)
    }

    public func useTransport(_ transport: TinkerbleClientTransport) {
        self.transport.disconnect()
        self.transport = transport
        bindTransport(transport)
    }

    internal func resetForTesting(transport: TinkerbleClientTransport = TinkerbleSocketClientTransport()) {
        self.transport.disconnect()
        self.transport = transport
        liveRegistrationsByID.removeAll()
        registeredTweaks.removeAll()
        connectionStatus = .disconnected
        bindTransport(transport)
    }

    public func connect(host: String? = nil, port: Int = TinkerbleNetworkConfiguration.defaultPort) {
        transport.connect(host: host, port: port)
    }

    public func disconnect() {
        transport.disconnect()
    }

    @discardableResult
    internal func register<Value: TinkerbleValueConvertible>(
        id: String,
        screen: String? = nil,
        category: String?,
        name: String,
        value: Value,
        control: TinkerbleControl<Value>,
        applyRemoteValue: @escaping (Value) -> Void
    ) -> TinkerbleRegistrationToken {
        let tweak = TinkerbleTweak(
            id: id,
            screen: screen,
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

    @discardableResult
    internal func registerAction(
        id: String,
        screen: String? = nil,
        category: String?,
        name: String,
        perform: @escaping () -> Void
    ) -> TinkerbleRegistrationToken {
        let tweak = TinkerbleTweak(
            id: id,
            screen: screen,
            category: normalizedCategory(category),
            name: name,
            value: .action,
            valueKind: .action,
            control: .automatic
        )
        let token = TinkerbleRegistrationToken(tweakID: id)

        if var liveRegistration = liveRegistrationsByID[id] {
            liveRegistration.actionHandlers[token.instanceID] = perform
            liveRegistrationsByID[id] = liveRegistration
            return token
        }

        liveRegistrationsByID[id] = LiveTweakRegistration(
            tweak: tweak,
            actionHandlers: [token.instanceID: perform]
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
        case .text, .plain, .slider, .date:
            descriptor
        }
    }

    internal func unregister(_ token: TinkerbleRegistrationToken) {
        guard var liveRegistration = liveRegistrationsByID[token.tweakID] else { return }

        liveRegistration.remoteAppliers.removeValue(forKey: token.instanceID)
        liveRegistration.actionHandlers.removeValue(forKey: token.instanceID)
        guard liveRegistration.remoteAppliers.isEmpty, liveRegistration.actionHandlers.isEmpty else {
            liveRegistrationsByID[token.tweakID] = liveRegistration
            return
        }

        liveRegistrationsByID.removeValue(forKey: token.tweakID)
        publishTweaks()
        transport.send(.unregister(id: token.tweakID))
    }

    internal func updateLocalValue<Value: TinkerbleValueConvertible>(id: String, value: Value) {
        updateLocalValue(id: id, value: value.tinkerbleValue)
    }

    internal func updateLocalValue(id: String, value: TinkerbleValue) {
        updateStoredValue(id: id, value: value)
        transport.send(.update(id: id, value: value))
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
        case let .trigger(id):
            let handlers = liveRegistrationsByID[id].map { Array($0.actionHandlers.values) } ?? []
            for handler in handlers {
                handler()
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
            if left.screen != right.screen {
                return left.screen.localizedCaseInsensitiveCompare(right.screen) == .orderedAscending
            }

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
        var remoteAppliers: [UUID: (TinkerbleValue) -> Void] = [:]
        var actionHandlers: [UUID: () -> Void] = [:]
    }
}

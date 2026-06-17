import Foundation
import Observation

@Observable
@MainActor
public final class Tinkerble {
    @ObservationIgnored
    public static let shared = Tinkerble()

    public private(set) var connectionStatus: TinkerbleConnectionStatus = .disconnected
    public private(set) var registeredTweaks: [TinkerbleTweak] = []

#if DEBUG
    @ObservationIgnored
    private var liveRegistrationsByID: [String: LiveTweakRegistration] = [:]
    @ObservationIgnored
    private var transport: TinkerbleClientTransport
#endif

    public init(transport: TinkerbleClientTransport = TinkerbleSocketClientTransport()) {
#if DEBUG
        self.transport = transport
        bindTransport(transport)
#else
        _ = transport
#endif
    }

    public func useTransport(_ transport: TinkerbleClientTransport) {
#if DEBUG
        self.transport.disconnect()
        self.transport = transport
        bindTransport(transport)
#else
        _ = transport
#endif
    }

    internal func resetForTesting(transport: TinkerbleClientTransport = TinkerbleSocketClientTransport()) {
#if DEBUG
        self.transport.disconnect()
        self.transport = transport
        liveRegistrationsByID.removeAll()
        registeredTweaks.removeAll()
        connectionStatus = .disconnected
        bindTransport(transport)
#else
        _ = transport
        registeredTweaks.removeAll()
        connectionStatus = .disconnected
#endif
    }

    public func connect(host: String? = nil, port: Int = TinkerbleNetworkConfiguration.defaultPort) {
#if DEBUG
        transport.connect(host: host, port: port)
#else
        _ = host
        _ = port
#endif
    }

    public func disconnect() {
#if DEBUG
        transport.disconnect()
#endif
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
#if DEBUG
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
#else
        _ = screen
        _ = category
        _ = name
        _ = value
        _ = control
        _ = applyRemoteValue
        return TinkerbleRegistrationToken(tweakID: id)
#endif
    }

    @discardableResult
    internal func registerAction(
        id: String,
        screen: String? = nil,
        category: String?,
        name: String,
        perform: @escaping () -> Void
    ) -> TinkerbleRegistrationToken {
#if DEBUG
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
#else
        _ = screen
        _ = category
        _ = name
        _ = perform
        return TinkerbleRegistrationToken(tweakID: id)
#endif
    }

#if DEBUG
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
#endif

    internal func unregister(_ token: TinkerbleRegistrationToken) {
#if DEBUG
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
#else
        _ = token
#endif
    }

    internal func updateLocalValue<Value: TinkerbleValueConvertible>(id: String, value: Value) {
#if DEBUG
        updateLocalValue(id: id, value: value.tinkerbleValue)
#else
        _ = id
        _ = value
#endif
    }

    internal func updateLocalValue(id: String, value: TinkerbleValue) {
#if DEBUG
        updateStoredValue(id: id, value: value)
        transport.send(.update(id: id, value: value))
#else
        _ = id
        _ = value
#endif
    }

    public func log(_ message: String) {
#if DEBUG
        transport.send(.log(.init(message: message)))
#else
        _ = message
#endif
    }

#if DEBUG
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
#endif
}

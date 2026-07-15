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
        sourceAnchor: TinkerbleSourceAnchor? = nil,
        applyRemoteValue: @escaping (Value) -> Void
    ) -> TinkerbleRegistrationToken {
#if DEBUG
        let tweak = TinkerbleTweak(
            id: id,
            screen: screen,
            category: normalizedCategory(category),
            name: name,
            value: value.tinkerbleValue,
            codeDefaultValue: value.tinkerbleValue,
            valueKind: Value.tinkerbleValueKind,
            control: resolvedControlDescriptor(control.descriptor, for: Value.self),
            enumOptions: Value.tinkerbleEnumOptions ?? [],
            sourceValueType: Value.tinkerbleSourceValueType,
            sourceAnchors: sourceAnchor.map { [$0] } ?? []
        )
        let token = TinkerbleRegistrationToken(tweakID: id)
        let remoteApplier: (TinkerbleValue) -> Void = { incomingValue in
            guard let typedValue = Value.fromTinkerbleValue(incomingValue) else { return }
            applyRemoteValue(typedValue)
        }

        if var liveRegistration = liveRegistrationsByID[id] {
            let currentValue = liveRegistration.tweak.value
            liveRegistration.remoteAppliers[token.instanceID] = remoteApplier
            var addedSourceAnchor = false
            if let sourceAnchor {
                liveRegistration.sourceAnchorsByInstance[token.instanceID] = sourceAnchor
                if !liveRegistration.tweak.sourceAnchors.contains(where: { $0.stableID == sourceAnchor.stableID }) {
                    liveRegistration.tweak.sourceAnchors.append(sourceAnchor)
                    addedSourceAnchor = true
                }
            }
            liveRegistrationsByID[id] = liveRegistration
            if addedSourceAnchor {
                publishTweaks()
                transport.send(.register(liveRegistration.tweak))
            }
            remoteApplier(currentValue)
            return token
        }

        liveRegistrationsByID[id] = LiveTweakRegistration(
            tweak: tweak,
            remoteAppliers: [token.instanceID: remoteApplier],
            sourceAnchorsByInstance: sourceAnchor.map { [token.instanceID: $0] } ?? [:]
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
        _ = sourceAnchor
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
        liveRegistration.sourceAnchorsByInstance.removeValue(forKey: token.instanceID)
        guard liveRegistration.remoteAppliers.isEmpty, liveRegistration.actionHandlers.isEmpty else {
            let remainingAnchors = Array(liveRegistration.sourceAnchorsByInstance.values)
            let previousAnchors = liveRegistration.tweak.sourceAnchors
            liveRegistration.tweak.sourceAnchors = previousAnchors.compactMap { previousAnchor in
                remainingAnchors.first(where: { $0 == previousAnchor })
                    ?? remainingAnchors.first(where: { $0.stableID == previousAnchor.stableID })
            }
            liveRegistrationsByID[token.tweakID] = liveRegistration
            if liveRegistration.tweak.sourceAnchors != previousAnchors {
                publishTweaks()
                transport.send(.register(liveRegistration.tweak))
            }
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

    public func log<Value: TinkerbleLogValueConvertible>(
        _ name: String,
        value: Value,
        screen: String? = nil,
        category: String? = nil
    ) {
#if DEBUG
        log(.init(screen: screen, category: category, name: name, value: value))
#else
        _ = name
        _ = value
        _ = screen
        _ = category
#endif
    }

    @available(*, deprecated, message: "Use log(\"Name\", value: ..., screen: ..., category: ...) instead.")
    public func log<Value: TinkerbleLogValueConvertible>(
        name: String,
        value: Value,
        screen: String? = nil,
        category: String? = nil
    ) {
        log(name, value: value, screen: screen, category: category)
    }

    public func log(_ entry: TinkerbleLogEntry) {
#if DEBUG
        transport.send(.log(entry))
#else
        _ = entry
#endif
    }

    @available(*, deprecated, message: "Use log(name:value:screen:category:) for live log values.")
    public func log(_ message: String) {
#if DEBUG
        log(.init(name: TinkerbleLogEntry.defaultName, value: message))
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
        var sourceAnchorsByInstance: [UUID: TinkerbleSourceAnchor] = [:]
    }
#endif
}

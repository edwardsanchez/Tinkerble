import Foundation
import Observation
import RSocketCore
import Tinkerble

@Observable
@MainActor
public final class TinkerbleCompanionStore {
    public private(set) var connectionStatus: TinkerbleConnectionStatus = .disconnected
    public private(set) var tweaks: [TinkerbleTweak] = []
    public private(set) var selectedScreen = TinkerbleTweak.defaultScreenName
    public private(set) var logs: [TinkerbleLogEntry] = []

    @ObservationIgnored
    private let codec = TinkerbleRSocketPayloadCodec()
    @ObservationIgnored
    private var server: TinkerbleRSocketCompanionServer?
    @ObservationIgnored
    private var tweaksByID: [String: TinkerbleTweak] = [:]
    @ObservationIgnored
    private var outboundStream: UnidirectionalStream?

    public init() {}

    public var groupedTweaks: [TinkerbleTweakGroup] {
        TinkerbleTweakGrouping.groupedTweaks(from: visibleTweaks)
    }

    public var screens: [String] {
        let uniqueScreens = Set(tweaks.map(\.screen))
        return uniqueScreens.sorted { left, right in
            if left == right {
                return false
            }
            if left == TinkerbleTweak.defaultScreenName {
                return true
            }
            if right == TinkerbleTweak.defaultScreenName {
                return false
            }
            return left.localizedCaseInsensitiveCompare(right) == .orderedAscending
        }
    }

    public var showsScreenSelector: Bool {
        screens.count > 1
    }

    private var visibleTweaks: [TinkerbleTweak] {
        guard showsScreenSelector else { return tweaks }
        return tweaks.filter { $0.screen == selectedScreen }
    }

    public func selectScreen(_ screen: String) {
        guard screens.contains(screen) else { return }
        selectedScreen = screen
    }

    public func start(host: String = "0.0.0.0", port: Int = 7777) {
        guard server == nil else { return }
        let server = TinkerbleRSocketCompanionServer(
            host: host,
            port: port,
            onMessage: { [weak self] message, outbound in
                Task { @MainActor in
                    self?.handle(message, outbound: outbound)
                }
            },
            onStatusChange: { [weak self] status in
                Task { @MainActor in
                    self?.connectionStatus = status
                }
            }
        )
        self.server = server
        server.start()
    }

    public func stop() {
        server?.stop()
        server = nil
        outboundStream = nil
        connectionStatus = .disconnected
    }

    public func updateTweak(id: String, value: TinkerbleValue) {
        updateStoredTweak(id: id, value: value)
        send(.update(id: id, value: value))
    }

    public func triggerTweak(id: String) {
        send(.trigger(id: id))
    }

    internal func handle(_ message: TinkerbleWireMessage, outbound: UnidirectionalStream?) {
        if let outbound {
            outboundStream = outbound
        }

        switch message {
        case .hello:
            connectionStatus = .connected("iOS app connected")
        case let .snapshot(tweaks):
            tweaksByID = Dictionary(uniqueKeysWithValues: tweaks.map { ($0.id, $0) })
            publishTweaks()
        case let .register(tweak):
            tweaksByID[tweak.id] = tweak
            publishTweaks()
        case let .unregister(id):
            tweaksByID.removeValue(forKey: id)
            publishTweaks()
        case let .update(id, value):
            updateStoredTweak(id: id, value: value)
        case .trigger:
            break
        case let .log(entry):
            logs.append(entry)
        }
    }

    private func updateStoredTweak(id: String, value: TinkerbleValue) {
        guard var tweak = tweaksByID[id] else { return }
        tweak.value = value
        tweaksByID[id] = tweak
        publishTweaks()
    }

    private func publishTweaks() {
        tweaks = tweaksByID.values.sorted { left, right in
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
        if let firstScreen = screens.first, !screens.contains(selectedScreen) {
            selectedScreen = firstScreen
        } else if screens.isEmpty {
            selectedScreen = TinkerbleTweak.defaultScreenName
        }
    }

    private func send(_ message: TinkerbleWireMessage) {
        guard let outboundStream else { return }
        do {
            outboundStream.onNext(try codec.payload(for: message), isCompletion: false)
        } catch {
            connectionStatus = .failed("Could not encode update: \(error.localizedDescription)")
        }
    }
}

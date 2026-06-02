import Combine
import Foundation
import RSocketCore
import Tinkerble

@MainActor
public final class TinkerbleCompanionStore: ObservableObject {
    @Published public private(set) var connectionStatus: TinkerbleConnectionStatus = .disconnected
    @Published public private(set) var tweaks: [TinkerbleTweak] = []
    @Published public private(set) var logs: [TinkerbleLogEntry] = []

    private let codec = TinkerbleRSocketPayloadCodec()
    private var server: TinkerbleRSocketCompanionServer?
    private var tweaksByID: [String: TinkerbleTweak] = [:]
    private var outboundStream: UnidirectionalStream?

    public init() {}

    public var groupedTweaks: [TinkerbleTweakGroup] {
        let uncategorized = tweaks.filter { $0.category == nil }
        let categorized = Dictionary(grouping: tweaks.filter { $0.category != nil }, by: \.category)

        var groups: [TinkerbleTweakGroup] = []
        if !uncategorized.isEmpty {
            groups.append(.init(category: nil, tweaks: uncategorized))
        }

        groups.append(
            contentsOf: categorized.keys.compactMap { category -> TinkerbleTweakGroup? in
                guard let category else { return nil }
                return TinkerbleTweakGroup(
                    category: category,
                    tweaks: categorized[category] ?? []
                )
            }
            .sorted { $0.category ?? "" < $1.category ?? "" }
        )

        return groups
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
        case let .update(id, value):
            updateStoredTweak(id: id, value: value)
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

    private func send(_ message: TinkerbleWireMessage) {
        guard let outboundStream else { return }
        do {
            outboundStream.onNext(try codec.payload(for: message), isCompletion: false)
        } catch {
            connectionStatus = .failed("Could not encode update: \(error.localizedDescription)")
        }
    }
}

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
    public private(set) var canUndo = false
    public private(set) var canRedo = false

    @ObservationIgnored
    private let codec = TinkerbleRSocketPayloadCodec()
    @ObservationIgnored
    private var server: TinkerbleRSocketCompanionServer?
    @ObservationIgnored
    private var tweaksByID: [String: TinkerbleTweak] = [:]
    @ObservationIgnored
    private var outboundStream: UnidirectionalStream?
    @ObservationIgnored
    private var undoStack: [TinkerbleTweakUndoEntry] = []
    @ObservationIgnored
    private var redoStack: [TinkerbleTweakUndoEntry] = []
    @ObservationIgnored
    private var coalescedUndoStartValues: [String: TinkerbleValue] = [:]

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
        clearUndoHistory()
    }

    public func updateTweak(id: String, value: TinkerbleValue) {
        guard let currentValue = tweaksByID[id]?.value, currentValue != value else { return }
        undoStack.append(.init(id: id, previousValue: currentValue, nextValue: value))
        redoStack.removeAll()
        updateStoredTweak(id: id, value: value)
        send(.update(id: id, value: value))
        updateUndoAvailability()
    }

    public func beginCoalescedTweakUpdate(id: String) {
        guard coalescedUndoStartValues[id] == nil, let currentValue = tweaksByID[id]?.value else { return }
        coalescedUndoStartValues[id] = currentValue
    }

    public func updateCoalescedTweak(id: String, value: TinkerbleValue) {
        guard let currentValue = tweaksByID[id]?.value, currentValue != value else { return }
        updateStoredTweak(id: id, value: value)
        send(.update(id: id, value: value))
    }

    public func endCoalescedTweakUpdate(id: String) {
        guard let previousValue = coalescedUndoStartValues.removeValue(forKey: id),
              let currentValue = tweaksByID[id]?.value,
              previousValue != currentValue
        else {
            updateUndoAvailability()
            return
        }

        undoStack.append(.init(id: id, previousValue: previousValue, nextValue: currentValue))
        redoStack.removeAll()
        updateUndoAvailability()
    }

    public func triggerTweak(id: String) {
        send(.trigger(id: id))
    }

    public func undo() {
        while let entry = undoStack.popLast() {
            guard updateStoredTweak(id: entry.id, value: entry.previousValue) else { continue }
            send(.update(id: entry.id, value: entry.previousValue))
            redoStack.append(entry)
            break
        }
        updateUndoAvailability()
    }

    public func redo() {
        while let entry = redoStack.popLast() {
            guard updateStoredTweak(id: entry.id, value: entry.nextValue) else { continue }
            send(.update(id: entry.id, value: entry.nextValue))
            undoStack.append(entry)
            break
        }
        updateUndoAvailability()
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
            pruneUndoHistory(toValidTweakIDs: Set(tweaksByID.keys))
            publishTweaks()
        case let .register(tweak):
            tweaksByID[tweak.id] = tweak
            publishTweaks()
        case let .unregister(id):
            tweaksByID.removeValue(forKey: id)
            removeUndoHistory(for: id)
            publishTweaks()
        case let .update(id, value):
            updateStoredTweak(id: id, value: value)
        case .trigger:
            break
        case let .log(entry):
            logs.append(entry)
        }
    }

    @discardableResult
    private func updateStoredTweak(id: String, value: TinkerbleValue) -> Bool {
        guard var tweak = tweaksByID[id] else { return false }
        tweak.value = value
        tweaksByID[id] = tweak
        publishTweaks()
        return true
    }

    private func removeUndoHistory(for id: String) {
        undoStack.removeAll { $0.id == id }
        redoStack.removeAll { $0.id == id }
        coalescedUndoStartValues.removeValue(forKey: id)
        updateUndoAvailability()
    }

    private func pruneUndoHistory(toValidTweakIDs validTweakIDs: Set<String>) {
        undoStack.removeAll { !validTweakIDs.contains($0.id) }
        redoStack.removeAll { !validTweakIDs.contains($0.id) }
        coalescedUndoStartValues = coalescedUndoStartValues.filter { validTweakIDs.contains($0.key) }
        updateUndoAvailability()
    }

    private func clearUndoHistory() {
        undoStack.removeAll()
        redoStack.removeAll()
        coalescedUndoStartValues.removeAll()
        updateUndoAvailability()
    }

    private func updateUndoAvailability() {
        canUndo = !undoStack.isEmpty
        canRedo = !redoStack.isEmpty
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

private struct TinkerbleTweakUndoEntry {
    var id: String
    var previousValue: TinkerbleValue
    var nextValue: TinkerbleValue
}

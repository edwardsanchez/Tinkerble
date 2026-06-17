import Foundation
import Observation
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
    public private(set) var versions: [TinkerbleSavedVersion] = []
    public private(set) var selectedVersionID: UUID?

    @ObservationIgnored
    private let versionRepository: any TinkerbleVersionRepository
    @ObservationIgnored
    private var server: TinkerbleSocketCompanionServer?
    @ObservationIgnored
    private var tweaksByID: [String: TinkerbleTweak] = [:]
    @ObservationIgnored
    private var defaultValuesByID: [String: TinkerbleValue] = [:]
    @ObservationIgnored
    private var outboundChannel: TinkerbleCompanionOutboundChannel?
    @ObservationIgnored
    private var undoStack: [TinkerbleTweakUndoEntry] = []
    @ObservationIgnored
    private var redoStack: [TinkerbleTweakUndoEntry] = []
    @ObservationIgnored
    private var coalescedUndoStartValues: [String: TinkerbleValue] = [:]
    @ObservationIgnored
    private var projectIdentity = TinkerbleProjectIdentity.fallback

    public convenience init() {
        self.init(versionRepository: TinkerbleInMemoryVersionRepository())
    }

    public init(versionRepository: any TinkerbleVersionRepository) {
        self.versionRepository = versionRepository
    }

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

    public var canDeleteSelectedVersion: Bool {
        selectedVersion?.isProtected == false
    }

    public var canResetSelectedVersion: Bool {
        selectedVersion?.isProtected == true
    }

    private var visibleTweaks: [TinkerbleTweak] {
        guard showsScreenSelector else { return tweaks }
        return tweaks.filter { $0.screen == selectedScreen }
    }

    private var selectedVersion: TinkerbleSavedVersion? {
        versions.first { $0.id == selectedVersionID }
    }

    private var versionedVisibleTweaks: [TinkerbleTweak] {
        visibleTweaks.filter { $0.value.kind != .action }
    }

    public func selectScreen(_ screen: String) {
        guard screens.contains(screen) else { return }
        selectedScreen = screen
        clearUndoHistory()
        reloadVersionsForSelectedScreen()
        applySelectedVersion()
    }

    public func selectVersion(_ id: UUID) {
        guard versions.contains(where: { $0.id == id }) else { return }
        selectedVersionID = id
        clearUndoHistory()
        applySelectedVersion()
    }

    public func createVersion() {
        let values = Dictionary(uniqueKeysWithValues: versionedVisibleTweaks.map { ($0.id, $0.value) })
        do {
            versions = try versionRepository.createVersion(
                projectID: projectIdentity.id,
                screen: selectedScreen,
                values: values
            )
            selectedVersionID = versions.last?.id
            clearUndoHistory()
        } catch {
            recordVersionPersistenceError(error)
        }
    }

    public func deleteSelectedVersion() {
        guard let selectedVersion, !selectedVersion.isProtected else { return }
        do {
            versions = try versionRepository.deleteVersion(
                projectID: projectIdentity.id,
                screen: selectedScreen,
                versionID: selectedVersion.id
            )
            selectedVersionID = versions.last { $0.ordinal < selectedVersion.ordinal }?.id ?? versions.first?.id
            clearUndoHistory()
            applySelectedVersion()
        } catch {
            recordVersionPersistenceError(error)
        }
    }

    public func resetSelectedVersion() {
        guard let selectedVersion, selectedVersion.isProtected else { return }
        do {
            try versionRepository.resetVersion(
                projectID: projectIdentity.id,
                screen: selectedScreen,
                versionID: selectedVersion.id
            )
            clearUndoHistory()
            applySelectedVersion()
        } catch {
            recordVersionPersistenceError(error)
        }
    }

    public func start(
        host: String = "0.0.0.0",
        port: Int = 7777,
        serviceType: String = TinkerbleNetworkConfiguration.bonjourServiceType
    ) {
        guard server == nil else { return }
        let server = TinkerbleSocketCompanionServer(
            host: host,
            port: port,
            serviceType: serviceType,
            onMessage: { [weak self] message, outboundChannel in
                Task { @MainActor in
                    self?.handle(message, outboundChannel: outboundChannel)
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
        outboundChannel = nil
        connectionStatus = .disconnected
        clearUndoHistory()
    }

    public func updateTweak(id: String, value: TinkerbleValue) {
        guard let currentValue = tweaksByID[id]?.value, currentValue != value else { return }
        undoStack.append(.init(id: id, previousValue: currentValue, nextValue: value))
        redoStack.removeAll()
        updateStoredTweak(id: id, value: value)
        saveCurrentVersionValue(id: id, value: value)
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
        saveCurrentVersionValue(id: id, value: value)
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
            saveCurrentVersionValue(id: entry.id, value: entry.previousValue)
            send(.update(id: entry.id, value: entry.previousValue))
            redoStack.append(entry)
            break
        }
        updateUndoAvailability()
    }

    public func redo() {
        while let entry = redoStack.popLast() {
            guard updateStoredTweak(id: entry.id, value: entry.nextValue) else { continue }
            saveCurrentVersionValue(id: entry.id, value: entry.nextValue)
            send(.update(id: entry.id, value: entry.nextValue))
            undoStack.append(entry)
            break
        }
        updateUndoAvailability()
    }

    internal func handle(_ message: TinkerbleWireMessage, outboundChannel: TinkerbleCompanionOutboundChannel?) {
        if let outboundChannel {
            self.outboundChannel = outboundChannel
        }

        switch message {
        case let .hello(_, _, project):
            projectIdentity = project ?? .fallback
            connectionStatus = .connected("iOS app connected")
            reloadVersionsForSelectedScreen()
            applySelectedVersion()
        case let .snapshot(tweaks):
            tweaksByID = Dictionary(uniqueKeysWithValues: tweaks.map { ($0.id, $0) })
            defaultValuesByID = Dictionary(uniqueKeysWithValues: tweaks.map { ($0.id, $0.value) })
            pruneUndoHistory(toValidTweakIDs: Set(tweaksByID.keys))
            publishTweaks()
            applySelectedVersion()
        case let .register(tweak):
            tweaksByID[tweak.id] = tweak
            defaultValuesByID[tweak.id] = tweak.value
            publishTweaks()
            applySelectedVersion()
        case let .unregister(id):
            tweaksByID.removeValue(forKey: id)
            defaultValuesByID.removeValue(forKey: id)
            removeUndoHistory(for: id)
            publishTweaks()
        case let .update(id, value):
            defaultValuesByID[id] = value
            updateStoredTweak(id: id, value: value)
            applySelectedVersionValueIfNeeded(id: id)
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

    private func reloadVersionsForSelectedScreen() {
        do {
            versions = try versionRepository.ensureVersions(projectID: projectIdentity.id, screen: selectedScreen)
            if let selectedVersionID, versions.contains(where: { $0.id == selectedVersionID }) {
                return
            }
            selectedVersionID = versions.first?.id
        } catch {
            recordVersionPersistenceError(error)
        }
    }

    private func applySelectedVersion() {
        guard selectedVersionID != nil else {
            reloadVersionsForSelectedScreen()
            return
        }

        for tweak in versionedVisibleTweaks {
            applySelectedVersionValueIfNeeded(id: tweak.id)
        }
    }

    private func applySelectedVersionValueIfNeeded(id: String) {
        guard let selectedVersionID,
              let tweak = tweaksByID[id],
              tweak.screen == selectedScreen,
              tweak.value.kind != .action
        else {
            return
        }

        do {
            let savedValue = try versionRepository.value(
                projectID: projectIdentity.id,
                screen: selectedScreen,
                versionID: selectedVersionID,
                tweakID: id
            )
            let targetValue = savedValue.flatMap { $0.kind == tweak.value.kind ? $0 : nil }
                ?? defaultValuesByID[id].flatMap { $0.kind == tweak.value.kind ? $0 : nil }
            guard let targetValue, targetValue != tweak.value else {
                return
            }
            updateStoredTweak(id: id, value: targetValue)
            send(.update(id: id, value: targetValue))
        } catch {
            recordVersionPersistenceError(error)
        }
    }

    private func saveCurrentVersionValue(id: String, value: TinkerbleValue) {
        guard let tweak = tweaksByID[id], tweak.screen == selectedScreen, value.kind != .action else { return }
        if selectedVersionID == nil {
            reloadVersionsForSelectedScreen()
        }
        guard let selectedVersionID else { return }

        do {
            try versionRepository.saveValue(
                projectID: projectIdentity.id,
                screen: selectedScreen,
                versionID: selectedVersionID,
                tweakID: id,
                value: value
            )
        } catch {
            recordVersionPersistenceError(error)
        }
    }

    private func recordVersionPersistenceError(_ error: Swift.Error) {
        logs.append(.init(message: "Version persistence failed: \(error.localizedDescription)"))
    }

    private func publishTweaks() {
        let previousSelectedScreen = selectedScreen
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
        if previousSelectedScreen != selectedScreen {
            clearUndoHistory()
            reloadVersionsForSelectedScreen()
        } else if !tweaks.isEmpty && versions.isEmpty {
            reloadVersionsForSelectedScreen()
        }
    }

    private func send(_ message: TinkerbleWireMessage) {
        outboundChannel?.send(message)
    }
}

private struct TinkerbleTweakUndoEntry {
    var id: String
    var previousValue: TinkerbleValue
    var nextValue: TinkerbleValue
}

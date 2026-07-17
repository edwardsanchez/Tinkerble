import Foundation
import Observation
import Tinkerble

@Observable
@MainActor
public final class TinkerbleCompanionStore {
    public nonisolated static let defaultAutoApplyDelay: Duration = .seconds(2)

    public private(set) var connectionStatus: TinkerbleConnectionStatus = .disconnected
    public private(set) var tweaks: [TinkerbleTweak] = []
    public private(set) var selectedScreen = TinkerbleTweak.defaultScreenName
    public private(set) var logs: [TinkerbleLogEntry] = []
    public private(set) var canUndo = false
    public private(set) var canRedo = false
    public private(set) var versions: [TinkerbleSavedVersion] = []
    public private(set) var selectedVersionID: UUID?
    public private(set) var sourceEditingTweakIDs: Set<String> = []
    public private(set) var recentlyAppliedTweakIDs: Set<String> = []
    public private(set) var sourceEditAlert: TinkerbleSourceEditAlert?
    public private(set) var isReconcilingAppliedDefaults = false
    public private(set) var isAutoApplyEnabled = false
    public private(set) var hasLiveConnection = false

    @ObservationIgnored
    private let versionRepository: any TinkerbleVersionRepository
    @ObservationIgnored
    private let sourceEditor: (any TinkerbleSourceEditing)?
    @ObservationIgnored
    private let appliedDefaultRepository: any TinkerbleAppliedDefaultRepository
    @ObservationIgnored
    private let sourceProjectRoot: URL?
    @ObservationIgnored
    private let sourceProjectID: String?
    @ObservationIgnored
    private let autoApplyPreference: (any TinkerbleAutoApplyPreference)?
    @ObservationIgnored
    private var server: TinkerbleSocketCompanionServer?
    @ObservationIgnored
    private var tweaksByID: [String: TinkerbleTweak] = [:]
    @ObservationIgnored
    private var compiledDefaultValuesByID: [String: TinkerbleValue] = [:]
    @ObservationIgnored
    private var effectiveDefaultValuesByID: [String: TinkerbleValue] = [:]
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
    @ObservationIgnored
    private var appliedDefaultResolutionsByID: [String: TinkerbleAppliedDefaultResolution] = [:]
    @ObservationIgnored
    private var appliedDefaultReconciliationGeneration = 0
    @ObservationIgnored
    private let autoApplyDelay: Duration
    @ObservationIgnored
    private var autoApplyTasksByTweakID: [String: Task<Void, Never>] = [:]
    @ObservationIgnored
    private var pendingAutoApplyValuesByTweakID: [String: TinkerbleValue] = [:]

    public convenience init() {
        self.init(versionRepository: TinkerbleInMemoryVersionRepository())
    }

    public init(
        versionRepository: any TinkerbleVersionRepository,
        sourceEditor: (any TinkerbleSourceEditing)? = nil,
        appliedDefaultRepository: any TinkerbleAppliedDefaultRepository = TinkerbleInMemoryAppliedDefaultRepository(),
        sourceProjectRoot: URL? = nil,
        sourceProjectID: String? = nil,
        autoApplyPreference: (any TinkerbleAutoApplyPreference)? = nil,
        autoApplyDelay: Duration = TinkerbleCompanionStore.defaultAutoApplyDelay
    ) {
        self.versionRepository = versionRepository
        self.sourceEditor = sourceEditor
        self.appliedDefaultRepository = appliedDefaultRepository
        self.sourceProjectRoot = sourceProjectRoot?.resolvingSymlinksInPath().standardizedFileURL
        self.sourceProjectID = sourceProjectID
        self.autoApplyPreference = autoApplyPreference
        self.autoApplyDelay = autoApplyDelay
        isAutoApplyEnabled = autoApplyPreference?.isEnabled ?? false
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
        applySelectedVersion(schedulesAutoApply: true)
    }

    public func selectVersion(_ id: UUID) {
        guard versions.contains(where: { $0.id == id }) else { return }
        selectedVersionID = id
        clearUndoHistory()
        applySelectedVersion(schedulesAutoApply: true)
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
            applySelectedVersion(schedulesAutoApply: true)
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
            applySelectedVersion(schedulesAutoApply: true)
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
            onConnectionClosed: { [weak self] outboundChannel in
                Task { @MainActor in
                    self?.handleConnectionClosed(outboundChannel)
                }
            },
            onStatusChange: { [weak self] status in
                Task { @MainActor in
                    self?.handleConnectionStatusChange(status)
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
        hasLiveConnection = false
        cancelPendingAutoApplies()
        clearUndoHistory()
    }

    public func setAutoApplyEnabled(_ isEnabled: Bool) {
        guard isAutoApplyEnabled != isEnabled else { return }
        isAutoApplyEnabled = isEnabled
        autoApplyPreference?.isEnabled = isEnabled
        if isEnabled {
            scheduleOutstandingAutoApplies()
        } else {
            cancelPendingAutoApplies()
        }
    }

    public func updateTweak(id: String, value: TinkerbleValue) {
        guard let currentValue = tweaksByID[id]?.value, currentValue != value else { return }
        undoStack.append(
            .init(changes: [.init(id: id, previousValue: currentValue, nextValue: value)])
        )
        redoStack.removeAll()
        updateStoredTweak(id: id, value: value)
        saveCurrentVersionValue(id: id, value: value)
        send(.update(id: id, value: value))
        updateUndoAvailability()
        scheduleAutoApplyAfterDirectUpdate(id: id, value: value)
    }

    public func beginCoalescedTweakUpdate(id: String) {
        guard coalescedUndoStartValues[id] == nil, let currentValue = tweaksByID[id]?.value else { return }
        if autoAppliesCoalescedUpdateAtInteractionEnd(id: id) {
            cancelPendingAutoApply(for: id)
        }
        coalescedUndoStartValues[id] = currentValue
    }

    public func updateCoalescedTweak(id: String, value: TinkerbleValue) {
        guard let currentValue = tweaksByID[id]?.value, currentValue != value else { return }
        updateStoredTweak(id: id, value: value)
        saveCurrentVersionValue(id: id, value: value)
        send(.update(id: id, value: value))
        if !autoAppliesCoalescedUpdateAtInteractionEnd(id: id) {
            scheduleAutoApplyAfterDirectUpdate(id: id, value: value)
        }
    }

    public func endCoalescedTweakUpdate(id: String) {
        guard let previousValue = coalescedUndoStartValues.removeValue(forKey: id),
              let currentValue = tweaksByID[id]?.value
        else {
            updateUndoAvailability()
            return
        }
        guard previousValue != currentValue else {
            updateUndoAvailability()
            if autoAppliesCoalescedUpdateAtInteractionEnd(id: id) {
                requestAutoApplyNow(id: id, expectedValue: currentValue)
            }
            return
        }

        undoStack.append(
            .init(changes: [.init(id: id, previousValue: previousValue, nextValue: currentValue)])
        )
        redoStack.removeAll()
        updateUndoAvailability()
        if autoAppliesCoalescedUpdateAtInteractionEnd(id: id) {
            requestAutoApplyNow(id: id, expectedValue: currentValue)
        }
    }

    public func triggerTweak(id: String) {
        send(.trigger(id: id))
    }

    public func canApplyTweakToSource(_ id: String) -> Bool {
        guard !isReconcilingAppliedDefaults,
              let tweak = tweaksByID[id],
              tweak.value.kind != .action
        else {
            return false
        }
        return !sourceEditingTweakIDs.contains(id)
            && effectiveDefaultValuesByID[id] != tweak.value
    }

    public func canApplyCategoryToSource(_ category: String) -> Bool {
        categoryTweaks(category).contains { canApplyTweakToSource($0.id) }
    }

    public func canResetCategoryToDefaults(_ category: String) -> Bool {
        guard !isReconcilingAppliedDefaults else { return false }
        return categoryTweaks(category).contains { tweak in
            guard tweak.value.kind != .action, let defaultValue = effectiveDefaultValuesByID[tweak.id] else {
                return false
            }
            return tweak.value != defaultValue
        }
    }

    public func applyTweakToSource(id: String) {
        cancelPendingAutoApply(for: id)
        guard let tweak = tweaksByID[id], canApplyTweakToSource(id) else { return }
        applyTweaksToSource([tweak])
    }

    public func applyCategoryToSource(_ category: String) {
        let tweaks = categoryTweaks(category).filter { canApplyTweakToSource($0.id) }
        guard !tweaks.isEmpty else { return }
        for tweak in tweaks {
            cancelPendingAutoApply(for: tweak.id)
        }
        applyTweaksToSource(tweaks)
    }

    public func resetCategoryToDefaults(_ category: String) {
        let changes = categoryTweaks(category).compactMap { tweak -> TinkerbleTweakUndoChange? in
            guard tweak.value.kind != .action,
                  let defaultValue = effectiveDefaultValuesByID[tweak.id],
                  defaultValue.kind == tweak.value.kind,
                  defaultValue != tweak.value
            else {
                return nil
            }
            return .init(id: tweak.id, previousValue: tweak.value, nextValue: defaultValue)
        }
        guard !changes.isEmpty else { return }

        undoStack.append(.init(changes: changes))
        redoStack.removeAll()
        for change in changes {
            updateStoredTweak(id: change.id, value: change.nextValue)
            saveCurrentVersionValue(id: change.id, value: change.nextValue)
            send(.update(id: change.id, value: change.nextValue))
        }
        updateUndoAvailability()
    }

    public func dismissSourceEditAlert() {
        sourceEditAlert = nil
    }

    private func applyTweaksToSource(_ tweaks: [TinkerbleTweak]) {
        guard let sourceProjectRoot else {
            sourceEditAlert = .init(
                title: "Unable to Apply Values",
                message: "Tinkerble was launched without this project's source path. Run the app with its + Tinkerble scheme and try again."
            )
            return
        }
        if let sourceProjectID, sourceProjectID != projectIdentity.id {
            sourceEditAlert = .init(
                title: "Unable to Apply Values",
                message: "The connected app is \(projectIdentity.displayName), but this Companion was opened for a different project. Run the connected app with its + Tinkerble scheme and try again."
            )
            return
        }
        guard let sourceEditor else {
            sourceEditAlert = .init(
                title: "Unable to Apply Values",
                message: "Source editing is unavailable in this Companion build. Rebuild the Companion and try again."
            )
            return
        }

        let requests = tweaks.map { tweak in
            TinkerbleSourceApplyRequest(
                projectID: projectIdentity.id,
                projectRoot: sourceProjectRoot,
                tweak: tweak,
                acceptedInitializerExpressions: tweak.sourceAnchors.map(\.initializerExpression)
                    + (appliedDefaultResolutionsByID[tweak.id]?.acceptedInitializerExpressions ?? [])
            )
        }
        let tweakIDs = Set(tweaks.map(\.id))
        let projectID = projectIdentity.id
        appliedDefaultReconciliationGeneration += 1
        sourceEditingTweakIDs.formUnion(tweakIDs)
        sourceEditAlert = nil

        Task { [weak self] in
            do {
                let result = try await sourceEditor.apply(requests)
                let tweaksByID = Dictionary(uniqueKeysWithValues: tweaks.map { ($0.id, $0) })
                let records = result.edits.compactMap { edit in
                    tweaksByID[edit.tweakID].map { tweak in
                        TinkerbleAppliedDefaultRecord(
                            projectID: projectID,
                            projectRoot: sourceProjectRoot,
                            edit: edit,
                            value: tweak.value,
                            sourceValueType: tweak.sourceValueType
                        )
                    }
                }
                do {
                    try await self?.appliedDefaultRepository.update(records)
                    self?.finishSourceApply(result, records: records, requestedTweaks: tweaks)
                } catch {
                    self?.finishSourceApply(result, records: records, requestedTweaks: tweaks)
                    self?.sourceEditAlert = .init(
                        title: "Values Applied with a Warning",
                        message: "The source files were updated and verified, but Tinkerble could not remember the new defaults for this running build. Rebuilding the app will synchronize them. \(error.localizedDescription)"
                    )
                }
            } catch {
                self?.finishSourceApply(error, requestedTweaks: tweaks)
            }
        }
    }

    private func finishSourceApply(
        _ result: TinkerbleSourceApplyResult,
        records: [TinkerbleAppliedDefaultRecord],
        requestedTweaks: [TinkerbleTweak]
    ) {
        let editedIDs = Set(result.edits.map(\.tweakID))
        let recordsByTweakID = Dictionary(
            uniqueKeysWithValues: zip(result.edits.map(\.tweakID), records)
        )
        sourceEditingTweakIDs.subtract(requestedTweaks.map(\.id))
        for tweak in requestedTweaks where editedIDs.contains(tweak.id) {
            effectiveDefaultValuesByID[tweak.id] = tweak.value
            if let record = recordsByTweakID[tweak.id] {
                appliedDefaultResolutionsByID[tweak.id] = .init(
                    effectiveValue: tweak.value,
                    acceptedInitializerExpressions: [record.writtenInitializerExpression],
                    record: record
                )
            }
        }
        recentlyAppliedTweakIDs.formUnion(editedIDs)
        resumePendingAutoApplies()
        guard !editedIDs.isEmpty else { return }
        Task { [weak self] in
            do {
                try await Task.sleep(for: .seconds(1.5))
            } catch {
                return
            }
            self?.recentlyAppliedTweakIDs.subtract(editedIDs)
        }
    }

    private func finishSourceApply(_ error: Swift.Error, requestedTweaks: [TinkerbleTweak]) {
        sourceEditingTweakIDs.subtract(requestedTweaks.map(\.id))
        let title: String
        if requestedTweaks.count == 1, let tweak = requestedTweaks.first {
            title = "Unable to Apply \(tweak.name)"
        } else {
            title = "Unable to Apply Values"
        }

        if let applyError = error as? TinkerbleSourceApplyError, !applyError.issues.isEmpty {
            let details = applyError.issues.map { issue in
                "\(issue.tweakName): \(issue.localizedDescription)"
            }
            sourceEditAlert = .init(title: title, message: details.joined(separator: "\n\n"))
        } else if let issue = error as? TinkerbleSourceEditIssue {
            sourceEditAlert = .init(title: title, message: issue.localizedDescription)
        } else {
            sourceEditAlert = .init(title: title, message: error.localizedDescription)
        }
        resumePendingAutoApplies()
    }

    public func undo() {
        while let entry = undoStack.popLast() {
            let appliedChanges = entry.changes.filter { change in
                guard updateStoredTweak(id: change.id, value: change.previousValue) else { return false }
                saveCurrentVersionValue(id: change.id, value: change.previousValue)
                send(.update(id: change.id, value: change.previousValue))
                scheduleAutoApplyAfterDirectUpdate(id: change.id, value: change.previousValue)
                return true
            }
            guard !appliedChanges.isEmpty else { continue }
            redoStack.append(.init(changes: appliedChanges))
            break
        }
        updateUndoAvailability()
    }

    public func redo() {
        while let entry = redoStack.popLast() {
            let appliedChanges = entry.changes.filter { change in
                guard updateStoredTweak(id: change.id, value: change.nextValue) else { return false }
                saveCurrentVersionValue(id: change.id, value: change.nextValue)
                send(.update(id: change.id, value: change.nextValue))
                scheduleAutoApplyAfterDirectUpdate(id: change.id, value: change.nextValue)
                return true
            }
            guard !appliedChanges.isEmpty else { continue }
            undoStack.append(.init(changes: appliedChanges))
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
            hasLiveConnection = true
            reloadVersionsForSelectedScreen()
            applySelectedVersion()
            reconcileAppliedDefaults()
        case let .snapshot(tweaks):
            cancelPendingAutoApplies()
            tweaksByID = Dictionary(uniqueKeysWithValues: tweaks.map { ($0.id, $0) })
            compiledDefaultValuesByID = Dictionary(uniqueKeysWithValues: tweaks.map { ($0.id, $0.codeDefaultValue) })
            effectiveDefaultValuesByID = compiledDefaultValuesByID
            appliedDefaultResolutionsByID.removeAll()
            pruneUndoHistory(toValidTweakIDs: Set(tweaksByID.keys))
            publishTweaks()
            applySelectedVersion()
            reconcileAppliedDefaults()
        case let .register(tweak):
            tweaksByID[tweak.id] = tweak
            compiledDefaultValuesByID[tweak.id] = tweak.codeDefaultValue
            effectiveDefaultValuesByID[tweak.id] = tweak.codeDefaultValue
            appliedDefaultResolutionsByID.removeValue(forKey: tweak.id)
            publishTweaks()
            applySelectedVersion()
            reconcileAppliedDefaults()
        case let .unregister(id):
            cancelPendingAutoApply(for: id)
            tweaksByID.removeValue(forKey: id)
            compiledDefaultValuesByID.removeValue(forKey: id)
            effectiveDefaultValuesByID.removeValue(forKey: id)
            appliedDefaultResolutionsByID.removeValue(forKey: id)
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

    private func handleConnectionStatusChange(_ status: TinkerbleConnectionStatus) {
        connectionStatus = status
        switch status {
        case .disconnected:
            outboundChannel = nil
            hasLiveConnection = false
            cancelPendingAutoApplies()
        case .connecting, .connected, .failed:
            break
        }
    }

    func handleConnectionClosed(_ closedChannel: TinkerbleCompanionOutboundChannel) {
        guard outboundChannel === closedChannel else { return }
        outboundChannel = nil
        connectionStatus = .disconnected
        hasLiveConnection = false
        cancelPendingAutoApplies()
    }

    @discardableResult
    private func updateStoredTweak(id: String, value: TinkerbleValue) -> Bool {
        guard var tweak = tweaksByID[id] else { return false }
        tweak.value = value
        tweaksByID[id] = tweak
        publishTweaks()
        return true
    }

    private func categoryTweaks(_ category: String) -> [TinkerbleTweak] {
        tweaksByID.values.filter { tweak in
            tweak.screen == selectedScreen && tweak.category == category
        }
    }

    private func reconcileAppliedDefaults() {
        guard !tweaksByID.isEmpty else { return }
        guard let sourceProjectRoot else {
            scheduleOutstandingAutoApplies()
            return
        }
        appliedDefaultReconciliationGeneration += 1
        isReconcilingAppliedDefaults = true
        let generation = appliedDefaultReconciliationGeneration
        let projectID = projectIdentity.id
        let registeredTweaks = Array(tweaksByID.values)

        Task { [weak self] in
            guard let self else { return }
            do {
                let resolutions = try await self.appliedDefaultRepository.reconcile(
                    projectID: projectID,
                    projectRoot: sourceProjectRoot,
                    tweaks: registeredTweaks
                )
                guard generation == self.appliedDefaultReconciliationGeneration else { return }
                self.appliedDefaultResolutionsByID = resolutions
                for (id, resolution) in resolutions where self.tweaksByID[id] != nil {
                    self.effectiveDefaultValuesByID[id] = resolution.effectiveValue
                }
                self.isReconcilingAppliedDefaults = false
                self.applySelectedVersion()
                self.publishTweaks()
                self.scheduleOutstandingAutoApplies()
                self.resumePendingAutoApplies()
            } catch {
                guard generation == self.appliedDefaultReconciliationGeneration else { return }
                self.isReconcilingAppliedDefaults = false
                self.logs.append(
                    .init(
                        name: "Applied Defaults",
                        value: "Applied-default cache could not be loaded: \(error.localizedDescription)"
                    )
                )
                self.scheduleOutstandingAutoApplies()
                self.resumePendingAutoApplies()
            }
        }
    }

    private func scheduleAutoApplyAfterDirectUpdate(id: String, value: TinkerbleValue) {
        guard isAutoApplyEnabled else { return }
        cancelPendingAutoApply(for: id)

        switch value.kind {
        case .bool, .enumeration:
            requestAutoApplyNow(id: id, expectedValue: value)
        case .string, .color, .number, .date:
            let delay = autoApplyDelay
            autoApplyTasksByTweakID[id] = Task { @MainActor [weak self] in
                do {
                    try await Task.sleep(for: delay)
                } catch {
                    return
                }
                guard let self else { return }
                autoApplyTasksByTweakID.removeValue(forKey: id)
                requestAutoApplyNow(id: id, expectedValue: value)
            }
        case .action:
            break
        }
    }

    private func autoAppliesCoalescedUpdateAtInteractionEnd(id: String) -> Bool {
        guard let tweak = tweaksByID[id] else { return false }
        if case .slider = tweak.control {
            return true
        }
        return false
    }

    private func scheduleOutstandingAutoApplies() {
        for tweak in tweaksByID.values where effectiveDefaultValuesByID[tweak.id] != tweak.value {
            scheduleAutoApplyAfterDirectUpdate(id: tweak.id, value: tweak.value)
        }
    }

    private func requestAutoApplyNow(id: String, expectedValue: TinkerbleValue) {
        guard isAutoApplyEnabled,
              let tweak = tweaksByID[id],
              tweak.value == expectedValue,
              effectiveDefaultValuesByID[id] != expectedValue
        else {
            pendingAutoApplyValuesByTweakID.removeValue(forKey: id)
            return
        }

        guard !isReconcilingAppliedDefaults, !sourceEditingTweakIDs.contains(id) else {
            pendingAutoApplyValuesByTweakID[id] = expectedValue
            return
        }

        pendingAutoApplyValuesByTweakID.removeValue(forKey: id)
        applyTweaksToSource([tweak])
    }

    private func resumePendingAutoApplies() {
        guard isAutoApplyEnabled else {
            pendingAutoApplyValuesByTweakID.removeAll()
            return
        }

        let pendingValues = pendingAutoApplyValuesByTweakID
        for (id, value) in pendingValues {
            requestAutoApplyNow(id: id, expectedValue: value)
        }
    }

    private func cancelPendingAutoApply(for id: String) {
        autoApplyTasksByTweakID.removeValue(forKey: id)?.cancel()
        pendingAutoApplyValuesByTweakID.removeValue(forKey: id)
    }

    private func cancelPendingAutoApplies() {
        for task in autoApplyTasksByTweakID.values {
            task.cancel()
        }
        autoApplyTasksByTweakID.removeAll()
        pendingAutoApplyValuesByTweakID.removeAll()
    }

    private func removeUndoHistory(for id: String) {
        undoStack = undoStack.compactMap { $0.removingChange(for: id) }
        redoStack = redoStack.compactMap { $0.removingChange(for: id) }
        coalescedUndoStartValues.removeValue(forKey: id)
        updateUndoAvailability()
    }

    private func pruneUndoHistory(toValidTweakIDs validTweakIDs: Set<String>) {
        undoStack = undoStack.compactMap { $0.keepingChanges(for: validTweakIDs) }
        redoStack = redoStack.compactMap { $0.keepingChanges(for: validTweakIDs) }
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

    private func applySelectedVersion(schedulesAutoApply: Bool = false) {
        guard selectedVersionID != nil else {
            reloadVersionsForSelectedScreen()
            return
        }

        for tweak in versionedVisibleTweaks {
            applySelectedVersionValueIfNeeded(id: tweak.id, schedulesAutoApply: schedulesAutoApply)
        }
    }

    private func applySelectedVersionValueIfNeeded(id: String, schedulesAutoApply: Bool) {
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
                ?? effectiveDefaultValuesByID[id].flatMap { $0.kind == tweak.value.kind ? $0 : nil }
            guard let targetValue, targetValue != tweak.value else {
                return
            }
            updateStoredTweak(id: id, value: targetValue)
            send(.update(id: id, value: targetValue))
            if schedulesAutoApply {
                scheduleAutoApplyAfterDirectUpdate(id: id, value: targetValue)
            }
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
        logs.append(
            .init(name: "Version Persistence", value: "Version persistence failed: \(error.localizedDescription)")
        )
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

private struct TinkerbleTweakUndoChange {
    var id: String
    var previousValue: TinkerbleValue
    var nextValue: TinkerbleValue
}

private struct TinkerbleTweakUndoEntry {
    var changes: [TinkerbleTweakUndoChange]

    func removingChange(for id: String) -> Self? {
        let remainingChanges = changes.filter { $0.id != id }
        return remainingChanges.isEmpty ? nil : .init(changes: remainingChanges)
    }

    func keepingChanges(for validTweakIDs: Set<String>) -> Self? {
        let remainingChanges = changes.filter { validTweakIDs.contains($0.id) }
        return remainingChanges.isEmpty ? nil : .init(changes: remainingChanges)
    }
}

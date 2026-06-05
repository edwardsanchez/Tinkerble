import AppKit
import Observation
import SwiftUI
import Tinkerble
import TinkerbleCompanionCore

@main
@MainActor
struct TinkerbleCompanionApp: App {
    @NSApplicationDelegateAdaptor(CompanionAppDelegate.self) private var appDelegate
    @State private var store: TinkerbleCompanionStore
    @State private var windowLevel = HudWindowLevelState()

    init() {
        let store = TinkerbleCompanionStore()
        _store = State(wrappedValue: store)
        store.start()
    }

    var body: some Scene {
        WindowGroup {
            CompanionRootView(
                store: store,
                keepsWindowOnTop: windowLevel.keepsWindowOnTop
            )
        }
        .defaultSize(
            width: TinkerbleCompanionWindowLayout.width,
            height: TinkerbleCompanionWindowLayout.idealMaximumHeight
        )
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(after: .windowArrangement) {
                Toggle("Keep Window on Top", isOn: $windowLevel.keepsWindowOnTop)
            }
        }
    }
}

@Observable
@MainActor
private final class HudWindowLevelState {
    var keepsWindowOnTop = false
}

private final class CompanionAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        false
    }

    func applicationShouldSaveApplicationState(_ app: NSApplication, coder: NSCoder) -> Bool {
        false
    }

    func applicationShouldRestoreApplicationState(_ app: NSApplication, coder: NSCoder) -> Bool {
        false
    }
}

private struct CompanionRootView: View {
    var store: TinkerbleCompanionStore
    var keepsWindowOnTop: Bool
    @State private var measuredInspectorHeight: CGFloat = 0

    var body: some View {
//        VStack(spacing: 0) {
        //            HudTitleBar() //This is appearing below an invisible title bar so I am trying to hide it.
        //
        //        }
        TweakInspectorView(store: store) { height in
            measuredInspectorHeight = height
        }
        .frame(width: TinkerbleCompanionWindowLayout.width)
        .background {
            HudMaterialBackground().ignoresSafeArea()
                .overlay {
                    Rectangle()
                        .fill(.black.opacity(0.4))
                        .ignoresSafeArea()
                }
        }
        .background(
            HudWindowConfigurator(
                keepsWindowOnTop: keepsWindowOnTop,
                measuredInspectorHeight: measuredInspectorHeight
            )
        )
        .preferredColorScheme(.dark)

        //DO NOT DELETE
//        HStack(spacing: 0) {
//            LogConsoleView(logs: store.logs, status: store.connectionStatus)
//                .frame(minWidth: 360, idealWidth: 440)
//
//            Divider()
//
//            TweakInspectorView(store: store)
//                .frame(minWidth: 420, idealWidth: 520)
//        }
    }
}

private struct HudTitleBar: View {
    var body: some View {
        ZStack {
            Text("Tinkerble")
                .font(.headline)
                .bold()
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .center)

            WindowDragHandle()
        }
        .frame(height: TinkerbleCompanionWindowLayout.titleBarHeight)
        .contentShape(Rectangle())
    }
}

private struct HudWindowConfigurator: NSViewRepresentable {
    var keepsWindowOnTop: Bool
    var measuredInspectorHeight: CGFloat

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        Task { @MainActor in
            configure(view.window, coordinator: context.coordinator)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        Task { @MainActor in
            configure(nsView.window, coordinator: context.coordinator)
        }
    }

    private func configure(_ window: NSWindow?, coordinator: Coordinator) {
        guard let window else { return }

        window.title = "Tinkerble"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isOpaque = false
        window.backgroundColor = .clear
        window.appearance = NSAppearance(named: .darkAqua)
        window.hasShadow = false
        window.styleMask.insert(.titled)
        window.styleMask.insert(.resizable)
        window.styleMask.insert(.fullSizeContentView)
        window.styleMask.insert(.hudWindow)
        window.styleMask.remove(.closable)
        window.styleMask.remove(.miniaturizable)
        window.level = keepsWindowOnTop ? .floating : .normal

        [
            NSWindow.ButtonType.closeButton,
            .miniaturizeButton,
            .zoomButton,
        ].forEach { buttonType in
            window.standardWindowButton(buttonType)?.isHidden = true
        }

        let width = TinkerbleCompanionWindowLayout.width
        let minimumHeight = TinkerbleCompanionWindowLayout.minimumHeight
        let hasMeasuredContent = measuredInspectorHeight > 0
        let maximumHeight: CGFloat
        let preferredHeight: CGFloat
        if hasMeasuredContent {
            maximumHeight = TinkerbleCompanionWindowLayout.maximumHeight(
                forMeasuredInspectorHeight: measuredInspectorHeight
            )
            preferredHeight = TinkerbleCompanionWindowLayout.preferredHeight(
                forMeasuredInspectorHeight: measuredInspectorHeight
            )
        } else {
            maximumHeight = TinkerbleCompanionWindowLayout.idealMaximumHeight
            preferredHeight = TinkerbleCompanionWindowLayout.idealMaximumHeight
        }
        let chromeHeight = max(0, window.frame.height - (window.contentView?.bounds.height ?? window.frame.height))
        let contentMinimumHeight = max(1, minimumHeight - chromeHeight)
        let contentMaximumHeight = max(contentMinimumHeight, maximumHeight - chromeHeight)
        let currentHeight = window.frame.height
        let clampedHeight = min(max(currentHeight, minimumHeight), maximumHeight)
        let shouldClampToBounds = abs(currentHeight - clampedHeight) > 0.5
        let isStillAppManaged = coordinator.lastManagedHeight.map { abs(currentHeight - $0) <= 0.5 } ?? true
        let shouldApplyPreferredHeight = hasMeasuredContent &&
            isStillAppManaged &&
            abs(currentHeight - preferredHeight) > 0.5
        let targetHeight: CGFloat
        if shouldClampToBounds {
            targetHeight = clampedHeight
        } else if shouldApplyPreferredHeight {
            targetHeight = preferredHeight
        } else {
            targetHeight = currentHeight
        }

        window.minSize = CGSize(width: width, height: minimumHeight)
        window.maxSize = CGSize(width: width, height: maximumHeight)
        window.contentMinSize = CGSize(width: width, height: contentMinimumHeight)
        window.contentMaxSize = CGSize(width: width, height: contentMaximumHeight)

        if abs(window.frame.width - width) > 0.5 ||
            shouldClampToBounds ||
            shouldApplyPreferredHeight {
            let yDelta = currentHeight - targetHeight
            window.setFrame(
                NSRect(
                    x: window.frame.minX,
                    y: window.frame.minY + yDelta,
                    width: width,
                    height: targetHeight
                ),
                display: true
            )
            coordinator.lastManagedHeight = targetHeight
        } else if coordinator.lastManagedHeight == nil {
            coordinator.lastManagedHeight = currentHeight
        }
    }

    final class Coordinator {
        var lastManagedHeight: CGFloat?
    }
}

private struct WindowDragHandle: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        DraggableHeaderView()
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

private final class DraggableHeaderView: NSView {
    override func mouseDown(with event: NSEvent) {
        window?.performDrag(with: event)
    }
}

private struct HudMaterialBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.appearance = NSAppearance(named: .darkAqua)
        view.material = .hudWindow
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.appearance = NSAppearance(named: .darkAqua)
        nsView.material = .hudWindow
        nsView.blendingMode = .behindWindow
        nsView.state = .active
    }
}

private struct LogConsoleView: View {
    var logs: [TinkerbleLogEntry]
    var status: TinkerbleConnectionStatus

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Console")
                    .font(.headline)
                Spacer()
                Text(statusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding([.horizontal, .top], 16)
            .padding(.bottom, 10)

            Divider()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(logs) { log in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(log.date, style: .time)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text(log.message)
                                .font(.system(.body, design: .monospaced))
                                .textSelection(.enabled)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    if logs.isEmpty {
                        Text("Waiting for logs")
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 6)
                    }
                }
                .padding(16)
            }
        }
        .background(Color(nsColor: .textBackgroundColor))
    }

    private var statusText: String {
        switch status {
        case .disconnected:
            return "Disconnected"
        case let .connecting(endpoint):
            return "Connecting \(endpoint)"
        case let .connected(endpoint):
            return endpoint
        case let .failed(message):
            return "Failed: \(message)"
        }
    }
}

private struct TweakInspectorView: View {
    var store: TinkerbleCompanionStore
    var measuredHeightChanged: (CGFloat) -> Void

    var body: some View {
        ScrollView {
            TweakInspectorContent(store: store)
        }
        .background {
            TweakInspectorContent(store: store)
                .fixedSize(horizontal: false, vertical: true)
                .hidden()
                .onGeometryChange(for: CGFloat.self) { proxy in
                    proxy.size.height
                } action: { height in
                    measuredHeightChanged(height)
                }
        }
    }
}

private struct TweakInspectorContent: View {
    var store: TinkerbleCompanionStore

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            ForEach(store.groupedTweaks) { group in
                VStack(alignment: .leading, spacing: 10) {
                    if let category = group.category {
                        Text(category)
                            .font(.subheadline)
                            .bold()
                            .foregroundStyle(.secondary)
                    }

                    ForEach(group.tweaks) { tweak in
                        TweakRow(tweak: tweak, store: store)
                    }
                }
            }

            if store.tweaks.isEmpty {
                EmptyTweakPlaceholderView()
            }
        }
        .padding(.horizontal, TinkerbleCompanionWindowLayout.inspectorHorizontalPadding)
        .padding(.top, TinkerbleCompanionWindowLayout.inspectorTopPadding)
        .padding(.bottom, TinkerbleCompanionWindowLayout.inspectorBottomPadding)
    }
}

private struct TweakRow: View {
    var tweak: TinkerbleTweak
    var store: TinkerbleCompanionStore

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 14) {
            Text(tweak.name)
                .font(.body)
                .bold()
                .foregroundStyle(.primary)
                .lineLimit(2)
                .frame(width: 116, alignment: .leading)

            control
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var control: some View {
        switch tweak.value {
        case .string:
            stringControl
        case .bool:
            Toggle("", isOn: boolBinding)
                .labelsHidden()
                .toggleStyle(.switch)
        case .color:
            ColorPicker("", selection: colorBinding, supportsOpacity: true)
                .labelsHidden()
        case .number:
            numberControl
        case .enumCase:
            Picker("", selection: enumBinding) {
                ForEach(tweak.enumOptions) { option in
                    Text(option.displayName).tag(option.id)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
        }
    }

    @ViewBuilder
    private var stringControl: some View {
        switch resolvedTextControlStyle {
        case .area:
            TextEditor(text: stringBinding)
                .font(.body)
                .frame(minHeight: 72)
                .overlay {
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(Color(nsColor: .separatorColor))
                }
        case .field, .automatic:
            TextField("", text: stringBinding)
                .textFieldStyle(.roundedBorder)
        }
    }

    @ViewBuilder
    private var numberControl: some View {
        switch tweak.control {
        case let .slider(configuration):
            HStack {
                Slider(
                    value: numberBinding,
                    in: (configuration.minimum ?? 0)...(configuration.maximum ?? 1),
                    step: configuration.step
                )
                Text(formattedNumber)
                    .font(.system(.body, design: .monospaced))
                    .frame(width: 52, alignment: .trailing)
            }
        case let .stepper(configuration):
            HStack {
                TextField("", text: numberTextBinding(configuration: configuration))
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 86)
                Stepper(
                    "",
                    value: numberBinding,
                    in: (configuration.minimum ?? -Double.greatestFiniteMagnitude)...(configuration.maximum ?? Double.greatestFiniteMagnitude),
                    step: configuration.step
                )
                .labelsHidden()
            }
        case .text:
            TextField("", text: numberTextBinding(configuration: .init(decimalPlaces: 2)))
                .textFieldStyle(.roundedBorder)
                .frame(width: 96)
        case .automatic:
            TextField("", text: numberTextBinding(configuration: .init(decimalPlaces: 2)))
                .textFieldStyle(.roundedBorder)
                .frame(width: 96)
        }
    }

    private var stringBinding: Binding<String> {
        Binding(
            get: {
                guard case let .string(value) = tweak.value else { return "" }
                return value
            },
            set: { store.updateTweak(id: tweak.id, value: .string($0)) }
        )
    }

    private var resolvedTextControlStyle: TinkerbleTextControlStyle {
        guard case let .string(value) = tweak.value else { return .field }
        guard case let .text(configuration) = tweak.control else { return .field }
        return configuration.resolvedStyle(for: value)
    }

    private var boolBinding: Binding<Bool> {
        Binding(
            get: {
                guard case let .bool(value) = tweak.value else { return false }
                return value
            },
            set: { store.updateTweak(id: tweak.id, value: .bool($0)) }
        )
    }

    private var colorBinding: Binding<Color> {
        Binding(
            get: {
                guard case let .color(value) = tweak.value else { return .accentColor }
                return value.swiftUIColor
            },
            set: { store.updateTweak(id: tweak.id, value: .color(TinkerbleColor($0))) }
        )
    }

    private var numberBinding: Binding<Double> {
        Binding(
            get: {
                guard case let .number(value) = tweak.value else { return 0 }
                return value
            },
            set: { store.updateTweak(id: tweak.id, value: .number($0)) }
        )
    }

    private var enumBinding: Binding<String> {
        Binding(
            get: {
                guard case let .enumCase(value) = tweak.value else { return tweak.enumOptions.first?.id ?? "" }
                return value
            },
            set: { store.updateTweak(id: tweak.id, value: .enumCase($0)) }
        )
    }

    private var formattedNumber: String {
        let places: Int
        if case let .slider(configuration) = tweak.control {
            places = configuration.decimalPlaces
        } else {
            places = 2
        }
        guard case let .number(value) = tweak.value else { return "0" }
        return value.formatted(.number.precision(.fractionLength(places)))
    }

    private func numberTextBinding(configuration: TinkerbleNumericControl) -> Binding<String> {
        Binding(
            get: {
                guard case let .number(value) = tweak.value else { return "0" }
                return value.formatted(.number.precision(.fractionLength(configuration.decimalPlaces)))
            },
            set: { text in
                guard let value = Double(text) else { return }
                store.updateTweak(id: tweak.id, value: .number(value))
            }
        )
    }
}

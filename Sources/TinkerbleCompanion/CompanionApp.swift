import SwiftUI
import Tinkerble
import TinkerbleCompanionCore

@main
struct TinkerbleCompanionApp: App {
    @StateObject private var store = TinkerbleCompanionStore()

    var body: some Scene {
        WindowGroup {
            CompanionRootView(store: store)
                .frame(minWidth: 920, minHeight: 560)
                .task {
                    store.start()
                }
        }
    }
}

private struct CompanionRootView: View {
    @ObservedObject var store: TinkerbleCompanionStore

    var body: some View {
        TweakInspectorView(store: store)
            .frame(minWidth: 420, idealWidth: 520)

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
    @ObservedObject var store: TinkerbleCompanionStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Text("Tweaks")
                        .font(.headline)
                    Spacer()
                }

                ForEach(store.groupedTweaks) { group in
                    VStack(alignment: .leading, spacing: 10) {
                        if let category = group.category {
                            Text(category)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }

                        ForEach(group.tweaks) { tweak in
                            TweakRow(tweak: tweak, store: store)
                        }
                    }
                }

                if store.tweaks.isEmpty {
                    Text("Waiting for registered values")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(18)
        }
    }
}

private struct TweakRow: View {
    var tweak: TinkerbleTweak
    @ObservedObject var store: TinkerbleCompanionStore

    var body: some View {
        Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 14, verticalSpacing: 8) {
            GridRow {
                Text(tweak.name)
                    .frame(width: 120, alignment: .leading)
                control
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    @ViewBuilder
    private var control: some View {
        switch tweak.value {
        case .string:
            TextField("", text: stringBinding)
                .textFieldStyle(.roundedBorder)
        case .bool:
            Toggle("", isOn: boolBinding)
                .labelsHidden()
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
                    .frame(width: 64, alignment: .trailing)
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

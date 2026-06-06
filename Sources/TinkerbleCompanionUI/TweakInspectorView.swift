import SwiftUI
import Tinkerble
import TinkerbleCompanionCore

struct TweakInspectorView: View {
    var store: TinkerbleCompanionStore
    var measuredHeightChanged: (CGFloat) -> Void

    var body: some View {
        ScrollView {
            TweakInspectorContent(
                groups: store.groupedTweaks,
                isEmpty: store.tweaks.isEmpty,
                updateTweak: store.updateTweak
            )
        }
        .background {
            TweakInspectorContent(
                groups: store.groupedTweaks,
                isEmpty: store.tweaks.isEmpty,
                updateTweak: store.updateTweak
            )
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

struct TweakInspectorContent: View {
    var groups: [TinkerbleTweakGroup]
    var isEmpty: Bool
    var updateTweak: (String, TinkerbleValue) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            ForEach(groups) { group in
                VStack(alignment: .leading, spacing: 10) {
                    if let category = group.category {
                        Text(category)
                            .font(.subheadline)
                            .bold()
                            .foregroundStyle(.primary)
                            .textCase(.uppercase)
                            .padding(.top, group.id == groups.first?.id ? 0 : 15)
                    }

                    ForEach(group.tweaks) { tweak in
                        TweakRow(tweak: tweak, updateTweak: updateTweak)
                    }
                }
            }

            if isEmpty {
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
    var updateTweak: (String, TinkerbleValue) -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Text(tweak.name)
                .font(.callout)
                .bold()
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .frame(width: 116, alignment: .leading)

            control
                .frame(maxWidth: .infinity, alignment: .trailing)
                .font(.callout)
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
                .frame(minHeight: 72)
                .padding(.bottom, 15)

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
                .controlSize(.mini)
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
            set: { updateTweak(tweak.id, .string($0)) }
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
            set: { updateTweak(tweak.id, .bool($0)) }
        )
    }

    private var colorBinding: Binding<Color> {
        Binding(
            get: {
                guard case let .color(value) = tweak.value else { return .accentColor }
                return value.swiftUIColor
            },
            set: { updateTweak(tweak.id, .color(TinkerbleColor($0))) }
        )
    }

    private var numberBinding: Binding<Double> {
        Binding(
            get: {
                guard case let .number(value) = tweak.value else { return 0 }
                return value
            },
            set: { updateTweak(tweak.id, .number($0)) }
        )
    }

    private var enumBinding: Binding<String> {
        Binding(
            get: {
                guard case let .enumCase(value) = tweak.value else { return tweak.enumOptions.first?.id ?? "" }
                return value
            },
            set: { updateTweak(tweak.id, .enumCase($0)) }
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
                updateTweak(tweak.id, .number(value))
            }
        )
    }
}

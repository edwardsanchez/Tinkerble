#if os(macOS)
import AppKit
#endif
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
                            .padding(.top, Self.categoryHeaderTopPadding(for: group, in: groups))
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

    static func categoryHeaderTopPadding(for group: TinkerbleTweakGroup, in groups: [TinkerbleTweakGroup]) -> CGFloat {
        group.id == groups.first?.id ? 0 : 15
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
        case let .plain(configuration):
            TinkerbleNumberFieldView(
                value: numberValue,
                configuration: configuration,
                showsDragHandle: false,
                updateValue: updateNumberValue
            )
        case let .slider(configuration):
            TinkerbleNumberFieldView(
                value: numberValue,
                configuration: configuration,
                showsDragHandle: true,
                updateValue: updateNumberValue
            )
        case .text:
            TinkerbleNumberFieldView(
                value: numberValue,
                configuration: .init(decimalPlaces: 2),
                showsDragHandle: false,
                updateValue: updateNumberValue
            )
        case .automatic:
            TinkerbleNumberFieldView(
                value: numberValue,
                configuration: .init(decimalPlaces: 2),
                showsDragHandle: false,
                updateValue: updateNumberValue
            )
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

    private var numberValue: Double {
        guard case let .number(value) = tweak.value else { return 0 }
        return value
    }

    private func updateNumberValue(_ value: Double) {
        updateTweak(tweak.id, .number(value))
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

}

private struct TinkerbleNumberFieldView: View {
    var value: Double
    var configuration: TinkerbleNumericControl
    var showsDragHandle: Bool
    var updateValue: (Double) -> Void

    @FocusState private var isFocused: Bool
    @State private var dragStartValue: Double?

    var body: some View {
        HStack(spacing: 6) {
            if showsDragHandle {
                Button("Adjust value", systemImage: "chevron.left.chevron.right") {}
                    .labelStyle(.iconOnly)
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .frame(width: 18, height: 22)
                    .contentShape(.rect)
                    .modifier(ResizeLeftRightCursorModifier())
                    .gesture(dragGesture)
            }

            TextField("", text: numberTextBinding)
                .textFieldStyle(.roundedBorder)
                .focused($isFocused)
                .frame(width: 96)
                .multilineTextAlignment(.trailing)
                .onKeyPress(.upArrow, phases: [.down, .repeat]) { keyPress in
                    handleKeyPress(.increment, modifiers: keyPress.modifiers)
                }
                .onKeyPress(.downArrow, phases: [.down, .repeat]) { keyPress in
                    handleKeyPress(.decrement, modifiers: keyPress.modifiers)
                }
        }
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .global)
            .onChanged { value in
                let startValue = dragStartValue ?? self.value
                dragStartValue = startValue
                updateValue(
                    TinkerbleNumericInteraction.draggedValue(
                        from: startValue,
                        horizontalTranslation: value.translation.width,
                        configuration: configuration
                    )
                )
            }
            .onEnded { _ in
                dragStartValue = nil
            }
    }

    private var numberTextBinding: Binding<String> {
        Binding(
            get: {
                return value.formatted(.number.precision(.fractionLength(configuration.decimalPlaces)))
            },
            set: { text in
                guard let value = Double(text) else { return }
                updateValue(TinkerbleNumericInteraction.adjustedTextValue(value, configuration: configuration))
            }
        )
    }

    private func handleKeyPress(
        _ direction: TinkerbleNumericArrowDirection,
        modifiers: EventModifiers
    ) -> KeyPress.Result {
        guard isFocused else { return .ignored }
        updateValue(
            TinkerbleNumericInteraction.adjustedValue(
                from: value,
                direction: direction,
                modifiers: .init(modifiers),
                configuration: configuration
            )
        )
        return .handled
    }
}

private struct ResizeLeftRightCursorModifier: ViewModifier {
    func body(content: Content) -> some View {
        #if os(macOS)
        content
            .onHover { isHovering in
                if isHovering {
                    NSCursor.resizeLeftRight.push()
                } else {
                    NSCursor.pop()
                }
            }
        #else
        content
        #endif
    }
}

private extension TinkerbleNumericKeyboardModifiers {
    init(_ modifiers: EventModifiers) {
        var options: Self = []
        if modifiers.contains(.shift) {
            options.insert(.shift)
        }
        if modifiers.contains(.option) {
            options.insert(.option)
        }
        self = options
    }
}

#Preview("Plain Number Field") {
    TinkerbleNumberFieldView(
        value: 42,
        configuration: .init(decimalPlaces: 0),
        showsDragHandle: false,
        updateValue: { _ in }
    )
    .padding()
}

#Preview("Ranged Number Field") {
    TinkerbleNumberFieldView(
        value: 0.65,
        configuration: .init(minimum: 0, maximum: 1, step: 0.01, decimalPlaces: 2),
        showsDragHandle: true,
        updateValue: { _ in }
    )
    .padding()
}

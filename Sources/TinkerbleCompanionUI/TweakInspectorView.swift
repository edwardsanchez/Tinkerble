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
                screens: store.screens,
                selectedScreen: selectedScreenBinding,
                updateTweak: store.updateTweak
            )
        }
        .background {
            TweakInspectorContent(
                groups: store.groupedTweaks,
                isEmpty: store.tweaks.isEmpty,
                screens: store.screens,
                selectedScreen: selectedScreenBinding,
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

    private var selectedScreenBinding: Binding<String> {
        Binding(
            get: { store.selectedScreen },
            set: { store.selectScreen($0) }
        )
    }
}

struct TweakInspectorContent: View {
    var groups: [TinkerbleTweakGroup]
    var isEmpty: Bool
    var screens: [String]
    @Binding var selectedScreen: String
    var updateTweak: (String, TinkerbleValue) -> Void

    init(
        groups: [TinkerbleTweakGroup],
        isEmpty: Bool,
        screens: [String] = [],
        selectedScreen: Binding<String> = .constant(TinkerbleTweak.defaultScreenName),
        updateTweak: @escaping (String, TinkerbleValue) -> Void
    ) {
        self.groups = groups
        self.isEmpty = isEmpty
        self.screens = screens
        _selectedScreen = selectedScreen
        self.updateTweak = updateTweak
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            if screens.count > 1 {
                TweakScreenSelectorView(screens: screens, selectedScreen: $selectedScreen)
            }

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

private struct TweakScreenSelectorView: View {
    let screens: [String]
    @Binding var selectedScreen: String

    var body: some View {
        ViewThatFits(in: .horizontal) {
            Picker("", selection: $selectedScreen) {
                ForEach(screens, id: \.self) { screen in
                    Text(screen)
                        .fixedSize(horizontal: true, vertical: false)
                        .tag(screen)
                }
            }
            .labelsHidden()
            .pickerStyle(.segmented)

            Picker("", selection: $selectedScreen) {
                ForEach(screens, id: \.self) { screen in
                    Text(screen)
                        .tag(screen)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
        }
        .frame(maxWidth: .infinity, alignment: .center)
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
        case .date:
            dateControl
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
                .monospacedDigit()
        }
    }

    @ViewBuilder
    private var numberControl: some View {
        switch tweak.control {
        case let .plain(configuration):
            TinkerbleNumberFieldView(
                value: numberDisplayValue(for: configuration),
                configuration: configuration,
                showsDragHandle: false,
                updateValue: { updateNumberDisplayValue($0, configuration: configuration) }
            )
        case let .slider(configuration):
            TinkerbleNumberFieldView(
                value: numberDisplayValue(for: configuration),
                configuration: configuration,
                showsDragHandle: true,
                updateValue: { updateNumberDisplayValue($0, configuration: configuration) }
            )
        case .text:
            fallbackNumberControl
        case .automatic:
            fallbackNumberControl
        case .date:
            fallbackNumberControl
        }
    }

    @ViewBuilder
    private var fallbackNumberControl: some View {
        let configuration = TinkerbleNumericControl(decimalPlaces: 2)
        TinkerbleNumberFieldView(
            value: numberValue,
            configuration: configuration,
            showsDragHandle: false,
            updateValue: updateNumberValue
        )
    }

    @ViewBuilder
    private var dateControl: some View {
        TinkerbleDatePickerView(selection: dateBinding, components: dateControlComponents)
    }

    private var dateControlComponents: TinkerbleDateControlComponents {
        guard case let .date(configuration) = tweak.control else {
            return .dateAndTime
        }
        return configuration.components
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

    private func numberDisplayValue(for configuration: TinkerbleNumericControl) -> Double {
        guard let angleUnit = configuration.angleUnit else { return numberValue }
        return angleUnit.displayValue(fromStoredRadians: numberValue)
    }

    private func updateNumberValue(_ value: Double) {
        updateTweak(tweak.id, .number(value))
    }

    private func updateNumberDisplayValue(_ value: Double, configuration: TinkerbleNumericControl) {
        guard let angleUnit = configuration.angleUnit else {
            updateNumberValue(value)
            return
        }
        updateNumberValue(angleUnit.storedRadians(fromDisplayValue: value))
    }

    private var dateBinding: Binding<Date> {
        Binding(
            get: {
                guard case let .date(value) = tweak.value else { return Date() }
                return value
            },
            set: { updateTweak(tweak.id, .date($0)) }
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

}

struct TinkerbleNumberFieldView: View {
    var value: Double
    var configuration: TinkerbleNumericControl
    var showsDragHandle: Bool
    var updateValue: (Double) -> Void

    @FocusState private var isFocused: Bool
    @State private var dragStartValue: Double?
    @State private var displayedValue: Double?
    @State private var editingText: String?

    var body: some View {
        HStack(spacing: 6) {
            if showsDragHandle {
                Image(systemName: "chevron.left.chevron.right")
                    .foregroundStyle(.secondary)
                    .frame(width: 18, height: 22)
                    .contentShape(.rect)
                    .accessibilityLabel("Adjust value")
                    .modifier(ResizeLeftRightCursorModifier())
                    .gesture(dragGesture)
            }

            TextField("", text: numberTextBinding)
                .textFieldStyle(.roundedBorder)
                .focused($isFocused)
                .frame(width: 96)
                .multilineTextAlignment(.trailing)
                .monospacedDigit()
                .id(textFieldRefreshID)
                .onSubmit {
                    editingText = nil
                }
                .onKeyPress(.upArrow, phases: [.down, .repeat]) { keyPress in
                    handleKeyPress(.increment, modifiers: keyPress.modifiers)
                }
                .onKeyPress(.downArrow, phases: [.down, .repeat]) { keyPress in
                    handleKeyPress(.decrement, modifiers: keyPress.modifiers)
                }
        }
        .onChange(of: value) { _, newValue in
            guard dragStartValue == nil else { return }
            displayedValue = newValue
        }
        .onChange(of: isFocused) { _, isFocused in
            editingText = isFocused ? textValue(for: currentValue) : nil
        }
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .global)
            .onChanged { value in
                let startValue = dragStartValue ?? currentValue
                dragStartValue = startValue
                commitValue(
                    TinkerbleNumericInteraction.draggedValue(
                        from: startValue,
                        horizontalTranslation: value.translation.width,
                        modifiers: .current,
                        configuration: configuration
                    ),
                    refreshEditingText: true
                )
            }
            .onEnded { _ in
                dragStartValue = nil
            }
    }

    private var numberTextBinding: Binding<String> {
        Binding(
            get: {
                if isFocused, let editingText {
                    return editingText
                }
                return textValue(for: currentValue)
            },
            set: { text in
                editingText = text
                guard let value = Self.number(from: text, configuration: configuration) else { return }
                commitValue(TinkerbleNumericInteraction.adjustedTextValue(value, configuration: configuration))
            }
        )
    }

    private var currentValue: Double {
        displayedValue ?? value
    }

    private var textFieldRefreshID: String {
        dragStartValue == nil ? "idle" : textValue(for: currentValue)
    }

    private func handleKeyPress(
        _ direction: TinkerbleNumericArrowDirection,
        modifiers: EventModifiers
    ) -> KeyPress.Result {
        guard isFocused else { return .ignored }
        commitValue(
            TinkerbleNumericInteraction.adjustedValue(
                from: currentValue,
                direction: direction,
                modifiers: .init(modifiers),
                configuration: configuration
            ),
            refreshEditingText: true
        )
        return .handled
    }

    private func commitValue(_ value: Double, refreshEditingText: Bool = false) {
        displayedValue = value
        if refreshEditingText, isFocused {
            editingText = textValue(for: value)
        }
        updateValue(value)
    }

    private func textValue(for value: Double) -> String {
        let number = value.formatted(.number.precision(.fractionLength(configuration.decimalPlaces)))
        guard configuration.angleUnit == .degrees else { return number }
        return "\(number)º"
    }

    static func number(from text: String, configuration: TinkerbleNumericControl) -> Double? {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedText: String
        if configuration.angleUnit == .degrees {
            normalizedText = trimmedText
                .replacing("º", with: "")
                .replacing("°", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            normalizedText = trimmedText
        }
        return Double(normalizedText)
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
    static var current: Self {
        #if os(macOS)
        var options: Self = []
        let flags = NSEvent.modifierFlags
        if flags.contains(.shift) {
            options.insert(.shift)
        }
        if flags.contains(.option) {
            options.insert(.option)
        }
        return options
        #else
        []
        #endif
    }

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
    @Previewable @State var plainValue = 42.0

    TinkerbleNumberFieldView(
        value: plainValue,
        configuration: .init(decimalPlaces: 0),
        showsDragHandle: false,
        updateValue: { plainValue = $0 }
    )
    .padding()
}

#Preview("Ranged Number Field") {
    @Previewable @State var rangedValue = 0.65

    TinkerbleNumberFieldView(
        value: rangedValue,
        configuration: .init(minimum: 0, maximum: 1, step: 0.01, decimalPlaces: 2),
        showsDragHandle: true,
        updateValue: { rangedValue = $0 }
    )
    .padding()
}

#Preview("Angle Field") {
    @Previewable @State var angleValue = 45.0

    TinkerbleNumberFieldView(
        value: angleValue,
        configuration: .init(minimum: 0, maximum: 360, step: 1, decimalPlaces: 0, angleUnit: .degrees),
        showsDragHandle: true,
        updateValue: { angleValue = $0 }
    )
    .padding()
}

import SwiftUI
import Tinkerble

struct TinkerbleStringControlView: View {
    private static let checkpointInterval: Duration = .seconds(2)

    var value: String
    var style: TinkerbleTextControlStyle
    var beginCoalescedUpdate: () -> Void
    var updateCoalescedValue: (String) -> Void
    var endCoalescedUpdate: () -> Void

    @FocusState private var isFocused: Bool
    @State private var editingText: String?
    @State private var isCoalescing = false
    @State private var hasPendingCheckpoint = false
    @State private var checkpointTask: Task<Void, Never>?

    var body: some View {
        Group {
            switch style {
            case .area:
                TextEditor(text: textBinding)
                    .focused($isFocused)
                    .frame(minHeight: 72)
                    .padding(.bottom, 15)

            case .field, .automatic:
                TextField("", text: textBinding)
                    .focused($isFocused)
                    .textFieldStyle(.roundedBorder)
                    .monospacedDigit()
            }
        }
        .onChange(of: value) { _, newValue in
            guard !isFocused else { return }
            editingText = newValue
        }
        .onChange(of: isFocused) { _, isFocused in
            if isFocused {
                editingText = value
            } else {
                finishCoalescedEditing()
            }
        }
        .onDisappear {
            finishCoalescedEditing()
        }
    }

    private var textBinding: Binding<String> {
        Binding(
            get: {
                if isFocused, let editingText {
                    return editingText
                }
                return value
            },
            set: { text in
                editingText = text
                beginCoalescedEditingIfNeeded()
                hasPendingCheckpoint = true
                updateCoalescedValue(text)
                scheduleCheckpointIfNeeded()
            }
        )
    }

    private func beginCoalescedEditingIfNeeded() {
        guard !isCoalescing else { return }
        isCoalescing = true
        beginCoalescedUpdate()
    }

    private func scheduleCheckpointIfNeeded() {
        guard checkpointTask == nil else { return }
        checkpointTask = Task { @MainActor in
            try? await Task.sleep(for: Self.checkpointInterval)
            checkpointTask = nil
            checkpointCoalescedEditing()
        }
    }

    private func checkpointCoalescedEditing() {
        guard isCoalescing, hasPendingCheckpoint else { return }
        endCoalescedUpdate()
        beginCoalescedUpdate()
        hasPendingCheckpoint = false
    }

    private func finishCoalescedEditing() {
        checkpointTask?.cancel()
        checkpointTask = nil
        guard isCoalescing else {
            editingText = nil
            hasPendingCheckpoint = false
            return
        }
        endCoalescedUpdate()
        isCoalescing = false
        hasPendingCheckpoint = false
        editingText = nil
    }
}

#Preview("String Field") {
    @Previewable @State var value = "Debug label"

    TinkerbleStringControlView(
        value: value,
        style: .field,
        beginCoalescedUpdate: {},
        updateCoalescedValue: { value = $0 },
        endCoalescedUpdate: {}
    )
    .padding()
}

#Preview("String Area") {
    @Previewable @State var value = "Line one\nLine two"

    TinkerbleStringControlView(
        value: value,
        style: .area,
        beginCoalescedUpdate: {},
        updateCoalescedValue: { value = $0 },
        endCoalescedUpdate: {}
    )
    .padding()
}

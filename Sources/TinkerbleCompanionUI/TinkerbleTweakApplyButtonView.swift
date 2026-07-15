import SwiftUI

struct TinkerbleTweakApplyButtonView: View {
    var tweakID: String
    var tweakName: String
    var isRowHovered: Bool
    var isEnabled: Bool
    var isApplying: Bool
    var wasRecentlyApplied: Bool
    var apply: () -> Void

    @State private var isHoverRevealReady = false
    @FocusState private var isFocused: Bool

    var body: some View {
        Button(action: apply) {
            Label("Apply", systemImage: wasRecentlyApplied ? "checkmark" : "arrow.up.right")
                .labelStyle(.iconOnly)
                .padding(6)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .focused($isFocused)
        .disabled(!isEnabled || isApplying)
        .opacity(isVisible ? 1 : 0)
        .allowsHitTesting(isVisible)
        .help("Apply")
        .accessibilityLabel("Apply \(tweakName) to code")
        .accessibilityIdentifier("TinkerbleApplyValue.\(tweakID)")
        .animation(.smooth(duration: 0.5), value: isFocused)
        .animation(.smooth(duration: 0.5), value: wasRecentlyApplied)
        .task(id: isRowHovered) {
            if isRowHovered {
                do {
                    try await Task.sleep(for: .milliseconds(300))
                } catch {
                    return
                }
                guard !Task.isCancelled else { return }
                withAnimation(.smooth(duration: 0.5)) {
                    isHoverRevealReady = true
                }
            } else {
                withAnimation(.smooth(duration: 0.1)) {
                    isHoverRevealReady = false
                }
            }
        }
    }

    private var isVisible: Bool {
        isHoverRevealReady || isFocused || isApplying || wasRecentlyApplied
    }
}

#Preview("Apply Value") {
    TinkerbleTweakApplyButtonView(
        tweakID: "Basic/Layout/Opacity",
        tweakName: "Opacity",
        isRowHovered: true,
        isEnabled: true,
        isApplying: false,
        wasRecentlyApplied: false,
        apply: {}
    )
    .padding()
}

import SwiftUI

struct TinkerbleTweakApplyButtonView: View {
    var tweakID: String
    var tweakName: String
    var isRowHovered: Bool
    var isEnabled: Bool
    var isApplying: Bool
    var wasRecentlyApplied: Bool
    var isAutoApplyEnabled: Bool
    var apply: () -> Void

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
        .accessibilityHidden(!isVisible)
        .help("Apply")
        .accessibilityLabel("Apply \(tweakName) to code")
        .accessibilityIdentifier("TinkerbleApplyValue.\(tweakID)")
        .animation(.smooth(duration: 0.15), value: isRowHovered)
        .animation(.smooth(duration: 0.5), value: isFocused)
        .animation(.smooth(duration: 0.5), value: wasRecentlyApplied)
        .animation(.smooth(duration: 0.15), value: isAutoApplyEnabled)
    }

    private var isVisible: Bool {
        Self.isVisible(
            isRowHovered: isRowHovered,
            isFocused: isFocused,
            isApplying: isApplying,
            wasRecentlyApplied: wasRecentlyApplied,
            isAutoApplyEnabled: isAutoApplyEnabled
        )
    }

    static func isVisible(
        isRowHovered: Bool,
        isFocused: Bool,
        isApplying: Bool,
        wasRecentlyApplied: Bool,
        isAutoApplyEnabled: Bool
    ) -> Bool {
        !isAutoApplyEnabled && (isRowHovered || isFocused || isApplying || wasRecentlyApplied)
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
        isAutoApplyEnabled: false,
        apply: {}
    )
    .padding()
}

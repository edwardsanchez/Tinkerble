import SwiftUI

struct TinkerbleTweakCategoryHeaderView: View {
    var category: String
    var canApplyValues: Bool
    var canResetValues: Bool
    var isApplyingValues: Bool
    var applyValues: () -> Void
    var resetValues: () -> Void

    var body: some View {
        HStack {
            Text(category)
                .font(.subheadline)
                .bold()
                .foregroundStyle(.primary)
                .textCase(.uppercase)

            Spacer()

            Menu {
                Button("Apply Values to Code", systemImage: "arrow.up.right") {
                    applyValues()
                }
                .disabled(!canApplyValues || isApplyingValues)

                Button("Reset to Defaults", systemImage: "arrow.counterclockwise") {
                    resetValues()
                }
                .disabled(!canResetValues || isApplyingValues)
            } label: {
                Label("Category actions", systemImage: "ellipsis")
                    .labelStyle(.iconOnly)
            }
            .menuIndicator(.hidden)
            .menuStyle(.borderlessButton)
            .disabled(isApplyingValues)
            .accessibilityLabel("Actions for \(category)")
            .accessibilityIdentifier("TinkerbleCategoryActions.\(category)")
        }
    }
}

#Preview("Category Actions") {
    TinkerbleTweakCategoryHeaderView(
        category: "Layout",
        canApplyValues: true,
        canResetValues: true,
        isApplyingValues: false,
        applyValues: {},
        resetValues: {}
    )
    .padding()
    .frame(width: 420)
}

import SwiftUI
import TinkerbleCompanionCore

struct TinkerbleAutoApplyView: View {
    @Binding var isEnabled: Bool

    var body: some View {
        VStack(spacing: 0) {
            Divider()

            HStack(alignment: .center) {
                Text("Auto-Apply")
                    .font(.callout)
                    .bold()
                    .foregroundStyle(.secondary)

                Spacer()

                Toggle("Auto-Apply", isOn: $isEnabled)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .accessibilityIdentifier("TinkerbleAutoApplyToggle")
            }
            .padding(.horizontal, TinkerbleCompanionWindowLayout.inspectorHorizontalPadding)
            .padding(.vertical)
        }
    }
}

#Preview("Auto-Apply Off") {
    @Previewable @State var isEnabled = false

    TinkerbleAutoApplyView(isEnabled: $isEnabled)
        .frame(width: TinkerbleCompanionWindowLayout.width)
        .background(.black)
        .preferredColorScheme(.dark)
}

#Preview("Auto-Apply On") {
    @Previewable @State var isEnabled = true

    TinkerbleAutoApplyView(isEnabled: $isEnabled)
        .frame(width: TinkerbleCompanionWindowLayout.width)
        .background(.black)
        .preferredColorScheme(.dark)
}

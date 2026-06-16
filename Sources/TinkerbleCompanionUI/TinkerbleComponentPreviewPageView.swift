import SwiftUI
import Tinkerble
import TinkerbleCompanionCore

public struct TinkerbleComponentPreviewPageView: View {
    private static let previewVersionID = UUID()

    @State private var tweaks = TinkerbleComponentPreviewFixture.tweaks
    @State private var selectedVersionID: UUID? = Self.previewVersionID

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                TweakInspectorContent(
                    groups: TinkerbleTweakGrouping.groupedTweaks(from: tweaks),
                    isEmpty: tweaks.isEmpty,
                    versions: [TinkerbleSavedVersion(id: Self.previewVersionID, ordinal: 1)],
                    selectedVersionID: $selectedVersionID,
                    canResetSelectedVersion: true,
                    updateTweak: updateTweak
                )
            }
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
        .preferredColorScheme(.dark)
    }

    private func updateTweak(id: String, value: TinkerbleValue) {
        guard let index = tweaks.firstIndex(where: { $0.id == id }) else { return }
        tweaks[index].value = value
    }
}

#Preview("All Tinkerble Components") {
    TinkerbleComponentPreviewPageView()
        .frame(height: TinkerbleCompanionWindowLayout.idealMaximumHeight)
}

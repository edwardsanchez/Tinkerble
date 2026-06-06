import SwiftUI
import TinkerbleCompanionCore

public struct CompanionRootView: View {
    var store: TinkerbleCompanionStore
    var keepsWindowOnTop: Bool
    @State private var measuredInspectorHeight: CGFloat = 0

    public init(store: TinkerbleCompanionStore, keepsWindowOnTop: Bool) {
        self.store = store
        self.keepsWindowOnTop = keepsWindowOnTop
    }

    public var body: some View {
        TweakInspectorView(store: store) { height in
            measuredInspectorHeight = height
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
        .background(
            HudWindowConfigurator(
                keepsWindowOnTop: keepsWindowOnTop,
                measuredInspectorHeight: measuredInspectorHeight
            )
        )
        .preferredColorScheme(.dark)
    }
}

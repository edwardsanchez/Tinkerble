import SwiftUI
import TinkerbleCompanionCore

public struct CompanionRootView: View {
    var store: TinkerbleCompanionStore
    var keepsWindowOnTop: Bool
    @State private var measuredInspectorHeight: CGFloat = 0
    @State private var measuredAutoApplyHeight: CGFloat = 0

    public init(store: TinkerbleCompanionStore, keepsWindowOnTop: Bool) {
        self.store = store
        self.keepsWindowOnTop = keepsWindowOnTop
    }

    public var body: some View {
        VStack(spacing: 0) {
            TweakInspectorView(store: store) { height in
                measuredInspectorHeight = height
            }

            if store.hasLiveConnection {
                TinkerbleAutoApplyView(isEnabled: autoApplyBinding)
                    .onGeometryChange(for: CGFloat.self) { proxy in
                        proxy.size.height
                    } action: { height in
                        measuredAutoApplyHeight = height
                    }
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
        .background(
            HudWindowConfigurator(
                keepsWindowOnTop: keepsWindowOnTop,
                measuredInspectorHeight: measuredInspectorHeight
                    + (store.hasLiveConnection ? measuredAutoApplyHeight : 0)
            )
        )
        .preferredColorScheme(.dark)
    }

    private var autoApplyBinding: Binding<Bool> {
        Binding(
            get: { store.isAutoApplyEnabled },
            set: { store.setAutoApplyEnabled($0) }
        )
    }
}

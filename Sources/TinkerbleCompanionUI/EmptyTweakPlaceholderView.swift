import AppKit
import SwiftUI
import TinkerbleCompanionCore

struct EmptyTweakPlaceholderView: View {
    var body: some View {
        VStack {
            if let imageURL = TinkerbleCompanionEmptyStateResource.wingsURL,
               let image = NSImage(contentsOf: imageURL) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: TinkerbleCompanionEmptyStateLayout.imageWidth)
                    // The HUD keeps a hidden titlebar region; center the artwork in the full window.
                    .offset(y: -TinkerbleCompanionWindowLayout.titleBarHeight)
                    .opacity(0.7)
            }

            Text("No Tinkerble Properties Found")
                .foregroundStyle(.secondary)
                .font(.title3)
        }
        .frame(
            maxWidth: .infinity,
            minHeight: TinkerbleCompanionEmptyStateLayout.contentHeight,
            alignment: .center
        )
    }
}

#Preview {
    EmptyTweakPlaceholderView()
        .frame(width: TinkerbleCompanionWindowLayout.width)
        .background(.black)
        .preferredColorScheme(.dark)
}

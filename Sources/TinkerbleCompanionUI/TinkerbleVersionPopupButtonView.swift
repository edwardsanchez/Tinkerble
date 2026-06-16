import AppKit
import SwiftUI
import TinkerbleCompanionCore

struct TinkerbleVersionPopupButtonView: NSViewRepresentable {
    var versions: [TinkerbleSavedVersion]
    @Binding var selectedVersionID: UUID?

    func makeCoordinator() -> Coordinator {
        Coordinator(selectedVersionID: $selectedVersionID)
    }

    func makeNSView(context: Context) -> NSPopUpButton {
        let popUpButton = NSPopUpButton(frame: .zero, pullsDown: false)
        popUpButton.bezelStyle = .rounded
        popUpButton.controlSize = .large
        popUpButton.setContentHuggingPriority(.defaultLow, for: .horizontal)
        popUpButton.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        popUpButton.target = context.coordinator
        popUpButton.action = #selector(Coordinator.selectionDidChange(_:))
        popUpButton.identifier = NSUserInterfaceItemIdentifier("TinkerbleVersionPopupButton")
        return popUpButton
    }

    func updateNSView(_ popUpButton: NSPopUpButton, context: Context) {
        context.coordinator.selectedVersionID = $selectedVersionID
        context.coordinator.versionIDs = versions.map(\.id)

        let selectedTitle = versions.first { $0.id == selectedVersionID }?.name
        let currentTitles = popUpButton.itemArray.map(\.title)
        let versionTitles = versions.map(\.name)
        if currentTitles != versionTitles {
            popUpButton.removeAllItems()
            popUpButton.addItems(withTitles: versionTitles)
        }

        if let selectedTitle {
            popUpButton.selectItem(withTitle: selectedTitle)
        } else {
            popUpButton.selectItem(at: 0)
        }
    }

    final class Coordinator: NSObject {
        var selectedVersionID: Binding<UUID?>
        var versionIDs: [UUID] = []

        init(selectedVersionID: Binding<UUID?>) {
            self.selectedVersionID = selectedVersionID
        }

        @objc func selectionDidChange(_ sender: NSPopUpButton) {
            let selectedIndex = sender.indexOfSelectedItem
            guard versionIDs.indices.contains(selectedIndex) else { return }
            selectedVersionID.wrappedValue = versionIDs[selectedIndex]
        }
    }
}

private let tinkerbleVersionPopupPreviewID = UUID()
private let tinkerbleVersionPopupPreviewVersions = [
    TinkerbleSavedVersion(id: tinkerbleVersionPopupPreviewID, ordinal: 1),
    TinkerbleSavedVersion(id: UUID(), ordinal: 2),
]

#Preview("Version Pop-Up") {
    @Previewable @State var selectedVersionID: UUID? = tinkerbleVersionPopupPreviewID

    TinkerbleVersionPopupButtonView(
        versions: tinkerbleVersionPopupPreviewVersions,
        selectedVersionID: $selectedVersionID
    )
    .frame(maxWidth: .infinity)
    .padding()
}

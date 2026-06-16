import SwiftUI
import TinkerbleCompanionCore

struct TinkerbleVersionControlBarView: View {
    var versions: [TinkerbleSavedVersion]
    @Binding var selectedVersionID: UUID?
    var canDeleteSelectedVersion: Bool
    var canResetSelectedVersion: Bool
    var createVersion: () -> Void
    var resetSelectedVersion: () -> Void
    var deleteSelectedVersion: () -> Void

    @State private var isDeleteConfirmationPresented = false

    private var content: TinkerbleVersionControlContent {
        TinkerbleVersionControlContent(
            versions: versions,
            selectedVersionID: selectedVersionID,
            canDeleteSelectedVersion: canDeleteSelectedVersion,
            canResetSelectedVersion: canResetSelectedVersion
        )
    }

    var body: some View {
        HStack {
            Button("New Version", systemImage: "plus") {
                createVersion()
            }
            .labelStyle(.iconOnly)
            .help("New Version")

            TinkerbleVersionPopupButtonView(versions: versions, selectedVersionID: $selectedVersionID)
            .frame(maxWidth: .infinity)

            Button(content.versionActionTitle, systemImage: content.versionActionSystemImage) {
                if canResetSelectedVersion {
                    resetSelectedVersion()
                } else {
                    isDeleteConfirmationPresented = true
                }
            }
            .labelStyle(.iconOnly)
            .help(content.versionActionTitle)
            .disabled(content.isVersionActionDisabled)
        }
        .confirmationDialog(
            content.deleteConfirmationTitle,
            isPresented: $isDeleteConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button("Delete Version", role: .destructive) {
                deleteSelectedVersion()
            }
            Button("Cancel", role: .cancel) {}
        }
    }
}

private let tinkerbleVersionControlPreviewID = UUID()
private let tinkerbleVersionControlPreviewVersions = [
    TinkerbleSavedVersion(id: tinkerbleVersionControlPreviewID, ordinal: 1),
    TinkerbleSavedVersion(id: UUID(), ordinal: 2),
]

#Preview("Version Control") {
    @Previewable @State var selectedVersionID: UUID? = tinkerbleVersionControlPreviewID

    TinkerbleVersionControlBarView(
        versions: tinkerbleVersionControlPreviewVersions,
        selectedVersionID: $selectedVersionID,
        canDeleteSelectedVersion: false,
        canResetSelectedVersion: true,
        createVersion: {},
        resetSelectedVersion: {},
        deleteSelectedVersion: {}
    )
    .padding()
}

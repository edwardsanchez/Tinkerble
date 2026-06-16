import Foundation
import TinkerbleCompanionCore

struct TinkerbleVersionControlContent: Equatable {
    var versions: [TinkerbleSavedVersion]
    var selectedVersionID: UUID?
    var canDeleteSelectedVersion: Bool
    var canResetSelectedVersion: Bool

    static func isVisible(isEmpty: Bool, versions: [TinkerbleSavedVersion]) -> Bool {
        !isEmpty && !versions.isEmpty
    }

    var selectedVersionName: String {
        versions.first { $0.id == selectedVersionID }?.name ?? "Version"
    }

    var deleteConfirmationTitle: String {
        "Delete \(selectedVersionName)?"
    }

    var versionActionTitle: String {
        canResetSelectedVersion ? "Reset Version" : "Delete Version"
    }

    var versionActionSystemImage: String {
        canResetSelectedVersion ? "slider.horizontal.2.arrow.trianglehead.counterclockwise" : "trash"
    }

    var isVersionActionDisabled: Bool {
        !canResetSelectedVersion && !canDeleteSelectedVersion
    }
}

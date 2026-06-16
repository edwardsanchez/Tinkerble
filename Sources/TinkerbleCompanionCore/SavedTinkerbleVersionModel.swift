import Foundation
import SwiftData

@Model
final class SavedTinkerbleVersionModel {
    var id: UUID
    var projectID: String
    var screen: String
    var ordinal: Int
    var createdAt: Date
    var updatedAt: Date

    init(id: UUID = UUID(), projectID: String, screen: String, ordinal: Int, date: Date = Date()) {
        self.id = id
        self.projectID = projectID
        self.screen = screen
        self.ordinal = ordinal
        createdAt = date
        updatedAt = date
    }

    var savedVersion: TinkerbleSavedVersion {
        TinkerbleSavedVersion(id: id, ordinal: ordinal)
    }
}

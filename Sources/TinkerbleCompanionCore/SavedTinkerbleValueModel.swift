import Foundation
import SwiftData
import Tinkerble

@Model
final class SavedTinkerbleValueModel {
    var id: UUID
    var projectID: String
    var screen: String
    var versionID: UUID
    var tweakID: String
    var valueKind: String
    var encodedValue: Data
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        projectID: String,
        screen: String,
        versionID: UUID,
        tweakID: String,
        value: TinkerbleValue,
        encodedValue: Data,
        date: Date = Date()
    ) {
        self.id = id
        self.projectID = projectID
        self.screen = screen
        self.versionID = versionID
        self.tweakID = tweakID
        valueKind = value.kind.rawValue
        self.encodedValue = encodedValue
        updatedAt = date
    }
}

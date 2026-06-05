import Foundation

struct TinkerbleRegistrationToken: Hashable, Sendable {
    let instanceID = UUID()
    let tweakID: String
}

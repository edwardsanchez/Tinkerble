import Foundation
import TinkerbleCompanionCore

enum TinkerbleCompanionEmptyStateResource {
    static var wingsURL: URL? {
        Bundle.main.url(
            forResource: TinkerbleCompanionEmptyStateLayout.imageResourceName,
            withExtension: TinkerbleCompanionEmptyStateLayout.imageResourceExtension
        ) ?? Bundle.module.url(
            forResource: TinkerbleCompanionEmptyStateLayout.imageResourceName,
            withExtension: TinkerbleCompanionEmptyStateLayout.imageResourceExtension
        )
    }
}

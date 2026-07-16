import Foundation
@testable import TinkerbleCompanionCore
import XCTest

@MainActor
final class TinkerbleAutoApplyPreferenceTests: XCTestCase {
    func testAutoApplyPreferenceSurvivesStoreRecreation() {
        let preference = InMemoryAutoApplyPreference()
        var store: TinkerbleCompanionStore? = makeStore(preference: preference)

        XCTAssertFalse(store?.isAutoApplyEnabled == true)

        store?.setAutoApplyEnabled(true)
        store = nil
        store = makeStore(preference: preference)

        XCTAssertTrue(store?.isAutoApplyEnabled == true)
    }

    func testUserDefaultsPreferenceDefaultsOffAndPersistsEnabledState() throws {
        let suiteName = "TinkerbleAutoApplyPreferenceTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        addTeardownBlock {
            defaults.removePersistentDomain(forName: suiteName)
        }

        var preference: TinkerbleUserDefaultsAutoApplyPreference? = .init(defaults: defaults)
        XCTAssertFalse(preference?.isEnabled == true)

        preference?.isEnabled = true
        preference = .init(defaults: defaults)

        XCTAssertTrue(preference?.isEnabled == true)
    }

    private func makeStore(preference: any TinkerbleAutoApplyPreference) -> TinkerbleCompanionStore {
        TinkerbleCompanionStore(
            versionRepository: TinkerbleInMemoryVersionRepository(),
            autoApplyPreference: preference
        )
    }
}

@MainActor
private final class InMemoryAutoApplyPreference: TinkerbleAutoApplyPreference {
    var isEnabled = false
}

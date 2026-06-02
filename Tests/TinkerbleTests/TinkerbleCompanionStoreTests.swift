import XCTest
@testable import Tinkerble
@testable import TinkerbleCompanionCore

@MainActor
final class TinkerbleCompanionStoreTests: XCTestCase {
    func testCompanionGroupsUncategorizedTweaksBeforeCategorizedTweaks() {
        let store = TinkerbleCompanionStore()

        store.handle(
            .register(
                TinkerbleTweak(
                    id: "Title",
                    category: nil,
                    name: "Title",
                    value: .string("Demo"),
                    valueKind: .string,
                    control: .automatic
                )
            ),
            outbound: nil
        )
        store.handle(
            .register(
                TinkerbleTweak(
                    id: "Layout/Width",
                    category: "Layout",
                    name: "Width",
                    value: .number(120),
                    valueKind: .number,
                    control: TinkerbleControl<Int>.stepper().descriptor
                )
            ),
            outbound: nil
        )

        XCTAssertEqual(store.groupedTweaks.map(\.category), [nil, "Layout"])
        XCTAssertEqual(store.groupedTweaks[0].tweaks.map(\.name), ["Title"])
    }

    func testCompanionStoresIncomingLogs() {
        let store = TinkerbleCompanionStore()
        let entry = TinkerbleLogEntry(message: "User tapped Save")

        store.handle(.log(entry), outbound: nil)

        XCTAssertEqual(store.logs, [entry])
    }
}

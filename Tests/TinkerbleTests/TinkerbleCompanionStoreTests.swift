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
                    control: TinkerbleControl<Int>.plain.descriptor
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

    func testCompanionRemovesTweaksWhenTheyUnregister() {
        let store = TinkerbleCompanionStore()

        store.handle(
            .register(
                TinkerbleTweak(
                    id: "Lifetime State/Message",
                    category: "Lifetime State",
                    name: "Message",
                    value: .string("Loaded"),
                    valueKind: .string,
                    control: .automatic
                )
            ),
            outbound: nil
        )

        XCTAssertEqual(store.tweaks.map(\.id), ["Lifetime State/Message"])

        store.handle(.unregister(id: "Lifetime State/Message"), outbound: nil)

        XCTAssertTrue(store.tweaks.isEmpty)
        XCTAssertTrue(store.groupedTweaks.isEmpty)
    }
}

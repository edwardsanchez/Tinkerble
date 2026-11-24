import SwiftUI
import XCTest
@testable import Tinkerble
@testable import TinkerbleCompanionCore

@MainActor
final class TinkerbleTweakOrderingTests: XCTestCase {
    // MARK: - Ordering rule

    func testControlsInOneFileFollowLineOrderNotNameOrder() {
        let tweaks = [
            makeTweak("Alpha", line: 30),
            makeTweak("Zeta", line: 10),
            makeTweak("Mid", line: 20)
        ]

        XCTAssertEqual(TinkerbleTweakOrdering.sorted(tweaks).map(\.name), ["Zeta", "Mid", "Alpha"])
    }

    func testControlsOnTheSameLineFollowColumnOrder() {
        let tweaks = [
            makeTweak("Alpha", line: 10, column: 40),
            makeTweak("Zeta", line: 10, column: 5)
        ]

        XCTAssertEqual(TinkerbleTweakOrdering.sorted(tweaks).map(\.name), ["Zeta", "Alpha"])
    }

    func testControlsFromTwoFilesComeOutFileByFile() {
        let tweaks = [
            makeTweak("B Early", file: "/App/B.swift", line: 1),
            makeTweak("A Late", file: "/App/A.swift", line: 90),
            makeTweak("B Late", file: "/App/B.swift", line: 50),
            makeTweak("A Early", file: "/App/A.swift", line: 3)
        ]

        XCTAssertEqual(
            TinkerbleTweakOrdering.sorted(tweaks).map(\.name),
            ["A Early", "A Late", "B Early", "B Late"]
        )
    }

    func testCategoriesFollowTheirFirstDeclaredControlAndUncategorizedComesFirst() {
        let tweaks = [
            makeTweak("Opacity", category: "Appearance", line: 40),
            makeTweak("Width", category: "Layout", line: 10),
            makeTweak("Title", line: 60),
            makeTweak("Tint", category: "Appearance", line: 20),
            makeTweak("Height", category: "Layout", line: 50)
        ]

        let sorted = TinkerbleTweakOrdering.sorted(tweaks)

        XCTAssertEqual(sorted.map(\.name), ["Title", "Width", "Height", "Tint", "Opacity"])
        XCTAssertEqual(sorted.map(\.category), [nil, "Layout", "Layout", "Appearance", "Appearance"])
    }

    func testActionDeclaredBelowPropertiesComesLast() {
        let file = "/App/CardView.swift"
        let tweaks = [
            makeAction("Aardvark Reset", category: "Deck", location: .init(filePath: file, line: 40, column: 13)),
            makeTweak("Zeta Width", category: "Deck", file: file, line: 5),
            makeTweak("Alpha Height", category: "Deck", file: file, line: 6)
        ]

        XCTAssertEqual(
            TinkerbleTweakOrdering.sorted(tweaks).map(\.name),
            ["Zeta Width", "Alpha Height", "Aardvark Reset"]
        )
    }

    func testControlWithoutLocationComesAfterLocatedControlsInNameOrder() {
        let tweaks = [
            makeTweak("Beta Unlocated", line: nil),
            makeTweak("Zeta", line: 20),
            makeTweak("Alpha Unlocated", line: nil),
            makeTweak("Yak", line: 10)
        ]

        XCTAssertEqual(
            TinkerbleTweakOrdering.sorted(tweaks).map(\.name),
            ["Yak", "Zeta", "Alpha Unlocated", "Beta Unlocated"]
        )
    }

    func testCategoryWithoutAnyLocationComesAfterLocatedCategories() {
        let tweaks = [
            makeTweak("Legacy", category: "Aardvark", line: nil),
            makeTweak("Width", category: "Zebra", line: 10)
        ]

        XCTAssertEqual(TinkerbleTweakOrdering.sorted(tweaks).map(\.category), ["Zebra", "Aardvark"])
    }

    func testControlWithSeveralAnchorsUsesItsEarliestOne() {
        var shared = makeTweak("Shared", file: "/App/B.swift", line: 80)
        shared.sourceAnchors.append(makeAnchor(propertyName: "Shared", file: "/App/A.swift", line: 2))
        let tweaks = [
            makeTweak("Other", file: "/App/A.swift", line: 10),
            shared
        ]

        XCTAssertEqual(TinkerbleTweakOrdering.sorted(tweaks).map(\.name), ["Shared", "Other"])
    }

    func testScreensKeepNameOrder() {
        let tweaks = [
            makeTweak("Second", screen: "Zoo", line: 1),
            makeTweak("First", screen: "Aquarium", line: 99)
        ]

        XCTAssertEqual(TinkerbleTweakOrdering.sorted(tweaks).map(\.screen), ["Aquarium", "Zoo"])
    }

    func testTweakDecodedWithoutDeclarationLocationStillSorts() throws {
        let action = makeAction("Reset", location: .init(filePath: "/App/A.swift", line: 1, column: 1))
        var json = try XCTUnwrap(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(action)) as? [String: Any]
        )
        XCTAssertNotNil(json["declarationLocation"])
        json.removeValue(forKey: "declarationLocation")
        json.removeValue(forKey: "sourceAnchors")

        let legacyAction = try JSONDecoder().decode(
            TinkerbleTweak.self,
            from: JSONSerialization.data(withJSONObject: json)
        )
        let sorted = TinkerbleTweakOrdering.sorted([legacyAction, makeTweak("Width", line: 10)])

        XCTAssertNil(legacyAction.declarationLocation)
        XCTAssertEqual(sorted.map(\.name), ["Width", "Reset"])
    }

    func testDeclarationLocationRoundTripsThroughTheWireCodec() throws {
        let location = TinkerbleSourceLocation(filePath: "/App/A.swift", line: 12, column: 9)
        let message = TinkerbleWireMessage.register(makeAction("Reset", location: location))

        let decoded = try JSONDecoder().decode(TinkerbleWireMessage.self, from: JSONEncoder().encode(message))

        guard case let .register(tweak) = decoded else {
            return XCTFail("Expected a register message")
        }
        XCTAssertEqual(tweak.declarationLocation, location)
        XCTAssertTrue(tweak.sourceAnchors.isEmpty)
    }

    // MARK: - Identity across a reorder

    func testMovingADeclarationKeepsItsIdentity() {
        let before = makeAnchor(propertyName: "width", file: "/App/A.swift", line: 10)
        var after = before
        after.line = 42
        after.column = 9
        let projectRoot = URL(fileURLWithPath: "/App")

        XCTAssertEqual(before.stableID, after.stableID)
        XCTAssertEqual(
            TinkerbleAppliedDefaultKey(projectID: "app", projectRoot: projectRoot, anchor: before),
            TinkerbleAppliedDefaultKey(projectID: "app", projectRoot: projectRoot, anchor: after)
        )
        XCTAssertEqual(
            TinkerbleTweak.makeID(screen: "Cards", category: "Layout", name: "Width"),
            "Cards/Layout/Width"
        )
    }

    // MARK: - App registry

#if DEBUG
    func testRegistryOrdersPropertiesThenAnActionCalledInBody() throws {
        Tinkerble.shared.resetForTesting(transport: OrderingRecordingTransport())
        addTeardownBlock { @MainActor in
            Tinkerble.shared.resetForTesting()
        }

        let fixture = DeclarationOrderFixtureView()
        let body = fixture.body

        let registered = Tinkerble.shared.registeredTweaks
        XCTAssertEqual(registered.map(\.name), ["Zeta Width", "Alpha Height", "Aardvark Reset"])
        let action = try XCTUnwrap(registered.last)
        XCTAssertTrue(action.sourceAnchors.isEmpty)
        let location = try XCTUnwrap(action.declarationLocation)
        XCTAssertTrue(location.filePath.hasSuffix("TinkerbleTweakOrderingTests.swift"))
        withExtendedLifetime(body) {}
    }

    func testObservableActionMacroOrdersByMethodDeclaration() {
        Tinkerble.shared.resetForTesting(transport: OrderingRecordingTransport())
        addTeardownBlock { @MainActor in
            Tinkerble.shared.resetForTesting()
        }

        let model = DeclarationOrderActionsFixture()
        model.activateTinkerbleActions()

        XCTAssertEqual(Tinkerble.shared.registeredTweaks.map(\.name), ["Zeta Shuffle", "Alpha Deal"])
    }

    func testDuplicateActionKeepsItsEarliestLiveCallSite() {
        let transport = OrderingRecordingTransport()
        Tinkerble.shared.resetForTesting(transport: transport)
        addTeardownBlock { @MainActor in
            Tinkerble.shared.resetForTesting()
        }
        let late = TinkerbleSourceLocation(filePath: "/App/A.swift", line: 90, column: 5)
        let early = TinkerbleSourceLocation(filePath: "/App/A.swift", line: 3, column: 5)

        _ = Tinkerble.shared.registerAction(id: "Reset", category: nil, name: "Reset", declarationLocation: late) {}
        let earlyToken = Tinkerble.shared.registerAction(
            id: "Reset",
            category: nil,
            name: "Reset",
            declarationLocation: early
        ) {}

        XCTAssertEqual(Tinkerble.shared.registeredTweaks.first?.declarationLocation, early)
        XCTAssertEqual(transport.registeredTweaks.last?.declarationLocation, early)

        Tinkerble.shared.unregister(earlyToken)

        XCTAssertEqual(Tinkerble.shared.registeredTweaks.first?.declarationLocation, late)
        XCTAssertEqual(transport.registeredTweaks.last?.declarationLocation, late)
    }
#endif

    // MARK: - Companion

    func testCompanionListsAndGroupsTweaksInDeclarationOrder() {
        let store = TinkerbleCompanionStore()
        let file = "/App/CardView.swift"
        let tweaks = [
            makeAction("Aardvark Reset", category: "Deck", location: .init(filePath: file, line: 40, column: 13)),
            makeTweak("Opacity", category: "Appearance", file: file, line: 20),
            makeTweak("Zeta Width", category: "Deck", file: file, line: 5),
            makeTweak("Title", file: file, line: 30),
            makeTweak("Alpha Height", category: "Deck", file: file, line: 6)
        ]
        store.handle(.snapshot(tweaks), outboundChannel: nil)

        XCTAssertEqual(
            store.tweaks.map(\.name),
            ["Title", "Zeta Width", "Alpha Height", "Aardvark Reset", "Opacity"]
        )
        XCTAssertEqual(store.groupedTweaks.map(\.category), [nil, "Deck", "Appearance"])
        XCTAssertEqual(
            store.groupedTweaks.map { $0.tweaks.map(\.name) },
            [["Title"], ["Zeta Width", "Alpha Height", "Aardvark Reset"], ["Opacity"]]
        )
        XCTAssertFalse(store.canApplyTweakToSource("Deck/Aardvark Reset"))
    }

    func testGroupingOrdersUnsortedInputByDeclaration() {
        let groups = TinkerbleTweakGrouping.groupedTweaks(from: [
            makeTweak("Second", category: "Zebra", line: 2),
            makeTweak("Fourth", category: "Aardvark", line: 4),
            makeTweak("Third", category: "Zebra", line: 3),
            makeTweak("First", line: 9)
        ])

        XCTAssertEqual(groups.map(\.category), [nil, "Zebra", "Aardvark"])
        XCTAssertEqual(groups.map { $0.tweaks.map(\.name) }, [["First"], ["Second", "Third"], ["Fourth"]])
    }

}

// MARK: - Helpers

private extension TinkerbleTweakOrderingTests {
    func makeTweak(
        _ name: String,
        category: String? = nil,
        screen: String? = nil,
        file: String = "/App/Screen.swift",
        line: Int?,
        column: Int = 5
    ) -> TinkerbleTweak {
        TinkerbleTweak(
            id: TinkerbleTweak.makeID(screen: screen, category: category, name: name),
            screen: screen,
            category: category,
            name: name,
            value: .number(1),
            valueKind: .number,
            control: .automatic,
            sourceValueType: .double,
            sourceAnchors: line.map { [makeAnchor(propertyName: name, file: file, line: $0, column: column)] } ?? []
        )
    }

    func makeAction(
        _ name: String,
        category: String? = nil,
        location: TinkerbleSourceLocation?
    ) -> TinkerbleTweak {
        TinkerbleTweak(
            id: TinkerbleTweak.makeID(category: category, name: name),
            category: category,
            name: name,
            value: .action,
            valueKind: .action,
            control: .automatic,
            declarationLocation: location
        )
    }

    func makeAnchor(propertyName: String, file: String, line: Int, column: Int = 5) -> TinkerbleSourceAnchor {
        TinkerbleSourceAnchor(
            filePath: file,
            line: line,
            column: column,
            enclosingTypePath: ["Fixture"],
            propertyName: propertyName,
            initializerExpression: "1"
        )
    }
}

#if DEBUG
/// Names are deliberately the reverse of declaration order, so name order and declaration
/// order disagree.
private struct DeclarationOrderFixtureView: View {
    @TinkerbleState("Zeta Width", screen: "Ordering", category: "Deck")
    var zetaWidth = 1.0

    @TinkerbleState("Alpha Height", screen: "Ordering", category: "Deck")
    var alphaHeight = 2.0

    var body: some View {
        Color.clear
            .tinkerbleAction("Aardvark Reset", screen: "Ordering", category: "Deck") {}
    }
}

@TinkerbleActions
@Observable
@MainActor
private final class DeclarationOrderActionsFixture {
    @TinkerbleAction("Zeta Shuffle", screen: "Ordering")
    func shuffle() {}

    @TinkerbleAction("Alpha Deal", screen: "Ordering")
    func deal() {}
}

#Preview("Declaration Order Fixture") {
    DeclarationOrderFixtureView()
}
#endif

private final class OrderingRecordingTransport: TinkerbleClientTransport {
    var onMessage: ((TinkerbleWireMessage) -> Void)?
    var onStatusChange: ((TinkerbleConnectionStatus) -> Void)?
    private(set) var sentMessages: [TinkerbleWireMessage] = []

    var registeredTweaks: [TinkerbleTweak] {
        sentMessages.compactMap { message in
            guard case let .register(tweak) = message else { return nil }
            return tweak
        }
    }

    func connect(host: String?, port: Int) {}

    func send(_ message: TinkerbleWireMessage) {
        sentMessages.append(message)
    }

    func disconnect() {}
}

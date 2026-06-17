import XCTest
@testable import Tinkerble
@testable import TinkerbleCompanionCore
@testable import TinkerbleCompanionUI

final class TinkerbleLogsViewTests: XCTestCase {
    func testLogGroupingCreatesNoCardsBeforeValuesArrive() {
        XCTAssertEqual(TinkerbleLogGrouping.cards(from: [], screen: TinkerbleTweak.defaultScreenName), [])
    }

    func testLogGroupingCreatesDefaultCategoryCardWithLatestValueAndHistory() {
        let firstDate = Date(timeIntervalSinceReferenceDate: 1)
        let secondDate = Date(timeIntervalSinceReferenceDate: 2)
        let entries = [
            TinkerbleLogEntry(name: "FPS", value: 57.5, date: firstDate),
            TinkerbleLogEntry(name: "FPS", value: 58.25, date: secondDate)
        ]

        let cards = TinkerbleLogGrouping.cards(from: entries, screen: TinkerbleTweak.defaultScreenName)

        XCTAssertEqual(cards.map(\.category), [TinkerbleLogEntry.defaultCategoryName])
        XCTAssertEqual(cards.first?.rows.map(\.name), ["FPS"])
        XCTAssertEqual(cards.first?.rows.first?.displayValue, "58.25")
        XCTAssertEqual(cards.first?.rows.first?.history.map(\.date), [firstDate, secondDate])
        XCTAssertEqual(cards.first?.lastUpdated, secondDate)
    }

    func testLogGroupingSeparatesScreensAndCategoriesInArrivalOrder() {
        let entries = [
            TinkerbleLogEntry(screen: "Cards", category: "Deck", name: "Visible Cards", value: 7),
            TinkerbleLogEntry(screen: "Cards", category: "Scroll View", name: "Offset", value: 12.5),
            TinkerbleLogEntry(screen: "Details", category: "Selection", name: "Title", value: "Queen")
        ]

        XCTAssertEqual(TinkerbleLogGrouping.screens(from: entries), ["Cards", "Details"])

        let cards = TinkerbleLogGrouping.cards(from: entries, screen: "Cards")

        XCTAssertEqual(cards.map(\.category), ["Deck", "Scroll View"])
        XCTAssertEqual(cards.flatMap(\.rows).map(\.displayValue), ["7", "12.5"])
    }

    func testLogCardExportIncludesTimestampedValues() throws {
        let date = Date(timeIntervalSince1970: 1_772_000_000)
        let card = try XCTUnwrap(
            TinkerbleLogGrouping.cards(
                from: [
                    TinkerbleLogEntry(
                        screen: "Cards",
                        category: "Deck",
                        name: "Selected Suit",
                        value: "Hearts",
                        date: date
                    )
                ],
                screen: "Cards"
            )
            .first
        )

        XCTAssertEqual(card.exportText.split(separator: "\n").first, "Timestamp\tScreen\tCategory\tName\tValue")
        XCTAssertTrue(card.exportText.localizedStandardContains("Cards\tDeck\tSelected Suit\tHearts"))
    }

    func testLogWindowPresentationOpensOnlyForFirstNonEmptyLogCount() {
        var presentation = TinkerbleLogWindowPresentationState()

        XCTAssertFalse(presentation.shouldOpenLogsWindow(logCount: 0))
        XCTAssertTrue(presentation.shouldOpenLogsWindow(logCount: 1))
        XCTAssertFalse(presentation.shouldOpenLogsWindow(logCount: 2))
        XCTAssertFalse(presentation.shouldOpenLogsWindow(logCount: 0))
        XCTAssertFalse(presentation.shouldOpenLogsWindow(logCount: 1))
    }
}

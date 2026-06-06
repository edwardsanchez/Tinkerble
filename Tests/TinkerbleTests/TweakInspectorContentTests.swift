import XCTest
@testable import Tinkerble
@testable import TinkerbleCompanionUI

final class TweakInspectorContentTests: XCTestCase {
    func testCategoryHeaderTopPaddingIsZeroForFirstGroup() {
        let firstGroup = TinkerbleTweakGroup(category: "Layout", tweaks: [])
        let secondGroup = TinkerbleTweakGroup(category: "Text", tweaks: [])

        XCTAssertEqual(
            TweakInspectorContent.categoryHeaderTopPadding(for: firstGroup, in: [firstGroup, secondGroup]),
            0
        )
    }

    func testCategoryHeaderTopPaddingIsFifteenForNonFirstGroup() {
        let firstGroup = TinkerbleTweakGroup(category: "Layout", tweaks: [])
        let secondGroup = TinkerbleTweakGroup(category: "Text", tweaks: [])

        XCTAssertEqual(
            TweakInspectorContent.categoryHeaderTopPadding(for: secondGroup, in: [firstGroup, secondGroup]),
            15
        )
    }
}

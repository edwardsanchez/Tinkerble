import AppKit
import XCTest
import SwiftUI
@testable import Tinkerble
@testable import TinkerbleCompanionCore
@testable import TinkerbleCompanionUI

final class TweakInspectorContentTests: XCTestCase {
    func testVersionControlContentShowsOnlyWhenTweaksAndVersionsExist() {
        let version = TinkerbleSavedVersion(id: UUID(), ordinal: 1)

        XCTAssertFalse(TinkerbleVersionControlContent.isVisible(isEmpty: true, versions: [version]))
        XCTAssertFalse(TinkerbleVersionControlContent.isVisible(isEmpty: false, versions: []))
        XCTAssertTrue(TinkerbleVersionControlContent.isVisible(isEmpty: false, versions: [version]))
    }

    func testVersionControlContentDescribesSelectedVersionDeletion() {
        let versionOne = TinkerbleSavedVersion(id: UUID(), ordinal: 1)
        let versionTwo = TinkerbleSavedVersion(id: UUID(), ordinal: 2)

        let protectedContent = TinkerbleVersionControlContent(
            versions: [versionOne, versionTwo],
            selectedVersionID: versionOne.id,
            canDeleteSelectedVersion: false,
            canResetSelectedVersion: true
        )
        let deletableContent = TinkerbleVersionControlContent(
            versions: [versionOne, versionTwo],
            selectedVersionID: versionTwo.id,
            canDeleteSelectedVersion: true,
            canResetSelectedVersion: false
        )

        XCTAssertFalse(protectedContent.canDeleteSelectedVersion)
        XCTAssertEqual(protectedContent.deleteConfirmationTitle, "Delete Version 1?")
        XCTAssertEqual(protectedContent.versionActionTitle, "Reset Version")
        XCTAssertEqual(
            protectedContent.versionActionSystemImage,
            "slider.horizontal.2.arrow.trianglehead.counterclockwise"
        )
        XCTAssertFalse(protectedContent.isVersionActionDisabled)
        XCTAssertTrue(deletableContent.canDeleteSelectedVersion)
        XCTAssertEqual(deletableContent.deleteConfirmationTitle, "Delete Version 2?")
        XCTAssertEqual(deletableContent.versionActionTitle, "Delete Version")
        XCTAssertEqual(deletableContent.versionActionSystemImage, "trash")
        XCTAssertFalse(deletableContent.isVersionActionDisabled)
    }

    @MainActor
    func testVersionControlPopupFillsAvailableHorizontalSpace() throws {
        let versionOne = TinkerbleSavedVersion(id: UUID(), ordinal: 1)
        let versionTwo = TinkerbleSavedVersion(id: UUID(), ordinal: 2)
        let host = NSHostingView(
            rootView: TinkerbleVersionControlBarView(
                versions: [versionOne, versionTwo],
                selectedVersionID: .constant(versionOne.id),
                canDeleteSelectedVersion: false,
                canResetSelectedVersion: true,
                createVersion: {},
                resetSelectedVersion: {},
                deleteSelectedVersion: {}
            )
            .frame(width: 608)
        )

        host.frame = NSRect(x: 0, y: 0, width: 608, height: 44)
        host.layoutSubtreeIfNeeded()

        let popUpButton = try XCTUnwrap(host.firstSubview(withIdentifier: "TinkerbleVersionPopupButton") as? NSPopUpButton)

        XCTAssertGreaterThanOrEqual(popUpButton.frame.width, 420)
        XCTAssertEqual(popUpButton.title, "Version 1")
        XCTAssertNil(popUpButton.image)
    }

    @MainActor
    func testScreenSegmentedControlFillsAvailableHorizontalSpace() throws {
        let host = NSHostingView(
            rootView: TinkerbleScreenSegmentedControlView(
                screens: ["Basic", "Fan Deck"],
                selectedScreen: .constant("Fan Deck")
            )
            .frame(width: 608)
        )

        host.frame = NSRect(x: 0, y: 0, width: 608, height: 44)
        host.layoutSubtreeIfNeeded()

        let segmentedControl = try XCTUnwrap(
            host.firstSubview(withIdentifier: "TinkerbleScreenSegmentedControl") as? NSSegmentedControl
        )

        XCTAssertEqual(segmentedControl.segmentCount, 2)
        XCTAssertEqual(segmentedControl.selectedSegment, 1)
    }

    func testDatePickerConfiguresAppKitElementsAndCalendarOverlay() {
        #if os(macOS)
        XCTAssertEqual(
            TinkerbleDatePickerView.appKitConfiguration(for: .date),
            TinkerbleDatePickerAppKitConfiguration(
                elements: .yearMonthDay,
                presentsCalendarOverlay: true,
                appearance: NSAppearance(named: .darkAqua)
            )
        )
        XCTAssertEqual(
            TinkerbleDatePickerView.appKitConfiguration(for: .dateAndTime),
            TinkerbleDatePickerAppKitConfiguration(
                elements: [.yearMonthDay, .hourMinute],
                presentsCalendarOverlay: true,
                appearance: NSAppearance(named: .darkAqua)
            )
        )
        XCTAssertEqual(
            TinkerbleDatePickerView.appKitConfiguration(for: .time),
            TinkerbleDatePickerAppKitConfiguration(
                elements: .hourMinute,
                presentsCalendarOverlay: false,
                appearance: NSAppearance(named: .darkAqua)
            )
        )
        #endif
    }

    func testDegreeFieldParserAcceptsValuesWithAndWithoutDegreeSymbols() {
        let configuration = TinkerbleNumericControl(decimalPlaces: 0, angleUnit: .degrees)

        XCTAssertEqual(TinkerbleNumberFieldView.number(from: "45", configuration: configuration), 45)
        XCTAssertEqual(TinkerbleNumberFieldView.number(from: "45º", configuration: configuration), 45)
        XCTAssertEqual(TinkerbleNumberFieldView.number(from: "45°", configuration: configuration), 45)
    }

    func testRadianFieldParserDoesNotStripDegreeSymbols() {
        let configuration = TinkerbleNumericControl(decimalPlaces: 2, angleUnit: .radians)

        XCTAssertEqual(TinkerbleNumberFieldView.number(from: "1.57", configuration: configuration), 1.57)
        XCTAssertNil(TinkerbleNumberFieldView.number(from: "1.57º", configuration: configuration))
    }
}

private extension NSView {
    func firstSubview(withIdentifier identifier: String) -> NSView? {
        if self.identifier?.rawValue == identifier {
            return self
        }

        for subview in subviews {
            if let match = subview.firstSubview(withIdentifier: identifier) {
                return match
            }
        }

        return nil
    }
}

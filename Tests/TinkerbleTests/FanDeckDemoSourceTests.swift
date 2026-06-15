import Foundation
import XCTest

final class FanDeckDemoSourceTests: XCTestCase {
    func testFanDeckDemoRegistersExpectedTinkerbleControls() throws {
        let source = try fanDeckSource
        let expectedControls = [
            #"@TinkerbleState(category: "Deck", name: "Card Count", screen: "Fan Deck", control: TinkerbleControl<Int>.slider(2...9))"#,
            #"@TinkerbleState(category: "Deck", name: "Card Size", screen: "Fan Deck", control: .slider(120.0...320.0))"#,
            #"@TinkerbleState(category: "Deck", name: "Card Spacing", screen: "Fan Deck", control: .slider(0.0...120.0))"#,
            #"@TinkerbleState(category: "Curve", name: "Spread Angle", screen: "Fan Deck", control: .slider(0.0...90.0))"#,
            #"@TinkerbleState(category: "Curve", name: "Arc Lift", screen: "Fan Deck", control: .slider(0.0...140.0))"#,
            #"@TinkerbleState(category: "Curve", name: "Edge Scale", screen: "Fan Deck", control: .slider(0.5...1.0))"#,
            #"@TinkerbleState(category: "Appearance", name: "Corner Radius", screen: "Fan Deck", control: .slider(0.0...60.0))"#,
            #"@TinkerbleState(category: "Appearance", name: "Shadow Radius", screen: "Fan Deck", control: .slider(0.0...30.0))"#,
            #"@TinkerbleState(category: "Appearance", name: "Shadow Opacity", screen: "Fan Deck", control: .slider(0.0...1.0))"#,
            #"@TinkerbleState(category: "Animation", name: "Duration", screen: "Fan Deck", control: .slider(0.1...2.0, step: 0.05, decimalPlaces: 2))"#,
            #"@TinkerbleState(category: "Animation", name: "Bounciness", screen: "Fan Deck", control: .slider(0.0...1.0))"#,
            #"@TinkerbleState(category: "Colors", name: "Start Color", screen: "Fan Deck")"#,
            #"@TinkerbleState(category: "Colors", name: "End Color", screen: "Fan Deck")"#
        ]

        for expectedControl in expectedControls {
            XCTAssertTrue(source.contains(expectedControl), "Missing control: \(expectedControl)")
        }

        XCTAssertEqual(source.components(separatedBy: "@TinkerbleState").count - 1, expectedControls.count)
    }

    func testFanDeckDemoUsesRequestedLayoutMathAndAnimationTriggers() throws {
        let source = try fanDeckSource
        let requiredSnippets = [
            "let resolvedSpreadAngle = isExpanded ? spreadAngle : 0",
            "let resolvedSpacing = isExpanded ? cardSpacing : 0",
            "let resolvedArcLift = isExpanded ? arcLift : 0",
            "let fitScale = FanDeckLayout.fitScale(for: bounds, in: deckSize)",
            "normalized * spreadAngle / 2",
            "relative * spacing",
            "arcLift * (normalized * normalized - 1)",
            "1 - (1 - edgeScale) * abs(normalized)",
            "private static let widthRatio = 0.6",
            "static func boundingRect(",
            "static func fitScale(for bounds: CGRect, in containerSize: CGSize) -> Double",
            ".onGeometryChange(for: CGSize.self)",
            "Color.lerp(from: startColor, to: endColor, progress: Double(card.index) / divisor)",
            ".spring(duration: duration, bounce: bounciness)",
            #".tinkerbleAction("Fan Out / Collapse", screen: "Fan Deck", category: "Animation")"#,
            "Task.sleep(for: .seconds(0.15))",
            ".onTapGesture",
            ".onDisappear",
            ".frame(height: 460)",
            "#Preview(\"Fan-Out Deck\")"
        ]

        for snippet in requiredSnippets {
            XCTAssertTrue(source.contains(snippet), "Missing snippet: \(snippet)")
        }
    }

    func testContentViewUsesTopLevelTabsForVisibleDemos() throws {
        let source = try contentViewSource

        XCTAssertTrue(source.contains("TabView {"))
        XCTAssertTrue(source.contains(#"Tab("Basic", systemImage: "slider.horizontal.3")"#))
        XCTAssertTrue(source.contains(#"Tab("Fan Deck", systemImage:"#))
        XCTAssertTrue(source.contains("BasicDemoView()"))
        XCTAssertTrue(source.contains("FanDeckDemoView()"))
        XCTAssertFalse(source.contains("LifetimeDemoView()"))
        XCTAssertFalse(source.contains(#"Tab("Lifecycle""#))
        XCTAssertFalse(source.contains("NavigationLink"))
    }

    func testDemoTinkerbleStatesDeclareScreens() throws {
        XCTAssertEqual(try contentViewSource.components(separatedBy: #"screen: "Basic""#).count - 1, 12)
        XCTAssertEqual(try fanDeckSource.components(separatedBy: #"screen: "Fan Deck""#).count - 1, 14)
    }

    func testDemoIncludesMacroActionSurface() throws {
        let source = try contentViewSource

        XCTAssertTrue(source.contains("@TinkerbleActions"))
        XCTAssertTrue(source.contains("activateTinkerbleActions()"))
        XCTAssertTrue(source.contains(#"@TinkerbleAction(name: "Increment Action Count", screen: "Basic", category: "Observable")"#))
    }

    private var fanDeckSource: String {
        get throws {
            try String(contentsOf: projectRoot.appending(path: "Tinkerble Demo/Tinkerble Demo/FanDeckDemoView.swift"), encoding: .utf8)
        }
    }

    private var contentViewSource: String {
        get throws {
            try String(contentsOf: projectRoot.appending(path: "Tinkerble Demo/Tinkerble Demo/ContentView.swift"), encoding: .utf8)
        }
    }

    private var projectRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}

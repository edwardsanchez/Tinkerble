import Observation
import SwiftUI
import XCTest
@testable import Tinkerble

@MainActor
final class TinkerbleStateSourceProvenanceTests: XCTestCase {
#if DEBUG
    func testStateMacroRegistersSourceAnchorDefaultAndConcreteType() throws {
        let transport = SourceProvenanceRecordingTransport()
        Tinkerble.shared.resetForTesting(transport: transport)
        addTeardownBlock { @MainActor in
            Tinkerble.shared.resetForTesting()
        }

        var fixture = SourceProvenanceStateFixture()
        fixture.setThroughBinding(41)

        let tweak = try XCTUnwrap(Tinkerble.shared.registeredTweaks.first)
        let anchor = try XCTUnwrap(tweak.sourceAnchors.first)
        XCTAssertEqual(tweak.value, .number(41))
        XCTAssertEqual(tweak.codeDefaultValue, .number(27))
        XCTAssertEqual(tweak.sourceValueType, .int)
        XCTAssertEqual(anchor.propertyName, "count")
        XCTAssertEqual(anchor.initializerExpression, "27")
        XCTAssertEqual(anchor.enclosingTypePath, ["SourceProvenanceStateFixture"])
        XCTAssertTrue(anchor.filePath.hasSuffix("TinkerbleStateSourceProvenanceTests.swift"))
        XCTAssertGreaterThan(anchor.line, 0)
        XCTAssertGreaterThan(anchor.column, 0)
    }

    func testStateMacroSupportsDeferredInitialization() {
        let transport = SourceProvenanceRecordingTransport()
        Tinkerble.shared.resetForTesting(transport: transport)
        addTeardownBlock { @MainActor in
            Tinkerble.shared.resetForTesting()
        }

        var fixture = DeferredSourceProvenanceStateFixture(count: 12)
        fixture.increment()

        XCTAssertEqual(fixture.count, 13)
        XCTAssertEqual(fixture.boundCount.wrappedValue, 13)
        XCTAssertEqual(Tinkerble.shared.registeredTweaks.first?.sourceAnchors.first?.initializerExpression, "")
    }

    func testStateMacroSupportsReferenceTypeMembers() {
        let transport = SourceProvenanceRecordingTransport()
        Tinkerble.shared.resetForTesting(transport: transport)
        addTeardownBlock { @MainActor in
            Tinkerble.shared.resetForTesting()
        }

        let fixture = SourceProvenanceClassFixture()
        fixture.count = 9

        XCTAssertEqual(fixture.count, 9)
        XCTAssertEqual(Tinkerble.shared.registeredTweaks.first?.value, .number(9))
    }

    func testStateMacroPreservesPropertyObserverBehavior() async {
        let transport = SourceProvenanceRecordingTransport()
        Tinkerble.shared.resetForTesting(transport: transport)
        addTeardownBlock { @MainActor in
            Tinkerble.shared.resetForTesting()
        }
        SourceProvenanceObserverRecorder.reset()

        var fixture = SourceProvenanceObserverFixture()
        XCTAssertTrue(SourceProvenanceObserverRecorder.events.isEmpty)
        XCTAssertEqual(
            Tinkerble.shared.registeredTweaks.first { $0.name == "Observed Count" }?
                .sourceAnchors.first?.initializerExpression,
            "4"
        )

        fixture.setCount(6)
        XCTAssertEqual(
            SourceProvenanceObserverRecorder.events,
            [
                .willSet(property: "explicit", oldValue: 4, newValue: 6),
                .didSet(property: "explicit", oldValue: 4, newValue: 6)
            ]
        )

        SourceProvenanceObserverRecorder.reset()
        fixture.setImplicitCount(7)
        XCTAssertEqual(
            SourceProvenanceObserverRecorder.events,
            [
                .willSet(property: "implicit", oldValue: 5, newValue: 7),
                .didSet(property: "implicit", oldValue: 5, newValue: 7)
            ]
        )

        fixture.setMutatingObservedCount(11)
        XCTAssertEqual(fixture.observerMutationCount, 1)

        SourceProvenanceObserverRecorder.reset()
        fixture.setCountThroughBinding(8)
        transport.receive(.update(id: "Basic/Layout/Observed Count", value: .number(9)))
        await Task.yield()

        XCTAssertEqual(fixture.count, 9)
        XCTAssertTrue(SourceProvenanceObserverRecorder.events.isEmpty)
    }

    func testStateMacroQualifiesGeneratedRuntimeNames() {
        let transport = SourceProvenanceRecordingTransport()
        Tinkerble.shared.resetForTesting(transport: transport)
        addTeardownBlock { @MainActor in
            Tinkerble.shared.resetForTesting()
        }

        let fixture = StateMacroShadowingNamespace.Fixture()

        XCTAssertEqual(fixture.count, 4)
        XCTAssertEqual(Tinkerble.shared.registeredTweaks.first?.codeDefaultValue, .number(4))
    }

    func testStateMacroSupportsAutomaticControlInference() {
        let transport = SourceProvenanceRecordingTransport()
        Tinkerble.shared.resetForTesting(transport: transport)
        addTeardownBlock { @MainActor in
            Tinkerble.shared.resetForTesting()
        }

        let fixture = AutomaticControlSourceProvenanceStateFixture()

        XCTAssertEqual(fixture.count, 4)
        XCTAssertEqual(Tinkerble.shared.registeredTweaks.first?.control, TinkerbleControl<Int>.plain.descriptor)
    }

    func testStateMacroForwardsAnAttributeArgumentListWithATrailingComma() {
        let transport = SourceProvenanceRecordingTransport()
        Tinkerble.shared.resetForTesting(transport: transport)
        addTeardownBlock { @MainActor in
            Tinkerble.shared.resetForTesting()
        }

        let fixture = TrailingCommaSourceProvenanceStateFixture()

        XCTAssertEqual(fixture.count, 4)
        XCTAssertEqual(Tinkerble.shared.registeredTweaks.first?.codeDefaultValue, .number(4))
    }

    func testStateMacroPreservesShorthandControlInference() {
        let transport = SourceProvenanceRecordingTransport()
        Tinkerble.shared.resetForTesting(transport: transport)
        addTeardownBlock { @MainActor in
            Tinkerble.shared.resetForTesting()
        }

        let fixture = ShorthandControlSourceProvenanceStateFixture()
        let tweaksByName = Dictionary(
            uniqueKeysWithValues: Tinkerble.shared.registeredTweaks.map { ($0.name, $0) }
        )

        XCTAssertEqual(fixture.count, 4)
        XCTAssertEqual(fixture.opacity, 0.5)
        XCTAssertEqual(fixture.floatOpacity, 0.25)
        XCTAssertEqual(fixture.cgFloatOpacity, 0.5)
        XCTAssertEqual(fixture.inferredCGFloatOpacity, 0.75)
        XCTAssertEqual(fixture.title, "Demo")
        XCTAssertEqual(fixture.angle, .degrees(45))
        XCTAssertEqual(fixture.date, Date(timeIntervalSinceReferenceDate: 123))
        XCTAssertEqual(fixture.explicitCount, 3)
        XCTAssertEqual(tweaksByName["Plain Count"]?.control, TinkerbleControl<Int>.plain.descriptor)
        XCTAssertEqual(
            tweaksByName["Slider Opacity"]?.control,
            TinkerbleControl<Double>.slider(0...1).descriptor
        )
        XCTAssertEqual(tweaksByName["Field Title"]?.control, TinkerbleControl<String>.field.descriptor)
        XCTAssertEqual(tweaksByName["Plain Angle"]?.control, TinkerbleControl<Angle>.plain.descriptor)
        XCTAssertEqual(
            tweaksByName["Slider Float"]?.control,
            TinkerbleControl<Float>.slider(0...1).descriptor
        )
        XCTAssertEqual(
            tweaksByName["Slider CGFloat"]?.control,
            TinkerbleControl<CGFloat>.slider(0...1, step: 0.1, decimalPlaces: 2).descriptor
        )
        XCTAssertEqual(
            tweaksByName["Inferred CGFloat"]?.control,
            TinkerbleControl<CGFloat>.slider(0...1).descriptor
        )
        XCTAssertEqual(tweaksByName["Date"]?.control, TinkerbleControl<Date>.dateAndTime.descriptor)
        XCTAssertEqual(tweaksByName["Explicit Count"]?.control, TinkerbleControl<Int>.plain.descriptor)
    }

    func testStateMacroPreservesSynthesizedMemberwiseInitialization() {
        let transport = SourceProvenanceRecordingTransport()
        Tinkerble.shared.resetForTesting(transport: transport)
        addTeardownBlock { @MainActor in
            Tinkerble.shared.resetForTesting()
        }

        let fixture = MemberwiseSourceProvenanceStateFixture(count: 8)

        XCTAssertEqual(fixture.count, 8)
        XCTAssertEqual(Tinkerble.shared.registeredTweaks.first?.codeDefaultValue, .number(8))
        XCTAssertEqual(Tinkerble.shared.registeredTweaks.first?.sourceAnchors.first?.initializerExpression, "4")
    }

    func testMemberwiseOverrideDoesNotEvaluateDeclarationDefault() {
        let transport = SourceProvenanceRecordingTransport()
        Tinkerble.shared.resetForTesting(transport: transport)
        addTeardownBlock { @MainActor in
            Tinkerble.shared.resetForTesting()
        }
        SourceProvenanceSideEffectCounter.reset()

        let fixture = MemberwiseSideEffectStateFixture(value: 8)

        XCTAssertEqual(fixture.value, 8)
        XCTAssertEqual(SourceProvenanceSideEffectCounter.count, 0)
        XCTAssertEqual(Tinkerble.shared.registeredTweaks.first?.codeDefaultValue, .number(8))
    }

    func testExplicitBackingAssignmentRetainsMacroSourceAnchor() throws {
        let transport = SourceProvenanceRecordingTransport()
        Tinkerble.shared.resetForTesting(transport: transport)
        addTeardownBlock { @MainActor in
            Tinkerble.shared.resetForTesting()
        }

        let fixture = ExplicitBackingSourceProvenanceStateFixture(count: 8)

        XCTAssertEqual(fixture.count, 8)
        let tweak = try XCTUnwrap(Tinkerble.shared.registeredTweaks.first)
        XCTAssertEqual(tweak.codeDefaultValue, .number(4))
        XCTAssertEqual(tweak.sourceAnchors.first?.propertyName, "count")
        XCTAssertEqual(tweak.sourceAnchors.first?.initializerExpression, "4")
    }

    func testStateMacroPreservesExplicitNumericTypesAndEvaluatesInitializersOnce() {
        let transport = SourceProvenanceRecordingTransport()
        Tinkerble.shared.resetForTesting(transport: transport)
        addTeardownBlock { @MainActor in
            Tinkerble.shared.resetForTesting()
        }
        SourceProvenanceSideEffectCounter.reset()

        let fixture = ExplicitNumericSourceProvenanceStateFixture()

        XCTAssertEqual(fixture.floatValue, 1.25)
        XCTAssertEqual(fixture.cgFloatValue, 18)
        XCTAssertEqual(fixture.sideEffectValue, 1)
        XCTAssertEqual(SourceProvenanceSideEffectCounter.count, 1)

        let tweaksByName = Dictionary(
            uniqueKeysWithValues: Tinkerble.shared.registeredTweaks.map { ($0.name, $0) }
        )
        XCTAssertEqual(tweaksByName["Float"]?.codeDefaultValue, .number(1.25))
        XCTAssertEqual(tweaksByName["Float"]?.sourceValueType, .float)
        XCTAssertEqual(tweaksByName["CGFloat"]?.codeDefaultValue, .number(18))
        XCTAssertEqual(tweaksByName["CGFloat"]?.sourceValueType, .cgFloat)
    }

    func testObservableMacroRegistersSourceAnchor() {
        let transport = SourceProvenanceRecordingTransport()
        Tinkerble.shared.resetForTesting(transport: transport)
        addTeardownBlock { @MainActor in
            Tinkerble.shared.resetForTesting()
        }

        let fixture = SourceProvenanceObservableFixture()
        XCTAssertEqual(fixture.count, 3)

        let anchor = Tinkerble.shared.registeredTweaks.first?.sourceAnchors.first
        XCTAssertEqual(anchor?.propertyName, "count")
        XCTAssertEqual(anchor?.initializerExpression, "3")
        XCTAssertEqual(anchor?.enclosingTypePath, ["SourceProvenanceObservableFixture"])
        XCTAssertTrue(anchor?.filePath.hasSuffix("TinkerbleStateSourceProvenanceTests.swift") == true)
    }

    func testDuplicateRegistrationAnchorsFollowInstanceLifetime() {
        let transport = SourceProvenanceRecordingTransport()
        Tinkerble.shared.resetForTesting(transport: transport)
        addTeardownBlock { @MainActor in
            Tinkerble.shared.resetForTesting()
        }
        let firstAnchor = sourceAnchor(propertyName: "first")
        let secondAnchor = sourceAnchor(propertyName: "second")

        let firstToken = Tinkerble.shared.register(
            id: "Basic/Layout/Count",
            screen: "Basic",
            category: "Layout",
            name: "Count",
            value: 2,
            control: .automatic,
            sourceAnchor: firstAnchor,
            applyRemoteValue: { _ in }
        )
        let secondToken = Tinkerble.shared.register(
            id: "Basic/Layout/Count",
            screen: "Basic",
            category: "Layout",
            name: "Count",
            value: 2,
            control: .automatic,
            sourceAnchor: secondAnchor,
            applyRemoteValue: { _ in }
        )

        XCTAssertEqual(Tinkerble.shared.registeredTweaks.first?.sourceAnchors, [firstAnchor, secondAnchor])
        XCTAssertEqual(transport.registeredTweaks.last?.sourceAnchors, [firstAnchor, secondAnchor])

        Tinkerble.shared.unregister(secondToken)

        XCTAssertEqual(Tinkerble.shared.registeredTweaks.first?.sourceAnchors, [firstAnchor])
        XCTAssertEqual(transport.registeredTweaks.last?.sourceAnchors, [firstAnchor])

        Tinkerble.shared.unregister(firstToken)
        XCTAssertTrue(Tinkerble.shared.registeredTweaks.isEmpty)
    }

    func testDuplicateRegistrationAnchorsWithTheSameStableIDAreDeduplicated() {
        let transport = SourceProvenanceRecordingTransport()
        Tinkerble.shared.resetForTesting(transport: transport)
        addTeardownBlock { @MainActor in
            Tinkerble.shared.resetForTesting()
        }
        let firstAnchor = sourceAnchor(propertyName: "value")
        var movedAnchor = firstAnchor
        movedAnchor.line = 2

        let firstToken = Tinkerble.shared.register(
            id: "Basic/Layout/Count",
            screen: "Basic",
            category: "Layout",
            name: "Count",
            value: 2,
            control: .automatic,
            sourceAnchor: firstAnchor,
            applyRemoteValue: { _ in }
        )
        let movedToken = Tinkerble.shared.register(
            id: "Basic/Layout/Count",
            screen: "Basic",
            category: "Layout",
            name: "Count",
            value: 2,
            control: .automatic,
            sourceAnchor: movedAnchor,
            applyRemoteValue: { _ in }
        )

        XCTAssertEqual(Tinkerble.shared.registeredTweaks.first?.sourceAnchors, [firstAnchor])
        Tinkerble.shared.unregister(firstToken)
        XCTAssertEqual(Tinkerble.shared.registeredTweaks.first?.sourceAnchors, [movedAnchor])

        Tinkerble.shared.unregister(movedToken)
        XCTAssertTrue(Tinkerble.shared.registeredTweaks.isEmpty)
    }

    private func sourceAnchor(propertyName: String) -> TinkerbleSourceAnchor {
        TinkerbleSourceAnchor(
            filePath: "/tmp/Source.swift",
            line: 1,
            column: 1,
            enclosingTypePath: ["Fixture"],
            propertyName: propertyName,
            initializerExpression: "2"
        )
    }
#endif
}

@MainActor
private struct SourceProvenanceStateFixture {
    @TinkerbleState("Count", screen: "Basic", category: "Layout")
    private var count = 27

    mutating func setThroughBinding(_ value: Int) {
        $count.wrappedValue = value
    }
}

@MainActor
private struct DeferredSourceProvenanceStateFixture {
    @TinkerbleState("Deferred Count", screen: "Basic", category: "Layout")
    var count: Int

    init(count: Int) {
        self.count = count
    }

    var boundCount: Binding<Int> {
        $count
    }

    mutating func increment() {
        count += 1
    }
}

@MainActor
private final class SourceProvenanceClassFixture {
    @TinkerbleState("Class Count", screen: "Basic", category: "Layout")
    var count = 4
}

@MainActor
private struct SourceProvenanceObserverFixture {
    var observerMutationCount = 0

    @TinkerbleState("Observed Count", screen: "Basic", category: "Layout")
    var count = 4 {
        willSet(incomingValue) {
            SourceProvenanceObserverRecorder.events.append(
                .willSet(property: "explicit", oldValue: count, newValue: incomingValue)
            )
        }
        didSet(previousValue) {
            SourceProvenanceObserverRecorder.events.append(
                .didSet(property: "explicit", oldValue: previousValue, newValue: count)
            )
        }
    }

    @TinkerbleState("Implicit Observed Count", screen: "Basic", category: "Layout")
    var implicitCount = 5 {
        willSet {
            SourceProvenanceObserverRecorder.events.append(
                .willSet(property: "implicit", oldValue: implicitCount, newValue: newValue)
            )
        }
        didSet {
            SourceProvenanceObserverRecorder.events.append(
                .didSet(property: "implicit", oldValue: oldValue, newValue: implicitCount)
            )
        }
    }

    @TinkerbleState("Mutating Observed Count", screen: "Basic", category: "Layout")
    var mutatingObservedCount = 10 {
        mutating didSet {
            observerMutationCount += 1
        }
    }

    mutating func setCount(_ value: Int) {
        count = value
    }

    mutating func setImplicitCount(_ value: Int) {
        implicitCount = value
    }

    mutating func setMutatingObservedCount(_ value: Int) {
        mutatingObservedCount = value
    }

    mutating func setCountThroughBinding(_ value: Int) {
        $count.wrappedValue = value
    }
}

private enum SourceProvenanceObserverEvent: Equatable {
    case willSet(property: String, oldValue: Int, newValue: Int)
    case didSet(property: String, oldValue: Int, newValue: Int)
}

@MainActor
private enum SourceProvenanceObserverRecorder {
    static var events: [SourceProvenanceObserverEvent] = []

    static func reset() {
        events = []
    }
}

private enum StateMacroShadowingNamespace {
    private struct TinkerbleState {}

    @MainActor
    struct Fixture {
        @Tinkerble.TinkerbleState("Qualified Count", screen: "Basic", category: "Layout")
        var count = 4
    }
}

@MainActor
private struct AutomaticControlSourceProvenanceStateFixture {
    @TinkerbleState("Automatic Count", screen: "Basic", category: "Layout", control: .automatic)
    var count = 4
}

@MainActor
private struct TrailingCommaSourceProvenanceStateFixture {
    @TinkerbleState(
        "Trailing Comma Count",
        screen: "Basic",
        category: "Layout",
    )
    var count = 4
}

@MainActor
private struct ShorthandControlSourceProvenanceStateFixture {
    @TinkerbleState("Plain Count", screen: "Basic", category: "Controls", control: .plain)
    var count = 4

    @TinkerbleState("Slider Opacity", screen: "Basic", category: "Controls", control: .slider(0...1))
    var opacity = 0.5

    @TinkerbleState("Field Title", screen: "Basic", category: "Controls", control: .field)
    var title = "Demo"

    @TinkerbleState("Slider Float", screen: "Basic", category: "Controls", control: .slider(0...1))
    var floatOpacity: Float = 0.25

    @TinkerbleState(
        "Slider CGFloat",
        screen: "Basic",
        category: "Controls",
        control: .slider(0.0...1.0, step: 0.1, decimalPlaces: 2)
    )
    var cgFloatOpacity: CGFloat = 0.5

    @TinkerbleState("Inferred CGFloat", screen: "Basic", category: "Controls", control: .slider(0.0...1.0))
    var inferredCGFloatOpacity = CGFloat(0.75)

    @TinkerbleState("Plain Angle", screen: "Basic", category: "Controls", control: .plain)
    var angle = Angle.degrees(45)

    @TinkerbleState("Date", screen: "Basic", category: "Controls", control: .datePicker(.dateAndTime))
    var date = Date(timeIntervalSinceReferenceDate: 123)

    @TinkerbleState(
        "Explicit Count",
        screen: "Basic",
        category: "Controls",
        control: TinkerbleControl<Int>.plain
    )
    var explicitCount = 3
}

@MainActor
private struct MemberwiseSourceProvenanceStateFixture {
    @TinkerbleState("Memberwise Count", screen: "Basic", category: "Layout")
    var count = 4
}

@MainActor
private struct MemberwiseSideEffectStateFixture {
    @TinkerbleState("Memberwise Side Effect", screen: "Basic", category: "Layout")
    var value = SourceProvenanceSideEffectCounter.next
}

@MainActor
private struct ExplicitBackingSourceProvenanceStateFixture {
    @TinkerbleState("Explicit Backing Count", screen: "Basic", category: "Layout")
    var count = 4

    init(count: Int) {
        _count = TinkerbleState(
            wrappedValue: count,
            "Explicit Backing Count",
            screen: "Basic",
            category: "Layout"
        )
    }
}

@MainActor
private struct ExplicitNumericSourceProvenanceStateFixture {
    @TinkerbleState("Float", screen: "Basic", category: "Source Types")
    var floatValue: Float = 1.25

    @TinkerbleState("CGFloat", screen: "Basic", category: "Source Types")
    var cgFloatValue: CGFloat = 18

    @TinkerbleState("Side Effect", screen: "Basic", category: "Source Types")
    var sideEffectValue = SourceProvenanceSideEffectCounter.next
}

@MainActor
private enum SourceProvenanceSideEffectCounter {
    private(set) static var count = 0

    static var next: Int {
        count += 1
        return count
    }

    static func reset() {
        count = 0
    }
}

@TinkerbleObservable
@Observable
@MainActor
private final class SourceProvenanceObservableFixture {
    @TinkerbleObservableState("Observable Count", screen: "Basic", category: "Observable")
    var count = 3
}

private final class SourceProvenanceRecordingTransport: TinkerbleClientTransport {
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

    func receive(_ message: TinkerbleWireMessage) {
        onMessage?(message)
    }

    func disconnect() {}
}

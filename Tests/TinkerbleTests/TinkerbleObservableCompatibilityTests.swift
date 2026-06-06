import XCTest
@testable import Tinkerble

#if canImport(Observation)
import Observation

@Observable
private final class ObservableDemoModel {
    @ObservationIgnored
    @TinkerbleState(name: "Count", control: TinkerbleControl<Int>.plain)
    var count = 1
}
#endif

final class TinkerbleObservableCompatibilityTests: XCTestCase {
    @MainActor
    func testObservableCompatibilityFixtureCompiles() {
        #if canImport(Observation)
        let model = ObservableDemoModel()
        let count = model.count
        XCTAssertEqual(count, 1)
        #else
        XCTAssertTrue(true)
        #endif
    }
}

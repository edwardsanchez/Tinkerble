import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest
@testable import TinkerbleMacros

final class TinkerbleObservableStateMacroExpansionTests: XCTestCase {
    func testObservableTypeMacroExpansion() {
        assertMacroExpansion(
            """
            @TinkerbleObservable
            @MainActor
            final class DemoModel {
            }
            """,
            expandedSource:
            """
            @MainActor
            final class DemoModel {

                @ObservationIgnored
                private let _tinkerbleObservationRegistrar = Observation.ObservationRegistrar()

                internal nonisolated func access<Member>(keyPath: KeyPath<DemoModel, Member>) {
                    _tinkerbleObservationRegistrar.access(self, keyPath: keyPath)
                }

                internal nonisolated func withMutation<Member, MutationResult>(
                    keyPath: KeyPath<DemoModel, Member>,
                    _ mutation: () throws -> MutationResult
                ) rethrows -> MutationResult {
                    try _tinkerbleObservationRegistrar.withMutation(of: self, keyPath: keyPath, mutation)
                }
            }

            extension DemoModel: Observation.Observable {
            }
            """,
            macros: [
                "TinkerbleObservable": TinkerbleObservableMacro.self,
            ]
        )
    }

    func testObservableStateMacroExpansion() {
        assertMacroExpansion(
            """
            @TinkerbleObservable
            @MainActor
            final class DemoModel {
                @TinkerbleObservableState(name: "Count", control: .stepper())
                var count = 1
            }
            """,
            expandedSource:
            """
            @TinkerbleObservable
            @MainActor
            final class DemoModel {
                var count {
                    get {
                        access(keyPath: \\.count)
                        _countTinkerbleRegistration.activate(
                        owner: self,
                        initialValue: _count, name: "Count", control: .stepper(),
                        applyRemoteValue: { owner, newValue in
                            owner.count = newValue
                        }
                        )
                        return _count
                    }
                    set {
                        _countTinkerbleRegistration.activate(
                        owner: self,
                        initialValue: _count, name: "Count", control: .stepper(),
                        applyRemoteValue: { owner, newValue in
                            owner.count = newValue
                        }
                        )
                        withMutation(keyPath: \\.count) {
                            _count = newValue
                        }
                        _countTinkerbleRegistration.updateLocalValue(newValue)
                    }
                }

                @ObservationIgnored
                private var _count = 1

                @ObservationIgnored
                private let _countTinkerbleRegistration = TinkerbleObservableStateRegistration()
            }
            """,
            macros: [
                "TinkerbleObservableState": TinkerbleObservableStateMacro.self,
            ]
        )
    }
}

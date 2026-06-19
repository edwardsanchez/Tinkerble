import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import TinkerbleMacros
import XCTest

final class TinkerbleMacroExpansionTests: XCTestCase {
    func testObservableMacroGeneratesRegistrationStorageAndActivation() {
        assertMacroExpansion(
            """
            @TinkerbleObservable
            @Observable
            @MainActor
            final class Model {
                @TinkerbleObservableState("Badge Count", screen: "Basic", category: "Observable", control: TinkerbleControl<Int>.plain)
                var badgeCount = 2
            }
            """,
            expandedSource:
            """
            @Observable
            @MainActor
            final class Model {
                var badgeCount = 2

                @ObservationIgnored
                private let _tinkerbleObservableState_badgeCountRegistration = TinkerbleObservableStateRegistration()

                init() {
                    _tinkerbleActivateObservableStates()
                }

                private func _tinkerbleActivateObservableStates() {
                    _tinkerbleObservableState_badgeCountRegistration.activate(
                        owner: self,
                        initialValue: badgeCount,
                        name: "Badge Count",
                        screen: "Basic",
                        category: "Observable",
                        control: TinkerbleControl<Int>.plain,
                        readValue: { owner in
                            owner.badgeCount
                        },
                        applyRemoteValue: { owner, value in
                            owner.badgeCount = value
                        }
                    )
                }
            }
            """,
            macros: testMacros
        )
    }

    func testObservableMacroSupportsCanonicalUnlabeledNameOverloads() {
        assertMacroExpansion(
            """
            @TinkerbleObservable
            @Observable
            @MainActor
            final class Model {
                @TinkerbleObservableState("Title")
                var title = "Demo"

                @TinkerbleObservableState("Opacity", screen: "Basic", category: "Layout", control: .slider(0.0...1.0))
                var opacity = 0.5
            }
            """,
            expandedSource:
            """
            @Observable
            @MainActor
            final class Model {
                var title = "Demo"
                var opacity = 0.5

                @ObservationIgnored
                private let _tinkerbleObservableState_titleRegistration = TinkerbleObservableStateRegistration()

                @ObservationIgnored
                private let _tinkerbleObservableState_opacityRegistration = TinkerbleObservableStateRegistration()

                init() {
                    _tinkerbleActivateObservableStates()
                }

                private func _tinkerbleActivateObservableStates() {
                    _tinkerbleObservableState_titleRegistration.activate(
                        owner: self,
                        initialValue: title,
                        name: "Title",
                        screen: nil,
                        category: nil,
                        control: .automatic,
                        readValue: { owner in
                            owner.title
                        },
                        applyRemoteValue: { owner, value in
                            owner.title = value
                        }
                    )

                    _tinkerbleObservableState_opacityRegistration.activate(
                        owner: self,
                        initialValue: opacity,
                        name: "Opacity",
                        screen: "Basic",
                        category: "Layout",
                        control: .slider(0.0 ... 1.0),
                        readValue: { owner in
                            owner.opacity
                        },
                        applyRemoteValue: { owner, value in
                            owner.opacity = value
                        }
                    )
                }
            }
            """,
            macros: testMacros
        )
    }

    func testObservableMacroKeepsDeprecatedUnlabeledCategoryOverloadMeaning() {
        assertMacroExpansion(
            """
            @TinkerbleObservable
            @Observable
            @MainActor
            final class Model {
                @TinkerbleObservableState("Layout", name: "Opacity", screen: "Basic", control: .slider(0.0...1.0))
                var opacity = 0.5
            }
            """,
            expandedSource:
            """
            @Observable
            @MainActor
            final class Model {
                var opacity = 0.5

                @ObservationIgnored
                private let _tinkerbleObservableState_opacityRegistration = TinkerbleObservableStateRegistration()

                init() {
                    _tinkerbleActivateObservableStates()
                }

                private func _tinkerbleActivateObservableStates() {
                    _tinkerbleObservableState_opacityRegistration.activate(
                        owner: self,
                        initialValue: opacity,
                        name: "Opacity",
                        screen: "Basic",
                        category: "Layout",
                        control: .slider(0.0 ... 1.0),
                        readValue: { owner in
                            owner.opacity
                        },
                        applyRemoteValue: { owner, value in
                            owner.opacity = value
                        }
                    )
                }
            }
            """,
            macros: testMacros
        )
    }

    func testObservableMacroDiagnosesExplicitInitializers() {
        assertMacroExpansion(
            """
            @TinkerbleObservable
            @Observable
            @MainActor
            final class Model {
                @TinkerbleObservableState("Title")
                var title = "Demo"

                init(title: String) {
                    self.title = title
                }
            }
            """,
            expandedSource:
            """
            @Observable
            @MainActor
            final class Model {
                var title = "Demo"

                init(title: String) {
                    self.title = title
                }
            }
            """,
            diagnostics: [
                DiagnosticSpec(
                    message: "@TinkerbleObservable currently supports only default-initialized classes without explicit initializers.",
                    line: 1,
                    column: 1
                )
            ],
            macros: testMacros
        )
    }

    func testObservableMacroDiagnosesStoredPropertiesWithoutDefaults() {
        assertMacroExpansion(
            """
            @TinkerbleObservable
            @Observable
            @MainActor
            final class Model {
                @TinkerbleObservableState("Title")
                var title: String
            }
            """,
            expandedSource:
            """
            @Observable
            @MainActor
            final class Model {
                var title: String
            }
            """,
            diagnostics: [
                DiagnosticSpec(
                    message: "@TinkerbleObservable requires stored properties to have default values.",
                    line: 1,
                    column: 1
                )
            ],
            macros: testMacros
        )
    }

    func testObservableMacroDiagnosesClassesMissingObservable() {
        assertMacroExpansion(
            """
            @TinkerbleObservable
            @MainActor
            final class Model {
                @TinkerbleObservableState("Title")
                var title = "Demo"
            }
            """,
            expandedSource:
            """
            @MainActor
            final class Model {
                var title = "Demo"
            }
            """,
            diagnostics: [
                DiagnosticSpec(
                    message: "@TinkerbleObservable requires the class to also be marked @Observable.",
                    line: 1,
                    column: 1
                )
            ],
            macros: testMacros
        )
    }

    func testTinkerbleActionsMacroGeneratesScreenAwareActionRegistration() {
        assertMacroExpansion(
            """
            @TinkerbleActions
            final class Model {
                @TinkerbleAction("Toggle Fan", screen: "Fan Deck", category: "Animation")
                func toggleFan() {
                }
            }
            """,
            expandedSource:
            """
            final class Model {
                func toggleFan() {
                }

                @ObservationIgnored
                private let _tinkerbleAction_toggleFanRegistration = TinkerbleActionRegistration()

                func activateTinkerbleActions() {
                    _tinkerbleAction_toggleFanRegistration.activate(
                        owner: self,
                        name: "Toggle Fan",
                        screen: "Fan Deck",
                        category: "Animation",
                        perform: { owner in
                            owner.toggleFan()
                        }
                    )
                }
            }
            """,
            macros: testMacros
        )
    }

    func testTinkerbleActionsMacroDefaultsNameAndSupportsUnlabeledName() {
        assertMacroExpansion(
            """
            @TinkerbleActions
            final class Model {
                @TinkerbleAction(category: "Animation")
                func toggleFan() {
                }

                @TinkerbleAction("Reset", screen: "Fan Deck")
                func resetDeck() {
                }
            }
            """,
            expandedSource:
            """
            final class Model {
                func toggleFan() {
                }
                func resetDeck() {
                }

                @ObservationIgnored
                private let _tinkerbleAction_toggleFanRegistration = TinkerbleActionRegistration()

                @ObservationIgnored
                private let _tinkerbleAction_resetDeckRegistration = TinkerbleActionRegistration()

                func activateTinkerbleActions() {
                    _tinkerbleAction_toggleFanRegistration.activate(
                        owner: self,
                        name: "toggleFan",
                        screen: nil,
                        category: "Animation",
                        perform: { owner in
                            owner.toggleFan()
                        }
                    )

                    _tinkerbleAction_resetDeckRegistration.activate(
                        owner: self,
                        name: "Reset",
                        screen: "Fan Deck",
                        category: nil,
                        perform: { owner in
                            owner.resetDeck()
                        }
                    )
                }
            }
            """,
            macros: testMacros
        )
    }

    func testTinkerbleActionDiagnosesMethodsWithParameters() {
        assertMacroExpansion(
            """
            final class Model {
                @TinkerbleAction
                func toggleFan(count: Int) {
                }
            }
            """,
            expandedSource:
            """
            final class Model {
                func toggleFan(count: Int) {
                }
            }
            """,
            diagnostics: [
                DiagnosticSpec(
                    message: "@TinkerbleAction requires a method with no parameters.",
                    line: 3,
                    column: 19
                )
            ],
            macros: testMacros
        )
    }

    func testObservableMacroDiagnosesClassesMissingMainActor() {
        assertMacroExpansion(
            """
            @TinkerbleObservable
            @Observable
            final class Model {
                @TinkerbleObservableState("Title")
                var title = "Demo"
            }
            """,
            expandedSource:
            """
            @Observable
            final class Model {
                var title = "Demo"
            }
            """,
            diagnostics: [
                DiagnosticSpec(
                    message: "@TinkerbleObservable requires the class to also be marked @MainActor.",
                    line: 1,
                    column: 1
                )
            ],
            macros: testMacros
        )
    }

    private let testMacros: [String: Macro.Type] = [
        "TinkerbleAction": TinkerbleActionMacro.self,
        "TinkerbleActions": TinkerbleActionsMacro.self,
        "TinkerbleObservable": TinkerbleObservableMacro.self,
        "TinkerbleObservableState": TinkerbleObservableStateMacro.self
    ]
}

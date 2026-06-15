import Foundation
import SwiftCompilerPlugin
import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxMacros

public struct TinkerbleObservableStateMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        []
    }
}

public struct TinkerbleActionMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let function = declaration.as(FunctionDeclSyntax.self) else {
            context.diagnose(
                Diagnostic(
                    node: Syntax(declaration),
                    message: TinkerbleMacroDiagnostic("@TinkerbleAction can only be applied to methods.")
                )
            )
            return []
        }

        guard function.signature.parameterClause.parameters.isEmpty else {
            context.diagnose(
                Diagnostic(
                    node: Syntax(function.signature.parameterClause),
                    message: TinkerbleMacroDiagnostic("@TinkerbleAction requires a method with no parameters.")
                )
            )
            return []
        }

        return []
    }
}

public struct TinkerbleObservableMacro: MemberMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let classDeclaration = declaration.as(ClassDeclSyntax.self) else {
            context.diagnose(
                Diagnostic(
                    node: Syntax(declaration),
                    message: TinkerbleMacroDiagnostic("@TinkerbleObservable can only be applied to classes.")
                )
            )
            return []
        }

        guard classDeclaration.hasAttribute(named: "Observable") else {
            context.diagnose(
                Diagnostic(
                    node: Syntax(classDeclaration),
                    message: TinkerbleMacroDiagnostic("@TinkerbleObservable requires the class to also be marked @Observable.")
                )
            )
            return []
        }

        guard classDeclaration.hasAttribute(named: "MainActor") else {
            context.diagnose(
                Diagnostic(
                    node: Syntax(classDeclaration),
                    message: TinkerbleMacroDiagnostic("@TinkerbleObservable requires the class to also be marked @MainActor.")
                )
            )
            return []
        }

        let observableProperties = classDeclaration.memberBlock.members.compactMap { member -> ObservableStateProperty? in
            guard let variable = member.decl.as(VariableDeclSyntax.self),
                  let attribute = variable.tinkerbleObservableStateAttribute
            else {
                return nil
            }

            return ObservableStateProperty(variable: variable, attribute: attribute, context: context)
        }

        guard !observableProperties.isEmpty else { return [] }

        if classDeclaration.memberBlock.members.contains(where: { $0.decl.is(InitializerDeclSyntax.self) }) {
            context.diagnose(
                Diagnostic(
                    node: Syntax(classDeclaration),
                    message: TinkerbleMacroDiagnostic(
                        "@TinkerbleObservable currently supports only default-initialized classes without explicit initializers."
                    )
                )
            )
            return []
        }

        if classDeclaration.memberBlock.members.contains(where: \.requiresExplicitInitializer) {
            context.diagnose(
                Diagnostic(
                    node: Syntax(classDeclaration),
                    message: TinkerbleMacroDiagnostic(
                        "@TinkerbleObservable requires stored properties to have default values."
                    )
                )
            )
            return []
        }

        let validProperties = observableProperties.compactMap { property -> ObservableStateProperty? in
            guard property.isValid else {
                property.diagnoseInvalidShape()
                return nil
            }
            return property
        }

        guard !validProperties.isEmpty else { return [] }

        let registrations = validProperties.map(\.registrationDeclaration).joined(separator: "\n\n")
        let activationCalls = validProperties.map(\.activationCall).joined(separator: "\n\n")

        return [
            DeclSyntax(stringLiteral: registrations),
            """
            init() {
                _tinkerbleActivateObservableStates()
            }
            """,
            DeclSyntax(
                stringLiteral: """
                private func _tinkerbleActivateObservableStates() {
                \(activationCalls.indentedByFourSpaces)
                }
                """
            ),
        ]
    }
}

public struct TinkerbleActionsMacro: MemberMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let classDeclaration = declaration.as(ClassDeclSyntax.self) else {
            context.diagnose(
                Diagnostic(
                    node: Syntax(declaration),
                    message: TinkerbleMacroDiagnostic("@TinkerbleActions can only be applied to classes.")
                )
            )
            return []
        }

        let actions = classDeclaration.memberBlock.members.compactMap { member -> ObservableActionMethod? in
            guard let function = member.decl.as(FunctionDeclSyntax.self),
                  let attribute = function.tinkerbleActionAttribute
            else {
                return nil
            }
            guard function.signature.parameterClause.parameters.isEmpty else {
                return nil
            }
            return ObservableActionMethod(function: function, attribute: attribute)
        }

        guard !actions.isEmpty else { return [] }

        let registrations = actions.map(\.registrationDeclaration).joined(separator: "\n\n")
        let activationCalls = actions.map(\.activationCall).joined(separator: "\n\n")

        return [
            DeclSyntax(stringLiteral: registrations),
            DeclSyntax(
                stringLiteral: """
                func activateTinkerbleActions() {
                \(activationCalls.indentedByFourSpaces)
                }
                """
            ),
        ]
    }
}

@main
struct TinkerbleMacrosPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        TinkerbleActionsMacro.self,
        TinkerbleActionMacro.self,
        TinkerbleObservableMacro.self,
        TinkerbleObservableStateMacro.self,
    ]
}

private struct ObservableActionMethod {
    let function: FunctionDeclSyntax
    let attribute: AttributeSyntax

    var methodName: String {
        function.name.text
    }

    var registrationName: String {
        "_tinkerbleAction_\(sanitizedMethodName)Registration"
    }

    var registrationDeclaration: String {
        """
        @ObservationIgnored
        private let \(registrationName) = TinkerbleActionRegistration()
        """
    }

    var activationCall: String {
        let arguments = ObservableActionArguments(attribute: attribute, defaultName: methodName)

        return """
        \(registrationName).activate(
            owner: self,
            name: \(arguments.name),
            screen: \(arguments.screen),
            category: \(arguments.category),
            perform: { owner in
                owner.\(methodName)()
            }
        )
        """
    }

    private var sanitizedMethodName: String {
        let allowedCharacters = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_"))
        return methodName.unicodeScalars.map { scalar in
            allowedCharacters.contains(scalar) ? String(scalar) : "_"
        }
        .joined()
    }
}

private struct ObservableStateProperty {
    let variable: VariableDeclSyntax
    let attribute: AttributeSyntax
    let context: MacroExpansionContext

    var isValid: Bool {
        propertyName != nil
            && variable.bindingSpecifier.tokenKind == .keyword(.var)
            && variable.bindings.count == 1
            && variable.bindings.first?.accessorBlock == nil
    }

    var propertyName: String? {
        variable.bindings.first?.pattern.as(IdentifierPatternSyntax.self)?.identifier.text
    }

    var registrationName: String {
        "_tinkerbleObservableState_\(sanitizedPropertyName)Registration"
    }

    var registrationDeclaration: String {
        """
        @ObservationIgnored
        private let \(registrationName) = TinkerbleObservableStateRegistration()
        """
    }

    var activationCall: String {
        guard let propertyName else { return "" }
        let arguments = ObservableStateArguments(attribute: attribute)

        return """
        \(registrationName).activate(
            owner: self,
            initialValue: \(propertyName),
            name: \(arguments.name),
            screen: \(arguments.screen),
            category: \(arguments.category),
            control: \(arguments.control),
            readValue: { owner in
                owner.\(propertyName)
            },
            applyRemoteValue: { owner, value in
                owner.\(propertyName) = value
            }
        )
        """
    }

    func diagnoseInvalidShape() {
        context.diagnose(
            Diagnostic(
                node: Syntax(variable),
                message: TinkerbleMacroDiagnostic(
                    "@TinkerbleObservableState can only be applied to a single stored var property."
                )
            )
        )
    }

    private var sanitizedPropertyName: String {
        guard let propertyName else { return "invalid" }
        let allowedCharacters = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_"))
        return propertyName.unicodeScalars.map { scalar in
            allowedCharacters.contains(scalar) ? String(scalar) : "_"
        }
        .joined()
    }
}

private struct ObservableActionArguments {
    var name: String
    var screen = "nil"
    var category = "nil"

    init(attribute: AttributeSyntax, defaultName: String) {
        name = "\"\(defaultName)\""
        guard case let .argumentList(arguments) = attribute.arguments else { return }

        for argument in arguments {
            let expression = argument.expression.description.trimmingCharacters(in: .whitespacesAndNewlines)
            switch argument.label?.text {
            case nil:
                name = expression
            case "name":
                name = expression == "nil" ? "\"\(defaultName)\"" : expression
            case "screen":
                screen = expression
            case "category":
                category = expression
            default:
                break
            }
        }
    }
}

private struct ObservableStateArguments {
    var name = "\"\""
    var screen = "nil"
    var category = "nil"
    var control = ".automatic"

    init(attribute: AttributeSyntax) {
        guard case let .argumentList(arguments) = attribute.arguments else { return }

        for argument in arguments {
            let expression = argument.expression.description.trimmingCharacters(in: .whitespacesAndNewlines)
            switch argument.label?.text {
            case nil:
                category = expression
            case "category":
                category = expression
            case "name":
                name = expression
            case "screen":
                screen = expression
            case "control":
                control = expression
            default:
                break
            }
        }
    }
}

private struct TinkerbleMacroDiagnostic: DiagnosticMessage {
    let message: String
    let diagnosticID: MessageID
    let severity: DiagnosticSeverity

    init(_ message: String) {
        self.message = message
        diagnosticID = MessageID(domain: "TinkerbleMacros", id: message)
        severity = .error
    }
}

private extension MemberBlockItemSyntax {
    var requiresExplicitInitializer: Bool {
        guard let variable = decl.as(VariableDeclSyntax.self),
              !variable.isStatic,
              variable.bindings.contains(where: { binding in
                  binding.initializer == nil && binding.accessorBlock == nil
              })
        else {
            return false
        }

        return true
    }
}

private extension VariableDeclSyntax {
    var isStatic: Bool {
        modifiers.contains { modifier in
            modifier.name.tokenKind == .keyword(.static) || modifier.name.tokenKind == .keyword(.class)
        }
    }

    var tinkerbleObservableStateAttribute: AttributeSyntax? {
        attributes.compactMap { element in
            guard let attribute = element.as(AttributeSyntax.self),
                  attribute.attributeName.description
                      .trimmingCharacters(in: .whitespacesAndNewlines)
                      .components(separatedBy: ".")
                      .last == "TinkerbleObservableState"
            else {
                return nil
            }
            return attribute
        }
        .first
    }
}

private extension FunctionDeclSyntax {
    var tinkerbleActionAttribute: AttributeSyntax? {
        attributes.compactMap { element in
            guard let attribute = element.as(AttributeSyntax.self),
                  attribute.attributeName.description
                      .trimmingCharacters(in: .whitespacesAndNewlines)
                      .components(separatedBy: ".")
                      .last == "TinkerbleAction"
            else {
                return nil
            }
            return attribute
        }
        .first
    }
}

private extension ClassDeclSyntax {
    func hasAttribute(named attributeName: String) -> Bool {
        attributes.contains { element in
            guard let attribute = element.as(AttributeSyntax.self) else { return false }
            return attribute.attributeName.description
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .components(separatedBy: ".")
                .last == attributeName
        }
    }
}

private extension String {
    var indentedByFourSpaces: String {
        split(separator: "\n", omittingEmptySubsequences: false)
            .map { line in line.isEmpty ? "" : "    \(line)" }
            .joined(separator: "\n")
    }
}

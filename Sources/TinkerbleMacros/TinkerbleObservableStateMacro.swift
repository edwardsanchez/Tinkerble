import Foundation
import SwiftCompilerPlugin
import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

@main
struct TinkerbleMacrosPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        TinkerbleObservableMacro.self,
        TinkerbleObservableStateMacro.self,
    ]
}

public struct TinkerbleObservableMacro: ExtensionMacro, MemberMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        let typeName = attachedTypeName(from: declaration)

        return [
            """
            @ObservationIgnored
            private let _tinkerbleObservationRegistrar = Observation.ObservationRegistrar()
            """,
            """
            internal nonisolated func access<Member>(keyPath: KeyPath<\(raw: typeName), Member>) {
                _tinkerbleObservationRegistrar.access(self, keyPath: keyPath)
            }
            """,
            """
            internal nonisolated func withMutation<Member, MutationResult>(
                keyPath: KeyPath<\(raw: typeName), Member>,
                _ mutation: () throws -> MutationResult
            ) rethrows -> MutationResult {
                try _tinkerbleObservationRegistrar.withMutation(of: self, keyPath: keyPath, mutation)
            }
            """,
        ]
    }

    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {
        [
            try ExtensionDeclSyntax(
                """
                extension \(type.trimmed): Observation.Observable {
                }
                """
            )
        ]
    }

    private static func attachedTypeName(from declaration: some DeclGroupSyntax) -> String {
        if let classDeclaration = declaration.as(ClassDeclSyntax.self) {
            return classDeclaration.name.text
        }
        if let structDeclaration = declaration.as(StructDeclSyntax.self) {
            return structDeclaration.name.text
        }
        if let actorDeclaration = declaration.as(ActorDeclSyntax.self) {
            return actorDeclaration.name.text
        }
        return "Self"
    }
}

public struct TinkerbleObservableStateMacro: AccessorMacro, PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let property = propertyInfo(from: declaration, context: context) else {
            return []
        }

        return [
            """
            @ObservationIgnored
            private var \(raw: property.backingName)\(raw: property.typeAnnotation) = \(raw: property.initializer)
            """,
            """
            @ObservationIgnored
            private let \(raw: property.registrationName) = TinkerbleObservableStateRegistration()
            """,
        ]
    }

    public static func expansion(
        of node: AttributeSyntax,
        providingAccessorsOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [AccessorDeclSyntax] {
        guard let property = propertyInfo(from: declaration, context: context) else {
            return []
        }

        let activation = activationCall(for: property, attribute: node)

        return [
            """
            get {
                access(keyPath: \\.\(raw: property.name))
                \(raw: activation)
                return \(raw: property.backingName)
            }
            """,
            """
            set {
                \(raw: activation)
                withMutation(keyPath: \\.\(raw: property.name)) {
                    \(raw: property.backingName) = newValue
                }
                \(raw: property.registrationName).updateLocalValue(newValue)
            }
            """,
        ]
    }

    private static func propertyInfo(
        from declaration: some DeclSyntaxProtocol,
        context: some MacroExpansionContext
    ) -> PropertyInfo? {
        guard let variable = declaration.as(VariableDeclSyntax.self),
              variable.bindingSpecifier.tokenKind == .keyword(.var)
        else {
            context.diagnose(.tinkerbleObservableState("@TinkerbleObservableState can only be applied to a var.", node: Syntax(declaration)))
            return nil
        }

        guard variable.bindings.count == 1,
              let binding = variable.bindings.first,
              let pattern = binding.pattern.as(IdentifierPatternSyntax.self)
        else {
            context.diagnose(.tinkerbleObservableState("@TinkerbleObservableState requires a single named property.", node: Syntax(variable)))
            return nil
        }

        guard binding.accessorBlock == nil else {
            context.diagnose(.tinkerbleObservableState("@TinkerbleObservableState requires a stored property.", node: Syntax(binding)))
            return nil
        }

        guard let initializer = binding.initializer?.value else {
            context.diagnose(.tinkerbleObservableState("@TinkerbleObservableState requires an initial value.", node: Syntax(binding)))
            return nil
        }

        let name = pattern.identifier.text
        return PropertyInfo(
            name: name,
            backingName: "_\(name)",
            registrationName: "_\(name)TinkerbleRegistration",
            typeAnnotation: binding.typeAnnotation.map { " \($0.trimmedDescription)" } ?? "",
            initializer: initializer.trimmedDescription
        )
    }

    private static func activationCall(
        for property: PropertyInfo,
        attribute: AttributeSyntax
    ) -> String {
        let arguments = forwardedArguments(from: attribute)
        let forwardedArguments = arguments.isEmpty ? "" : ", \(arguments)"

        return """
        \(property.registrationName).activate(
            owner: self,
            initialValue: \(property.backingName)\(forwardedArguments),
            applyRemoteValue: { owner, newValue in
                owner.\(property.name) = newValue
            }
        )
        """
    }

    private static func forwardedArguments(from attribute: AttributeSyntax) -> String {
        guard let arguments = attribute.arguments else { return "" }

        switch arguments {
        case let .argumentList(argumentList):
            return argumentList
                .map { argument in
                    var source = ""
                    if let label = argument.label {
                        source += "\(label.text): "
                    }
                    source += argument.expression.trimmedDescription
                    return source
                }
                .joined(separator: ", ")
        default:
            return arguments.description
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .trimmingCharacters(in: CharacterSet(charactersIn: "()"))
        }
    }
}

private struct PropertyInfo {
    var name: String
    var backingName: String
    var registrationName: String
    var typeAnnotation: String
    var initializer: String
}

private struct TinkerbleObservableStateDiagnostic: DiagnosticMessage {
    let message: String

    var diagnosticID: MessageID {
        MessageID(domain: "TinkerbleObservableState", id: "invalid-declaration")
    }

    var severity: DiagnosticSeverity { .error }
}

private extension Diagnostic {
    static func tinkerbleObservableState(_ message: String, node: Syntax) -> Diagnostic {
        Diagnostic(
            node: node,
            message: TinkerbleObservableStateDiagnostic(message: message)
        )
    }
}

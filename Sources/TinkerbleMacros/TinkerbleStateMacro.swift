import Foundation
import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

public struct TinkerbleStateMacro: AccessorMacro, PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingAccessorsOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [AccessorDeclSyntax] {
        guard let property = TinkerbleStateProperty(declaration: declaration) else {
            diagnoseInvalidProperty(declaration, in: context)
            return []
        }

        let storageName = property.initializer == nil ? property.backingName : property.storageName
        let enclosingNominalType = context.lexicalContext.first { syntax in
            syntax.is(StructDeclSyntax.self)
                || syntax.is(EnumDeclSyntax.self)
                || syntax.is(ClassDeclSyntax.self)
                || syntax.is(ActorDeclSyntax.self)
        }
        let setterIntroducer = if (enclosingNominalType?.is(StructDeclSyntax.self) == true
            || enclosingNominalType?.is(EnumDeclSyntax.self) == true)
            && !property.requiresMutatingSetter {
            "nonmutating set"
        } else {
            "set"
        }
        var accessors: [AccessorDeclSyntax] = [
            """
            @storageRestrictions(initializes: \(raw: storageName))
            init(initialValue) {
                \(raw: storageName) = \(raw: property.runtimeStateType)(
                    wrappedValue: initialValue,
                    \(raw: runtimeArguments(node, property: property, context: context))
                )
            }
            """
        ]

        accessors.append(
            """
            get {
                \(raw: storageName).wrappedValue
            }
            """
        )
        var setterStatements: [String] = []
        let oldValueName: String?
        if property.didSetObserver != nil {
            let generatedOldValueName = context.makeUniqueName("oldValue").trimmedDescription
            oldValueName = generatedOldValueName
            setterStatements.append("let \(generatedOldValueName) = \(storageName).wrappedValue")
        } else {
            oldValueName = nil
        }
        if let observer = property.willSetObserver {
            setterStatements.append(
                observerInvocation(observer, defaultParameterName: "newValue", argument: "newValue")
            )
        }
        setterStatements.append("\(storageName).wrappedValue = newValue")
        if let observer = property.didSetObserver, let oldValueName {
            setterStatements.append(
                observerInvocation(observer, defaultParameterName: "oldValue", argument: oldValueName)
            )
        }
        accessors.append(
            """
            \(raw: setterIntroducer) {
                \(raw: setterStatements.joined(separator: "\n"))
            }
            """
        )
        return accessors
    }

    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let property = TinkerbleStateProperty(declaration: declaration) else {
            return []
        }

        let arguments = runtimeArguments(node, property: property, context: context)
        let projectedAccess = property.projectedAccessPrefix

        if property.initializer != nil, let initialValue = property.typedInitialValueExpression {
            return [
                """
                private var \(raw: property.storageName) = \(raw: property.runtimeStateType)(
                    wrappedValue: \(raw: initialValue),
                    \(raw: arguments)
                )
                """,
                """
                @_TinkerbleStateBacking
                private var \(raw: property.backingName) = \(raw: property.runtimeStateType)(
                    wrappedValue: \(raw: initialValue),
                    \(raw: arguments)
                )
                """,
                """
                @_TinkerbleStateProjected
                \(raw: projectedAccess)var \(raw: property.projectedName) = \(raw: property.runtimeStateType)(
                    wrappedValue: \(raw: initialValue),
                    \(raw: arguments)
                ).projectedValue
                """
            ]
        }

        guard let type = property.type else {
            diagnoseInvalidProperty(declaration, in: context)
            return []
        }

        return [
            "private var \(raw: property.backingName): Tinkerble.MacroRuntime.State<\(type)>",
            """
            \(raw: projectedAccess)var \(raw: property.projectedName): SwiftUI.Binding<\(type)> {
                \(raw: property.backingName).projectedValue
            }
            """
        ]
    }

    private static func diagnoseInvalidProperty(
        _ declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) {
        context.diagnose(
            Diagnostic(
                node: Syntax(declaration),
                message: TinkerbleStateDiagnostic(
                    "@TinkerbleState can only be applied to a single stored var property with an initializer or explicit type."
                )
            )
        )
    }

    private static func macroArguments(_ node: AttributeSyntax) -> String {
        guard case let .argumentList(arguments) = node.arguments else {
            return "\"\""
        }
        guard var lastArgument = arguments.last, lastArgument.trailingComma != nil else {
            return arguments.description
        }
        lastArgument.trailingComma = nil
        return arguments.dropLast().map(\.description).joined() + lastArgument.description
    }

    private static func observerInvocation(
        _ observer: AccessorDeclSyntax,
        defaultParameterName: String,
        argument: String
    ) -> String {
        let parameterName = observer.parameters?.name.text ?? defaultParameterName
        let statements = observer.body?.statements.trimmedDescription ?? ""
        return """
        ({ \(parameterName) in
            \(statements)
        })(\(argument))
        """
    }

    private static func runtimeArguments(
        _ node: AttributeSyntax,
        property: TinkerbleStateProperty,
        context: some MacroExpansionContext
    ) -> String {
        let arguments = macroArguments(node)
        let sourceAnchor = tinkerbleSourceAnchorExpression(
            variable: property.variable,
            propertyName: property.name,
            initializer: property.initializer,
            context: context
        )
        return "\(arguments), _sourceAnchor: \(sourceAnchor)"
    }
}

public struct TinkerbleStateBackingMacro: AccessorMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingAccessorsOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [AccessorDeclSyntax] {
        guard let variable = declaration.as(VariableDeclSyntax.self),
              let binding = variable.bindings.first,
              let identifier = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier.text,
              identifier.hasPrefix("_"),
              !identifier.hasPrefix("__")
        else {
            return []
        }

        let storageName = "_\(identifier)"
        return [
            "get { \(raw: storageName) }",
            "set { \(raw: storageName).wrappedValue = newValue._tinkerbleInitializationValue }"
        ]
    }
}

public struct TinkerbleStateProjectedMacro: AccessorMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingAccessorsOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [AccessorDeclSyntax] {
        guard let variable = declaration.as(VariableDeclSyntax.self),
              let binding = variable.bindings.first,
              let identifier = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier.text,
              identifier.hasPrefix("$")
        else {
            return []
        }

        let storageName = "__\(identifier.dropFirst())"
        return ["get { \(raw: storageName).projectedValue }"]
    }
}

private struct TinkerbleStateProperty {
    let variable: VariableDeclSyntax
    let binding: PatternBindingSyntax
    let name: String

    init?(declaration: some DeclSyntaxProtocol) {
        guard let variable = declaration.as(VariableDeclSyntax.self),
              variable.bindingSpecifier.tokenKind == .keyword(.var),
              !variable.isStatic,
              variable.bindings.count == 1,
              let binding = variable.bindings.first,
              let identifier = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier.text,
              binding.initializer != nil || binding.typeAnnotation != nil,
              binding.hasOnlySupportedObservers
        else {
            return nil
        }

        self.variable = variable
        self.binding = binding
        name = identifier
    }

    var initializer: ExprSyntax? {
        binding.initializer?.value
    }

    var type: TypeSyntax? {
        binding.typeAnnotation?.type
    }

    var typedInitialValueExpression: String? {
        guard let initializer else { return nil }
        guard let type else { return initializer.description }
        return """
        ({
            let value: \(type.trimmedDescription) = \(initializer.description)
            return value
        }())
        """
    }

    var runtimeStateType: String {
        guard let type else { return "Tinkerble.MacroRuntime.State" }
        return "Tinkerble.MacroRuntime.State<\(type.trimmedDescription)>"
    }

    var willSetObserver: AccessorDeclSyntax? {
        binding.observers.first { $0.accessorSpecifier.text == "willSet" }
    }

    var didSetObserver: AccessorDeclSyntax? {
        binding.observers.first { $0.accessorSpecifier.text == "didSet" }
    }

    var requiresMutatingSetter: Bool {
        binding.observers.contains { observer in
            observer.modifiers.contains { $0.name.tokenKind == .keyword(.mutating) }
        }
    }

    var storageName: String {
        "__\(name)"
    }

    var backingName: String {
        "_\(name)"
    }

    var projectedName: String {
        "$\(name)"
    }

    var projectedAccessPrefix: String {
        guard let access = variable.modifiers.first(where: { modifier in
            ["private", "fileprivate", "package", "public", "open"].contains(modifier.name.text)
        })?.name.text else {
            return ""
        }
        return "\(access) "
    }
}

private extension PatternBindingSyntax {
    var observers: [AccessorDeclSyntax] {
        guard let accessorBlock else { return [] }
        guard case let .accessors(accessors) = accessorBlock.accessors else { return [] }
        return Array(accessors)
    }

    var hasOnlySupportedObservers: Bool {
        guard let accessorBlock else { return true }
        guard case let .accessors(accessors) = accessorBlock.accessors else { return false }
        let observers = Array(accessors)
        guard observers.allSatisfy({ observer in
            ["willSet", "didSet"].contains(observer.accessorSpecifier.text) && observer.body != nil
        }) else {
            return false
        }
        return observers.filter { $0.accessorSpecifier.text == "willSet" }.count <= 1
            && observers.filter { $0.accessorSpecifier.text == "didSet" }.count <= 1
    }
}

private struct TinkerbleStateDiagnostic: DiagnosticMessage {
    let message: String
    let diagnosticID: MessageID
    let severity: DiagnosticSeverity

    init(_ message: String) {
        self.message = message
        diagnosticID = MessageID(domain: "TinkerbleMacros", id: "invalid-tinkerble-state")
        severity = .error
    }
}

private extension VariableDeclSyntax {
    var isStatic: Bool {
        modifiers.contains { modifier in
            modifier.name.tokenKind == .keyword(.static) || modifier.name.tokenKind == .keyword(.class)
        }
    }
}

func tinkerbleSourceAnchorExpression(
    variable: VariableDeclSyntax,
    propertyName: String,
    initializer: ExprSyntax?,
    enclosingTypePathOverride: [String]? = nil,
    context: some MacroExpansionContext
) -> String {
    if let buildConfiguration = context.buildConfiguration,
       (try? buildConfiguration.isCustomConditionSet(name: "DEBUG")) == false {
        return "nil"
    }

    guard let location = context.location(
        of: variable,
        at: .afterLeadingTrivia,
        filePathMode: .filePath
    ) else {
        return "nil"
    }

    let enclosingTypes = enclosingTypePathOverride
        ?? context.lexicalContext.reversed().flatMap(tinkerbleEnclosingTypeNames)
    let enclosingTypeExpression = enclosingTypes
        .map { "\"\($0.swiftStringLiteralEscaped)\"" }
        .joined(separator: ", ")
    let initializerExpression = initializer?.trimmedDescription ?? ""

    return """
    Tinkerble.MacroRuntime.SourceAnchor(
        filePath: \(location.file),
        line: \(location.line),
        column: \(location.column),
        enclosingTypePath: [\(enclosingTypeExpression)],
        propertyName: "\(propertyName.swiftStringLiteralEscaped)",
        initializerExpression: "\(initializerExpression.swiftStringLiteralEscaped)"
    )
    """
}

func tinkerbleEnclosingTypeNames(_ syntax: Syntax) -> [String] {
    if let declaration = syntax.as(StructDeclSyntax.self) {
        return [declaration.name.text]
    }
    if let declaration = syntax.as(ClassDeclSyntax.self) {
        return [declaration.name.text]
    }
    if let declaration = syntax.as(EnumDeclSyntax.self) {
        return [declaration.name.text]
    }
    if let declaration = syntax.as(ActorDeclSyntax.self) {
        return [declaration.name.text]
    }
    if let declaration = syntax.as(ExtensionDeclSyntax.self) {
        return declaration.extendedType.trimmedDescription
            .split(separator: ".")
            .map(String.init)
    }
    return []
}

private extension String {
    var swiftStringLiteralEscaped: String {
        var result = ""
        result.reserveCapacity(count)
        for character in self {
            switch character {
            case "\\": result += "\\\\"
            case "\"": result += "\\\""
            case "\n": result += "\\n"
            case "\r": result += "\\r"
            case "\t": result += "\\t"
            case "\0": result += "\\0"
            default: result.append(character)
            }
        }
        return result
    }
}

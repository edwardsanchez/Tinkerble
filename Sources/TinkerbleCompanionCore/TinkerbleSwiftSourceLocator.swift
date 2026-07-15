import Foundation
import SwiftParser
import SwiftSyntax
import Tinkerble

struct TinkerbleLocatedInitializer {
    var expression: String
    var utf8Range: Range<Int>
}

struct TinkerbleSwiftSourceLocator {
    func locate(
        anchor: TinkerbleSourceAnchor,
        acceptedInitializerExpressions: [String],
        source: String,
        tweak: TinkerbleTweak
    ) throws -> TinkerbleLocatedInitializer {
        let sourceFile = Parser.parse(source: source)
        guard !sourceFile.hasError else {
            throw TinkerbleSourceEditIssue(tweak: tweak, reason: .parseFailure(anchor.filePath))
        }

        let visitor = TinkerbleVariableVisitor(viewMode: .sourceAccurate)
        visitor.walk(sourceFile)
        let matchingDeclarations = visitor.variables.filter { variable in
            variable.propertyName == anchor.propertyName
                && variable.enclosingTypePath == anchor.enclosingTypePath
                && variable.hasTinkerbleAttribute
        }

        guard !matchingDeclarations.isEmpty else {
            throw TinkerbleSourceEditIssue(tweak: tweak, reason: .declarationMissing(anchor.filePath))
        }

        let sourceLocationConverter = SourceLocationConverter(fileName: anchor.filePath, tree: sourceFile)
        let declarations: [TinkerbleVisitedVariable]
        if matchingDeclarations.count == 1 {
            declarations = matchingDeclarations
        } else {
            let declarationsAtAnchor = matchingDeclarations.filter { declaration in
                let location = sourceLocationConverter.location(for: declaration.position)
                return location.line == anchor.line && location.column == anchor.column
            }
            guard declarationsAtAnchor.count == 1 else {
                throw TinkerbleSourceEditIssue(tweak: tweak, reason: .declarationAmbiguous(anchor.filePath))
            }
            declarations = declarationsAtAnchor
        }

        let initializedDeclarations = declarations.compactMap { declaration -> TinkerbleVariableCandidate? in
            guard let initializer = declaration.initializer else { return nil }
            return .init(
                expression: initializer.trimmedDescription,
                canonicalExpression: canonicalExpression(initializer),
                utf8Range: initializer.positionAfterSkippingLeadingTrivia.utf8Offset..<initializer.endPositionBeforeTrailingTrivia.utf8Offset
            )
        }

        guard !initializedDeclarations.isEmpty else {
            throw TinkerbleSourceEditIssue(tweak: tweak, reason: .initializerMissing(anchor.filePath))
        }

        let accepted = Set(
            ([anchor.initializerExpression] + acceptedInitializerExpressions)
                .compactMap(canonicalExpression)
        )
        let matches = initializedDeclarations.filter { accepted.contains($0.canonicalExpression) }

        guard !matches.isEmpty else {
            throw TinkerbleSourceEditIssue(
                tweak: tweak,
                reason: .staleInitializer(
                    expected: [anchor.initializerExpression] + acceptedInitializerExpressions,
                    actual: initializedDeclarations.map(\.expression).joined(separator: ", ")
                )
            )
        }
        guard matches.count == 1 else {
            throw TinkerbleSourceEditIssue(tweak: tweak, reason: .declarationAmbiguous(anchor.filePath))
        }

        return TinkerbleLocatedInitializer(expression: matches[0].expression, utf8Range: matches[0].utf8Range)
    }

    func canonicalExpression(_ expression: String) -> String? {
        let file = Parser.parse(source: "let _tinkerbleValue = \(expression)")
        guard !file.hasError,
              let variable = file.statements.first?.item.as(VariableDeclSyntax.self),
              let initializer = variable.bindings.first?.initializer
        else {
            return nil
        }
        return canonicalExpression(initializer.value)
    }

    private func canonicalExpression(_ expression: ExprSyntax) -> String {
        expression.tokens(viewMode: .sourceAccurate)
            .map { token in "\(token.text.utf8.count):\(token.text)" }
            .joined(separator: "|")
    }
}

private struct TinkerbleVariableCandidate {
    var expression: String
    var canonicalExpression: String
    var utf8Range: Range<Int>
}

private struct TinkerbleVisitedVariable {
    var propertyName: String
    var enclosingTypePath: [String]
    var initializer: ExprSyntax?
    var hasTinkerbleAttribute: Bool
    var position: AbsolutePosition
}

private final class TinkerbleVariableVisitor: SyntaxVisitor {
    private(set) var variables: [TinkerbleVisitedVariable] = []
    private var enclosingTypePath: [String] = []

    override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
        enclosingTypePath.append(node.name.text)
        return .visitChildren
    }

    override func visitPost(_ node: StructDeclSyntax) {
        enclosingTypePath.removeLast()
    }

    override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind {
        enclosingTypePath.append(node.name.text)
        return .visitChildren
    }

    override func visitPost(_ node: ClassDeclSyntax) {
        enclosingTypePath.removeLast()
    }

    override func visit(_ node: EnumDeclSyntax) -> SyntaxVisitorContinueKind {
        enclosingTypePath.append(node.name.text)
        return .visitChildren
    }

    override func visitPost(_ node: EnumDeclSyntax) {
        enclosingTypePath.removeLast()
    }

    override func visit(_ node: ActorDeclSyntax) -> SyntaxVisitorContinueKind {
        enclosingTypePath.append(node.name.text)
        return .visitChildren
    }

    override func visitPost(_ node: ActorDeclSyntax) {
        enclosingTypePath.removeLast()
    }

    override func visit(_ node: ExtensionDeclSyntax) -> SyntaxVisitorContinueKind {
        enclosingTypePath.append(contentsOf: extensionPath(node.extendedType.trimmedDescription))
        return .visitChildren
    }

    override func visitPost(_ node: ExtensionDeclSyntax) {
        enclosingTypePath.removeLast(extensionPath(node.extendedType.trimmedDescription).count)
    }

    override func visit(_ node: VariableDeclSyntax) -> SyntaxVisitorContinueKind {
        guard node.bindings.count == 1,
              let binding = node.bindings.first,
              let identifier = binding.pattern.as(IdentifierPatternSyntax.self)
        else {
            return .skipChildren
        }

        variables.append(
            .init(
                propertyName: identifier.identifier.text,
                enclosingTypePath: enclosingTypePath,
                initializer: binding.initializer?.value,
                hasTinkerbleAttribute: node.attributes.containsTinkerbleSourceAttribute,
                position: node.positionAfterSkippingLeadingTrivia
            )
        )
        return .skipChildren
    }

    private func extensionPath(_ value: String) -> [String] {
        value.split(separator: ".").map(String.init)
    }
}

private extension AttributeListSyntax {
    var containsTinkerbleSourceAttribute: Bool {
        contains { element in
            guard let attribute = element.as(AttributeSyntax.self) else { return false }
            let name = attribute.attributeName.trimmedDescription.split(separator: ".").last.map(String.init)
            return name == "TinkerbleState" || name == "TinkerbleObservableState"
        }
    }
}

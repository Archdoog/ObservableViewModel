import SwiftSyntax
import SwiftDiagnostics

/// An error the macro reports against one piece of syntax.
struct MacroError: Error, DiagnosticMessage {
    let message: String
    let diagnosticID: MessageID
    let severity: DiagnosticSeverity = .error

    init(_ message: String, id: String) {
        self.message = message
        self.diagnosticID = MessageID(domain: "ObservableViewModel", id: id)
    }
}

/// Attributes that say nothing about isolation.
///
/// Anything else on a declaration counts as a stated actor. A macro cannot
/// resolve a type, so the check reads names and nothing more. See docs/adr/0003.
private let nonIsolationAttributes: Set<String> = [
    "Observable", "ObservableViewModel", "Inject", "Sendable", "unchecked",
    "retroactive", "available", "objc", "objcMembers", "nonobjc", "inlinable",
    "usableFromInline", "frozen", "discardableResult", "dynamicMemberLookup",
    "preconcurrency", "propertyWrapper", "resultBuilder", "warn_unqualified_access"
]

extension DeclGroupSyntax {

    /// The names of every attribute on the declaration.
    var attributeNames: [String] {
        attributes.compactMap { attribute in
            guard case .attribute(let attribute) = attribute else { return nil }
            return attribute.attributeName.trimmedDescription
        }
    }

    /// The first attribute that states an actor, or `nil`.
    var statedActor: String? {
        attributeNames.first { !nonIsolationAttributes.contains($0) }
    }

    /// True when the declaration carries the named attribute.
    func hasAttribute(_ name: String) -> Bool {
        attributeNames.contains(name)
    }

    /// Every initializer the declaration writes out.
    var declaredInitializers: [InitializerDeclSyntax] {
        memberBlock.members.compactMap { $0.decl.as(InitializerDeclSyntax.self) }
    }

    /// The stored property with the given name, or `nil`.
    func property(named name: String) -> VariableDeclSyntax? {
        memberBlock.members
            .compactMap { $0.decl.as(VariableDeclSyntax.self) }
            .first { declaration in
                declaration.bindings.contains { binding in
                    binding.pattern.as(IdentifierPatternSyntax.self)?.identifier.text == name
                }
            }
    }
}

extension VariableDeclSyntax {

    /// True when the property carries the named attribute.
    func hasAttribute(_ name: String) -> Bool {
        attributes.contains { attribute in
            guard case .attribute(let attribute) = attribute else { return false }
            return attribute.attributeName.trimmedDescription == name
        }
    }

    /// The type of the property.
    ///
    /// It reads the annotation first. Without one, it reads the name of the
    /// type the initializer calls, so `var state = SomeState()` also works.
    var resolvedTypeName: String? {
        guard let binding = bindings.first else { return nil }
        if let annotation = binding.typeAnnotation {
            return annotation.type.trimmedDescription
        }
        guard let call = binding.initializer?.value.as(FunctionCallExprSyntax.self),
              let callee = call.calledExpression.as(DeclReferenceExprSyntax.self)
        else { return nil }
        return callee.baseName.text
    }
}

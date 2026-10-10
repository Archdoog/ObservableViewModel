import SwiftSyntax
import SwiftSyntaxMacros

/// Writes the dependency properties, the initializer, and the conformance.
///
/// It writes nothing else. Everything it writes is code a developer can write
/// by hand. See docs/adr/0004.
public struct ObservableViewModelMacro {

    /// Reads the property names out of the key path arguments.
    ///
    /// `\.someUseCase` gives `someUseCase`. The macro never learns the type,
    /// so the generated property takes its type by inference. See docs/adr/0002.
    static func dependencyNames(of node: AttributeSyntax) throws -> [String] {
        guard let arguments = node.arguments?.as(LabeledExprListSyntax.self) else { return [] }
        return try arguments.map { argument in
            guard let keyPath = argument.expression.as(KeyPathExprSyntax.self),
                  let last = keyPath.components.last,
                  let property = last.component.as(KeyPathPropertyComponentSyntax.self)
            else {
                throw MacroError(
                    "@ObservableViewModel takes key paths, such as \\.someUseCase.",
                    id: "badKeyPath"
                )
            }
            return property.declName.baseName.text
        }
    }

    /// Fails the build when the view model does not state what the macro reads.
    static func checkPreconditions(_ declaration: some DeclGroupSyntax) throws -> String {
        guard declaration.is(ClassDeclSyntax.self) else {
            throw MacroError("@ObservableViewModel applies to a class.", id: "notAClass")
        }
        guard declaration.statedActor != nil else {
            throw MacroError(
                """
                @ObservableViewModel needs an actor attribute on this class. \
                Add @ViewModelActor, or another global actor.
                """,
                id: "missingActor"
            )
        }
        guard declaration.hasAttribute("Observable") else {
            throw MacroError(
                """
                @ObservableViewModel needs @Observable on this class. \
                A macro cannot add it, because @Observable cannot see a \
                property that a macro writes.
                """,
                id: "missingObservable"
            )
        }
        guard let state = declaration.property(named: "state") else {
            throw MacroError(
                """
                @ObservableViewModel needs a state property that conforms to ViewState. 
                Add @MainActor var state = MyState().
                """,
                id: "missingState"
            )
        }
        guard state.hasAttribute("MainActor") else {
            throw MacroError(
                """
                The state property needs @MainActor. SwiftUI reads it from \
                body, and body cannot await.
                """,
                id: "stateNotOnMain"
            )
        }
        // A default value on `state` makes Swift synthesize an initializer
        // that is isolated to both the class actor and the main actor, which
        // does not compile. The macro writes the default instead.
        guard state.bindings.allSatisfy({ $0.initializer == nil }) else {
            throw MacroError(
                """
                The state property must not have a default value. Write \
                @MainActor var state: MyState, and the macro writes \
                init(initialState: MyState = MyState()) for you.
                """,
                id: "stateHasDefault"
            )
        }
        guard let stateType = state.resolvedTypeName else {
            throw MacroError(
                "Write the type of state, as in @MainActor var state: MyState.",
                id: "unreadableStateType"
            )
        }
        return stateType
    }
}

extension ObservableViewModelMacro: MemberMacro {

    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        let stateType = try checkPreconditions(declaration)

        guard declaration.declaredInitializers.isEmpty else {
            throw MacroError(
                """
                @ObservableViewModel writes the initializer, so this class \
                must not declare one. To set up state, pass it in: \
                MyViewModel(initialState: MyState(...)).
                """,
                id: "declaredInitializer"
            )
        }

        let dependencies = try dependencyNames(of: node).map { name in
            "private let \(raw: name) = Container.shared.\(raw: name)()" as DeclSyntax
        }

        let initializer: DeclSyntax = """
            @MainActor init(initialState: \(raw: stateType) = \(raw: stateType)()) {
                self.state = initialState
            }
            """

        return dependencies + [initializer]
    }
}

extension ObservableViewModelMacro: ExtensionMacro {

    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {
        guard !protocols.isEmpty else { return [] }
        return [try ExtensionDeclSyntax("extension \(raw: type.trimmedDescription): ViewModel {}")]
    }
}

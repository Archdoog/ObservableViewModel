import FactoryKit

/// Writes the dependency properties, the initializer, and the `ViewModel`
/// conformance for a view model.
///
/// Write the actor attribute, `@Observable`, and `state` yourself. The macro
/// reads them. It cannot write them, because Swift expands attached macros
/// independently and `@Observable` cannot see a property that a macro wrote.
/// See docs/adr/0004.
///
/// ```swift
/// @ViewModelActor
/// @Observable
/// @ObservableViewModel(\.someUseCase, \.otherUseCase)
/// final class SomeViewModel {
///     @MainActor var state: SomeState
///
///     func doSomething() async {
///         let value = await someUseCase()
///         await setState(\.title, value)
///     }
/// }
/// ```
///
/// For a dependency on a container other than `Container`, leave it out of the
/// macro and write the property yourself:
/// `private let other = CustomContainer.shared.other()`.
@attached(member, names: arbitrary)
@attached(extension, conformances: ViewModel)
public macro ObservableViewModel<each Dependency>(
    _ dependencies: repeat KeyPath<Container, Factory<each Dependency>>
) = #externalMacro(module: "ObservableViewModelMacros", type: "ObservableViewModelMacro")

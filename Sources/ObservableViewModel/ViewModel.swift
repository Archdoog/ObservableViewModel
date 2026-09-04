import Observation

/// A view model that holds main-actor state and routes work to its actor.
///
/// `@ObservableViewModel` adds this conformance. Do not write it by hand.
public protocol ViewModel: AnyObject, Observable, Sendable {
    associatedtype State: ViewState

    /// The one property a view reads. It stays on the main actor, because
    /// SwiftUI reads it from `body` and `body` cannot await. See docs/adr/0001.
    @MainActor var state: State { get set }
}

extension ViewModel {

    /// Writes one field of the state.
    ///
    /// Call this from a method that runs on the view model actor. The `await`
    /// moves the write to the main actor.
    @MainActor
    public func setState<Value: Sendable>(
        _ keyPath: WritableKeyPath<State, Value>,
        _ value: Value
    ) {
        state[keyPath: keyPath] = value
    }

    /// Reads and writes the state in one main-actor step.
    ///
    /// Use this form for a read-modify-write. A separate read and write cross
    /// the actor boundary twice, and another task can run in the gap.
    @MainActor
    public func setState(_ body: sending (inout State) -> Void) {
        body(&state)
    }
}

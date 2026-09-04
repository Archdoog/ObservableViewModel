/// The value a view model publishes to its view.
///
/// A view model reads and writes its state across an actor boundary, so the
/// type must be `Sendable`. The macro writes an initializer with a default
/// argument, so the type must also have a no-argument initializer.
public protocol ViewState: Sendable {
    init()
}

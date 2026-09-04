/// The default actor for view model behavior.
///
/// Every view model in an app shares this one serial executor, so a view model
/// method must not do slow synchronous work. It routes the work to a dependency
/// that states its own actor. See docs/adr/0003.
///
/// To split view models across more than one executor, declare another global
/// actor and write that attribute instead.
@globalActor
public actor ViewModelActor {
    public static let shared = ViewModelActor()
}

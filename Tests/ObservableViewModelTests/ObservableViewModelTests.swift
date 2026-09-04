import Testing
import Observation
import FactoryKit
@testable import ObservableViewModel

@globalActor
actor DomainActor {
    static let shared = DomainActor()
}

struct CounterState: ViewState {
    var title = ""
    var count = 0
}

@DomainActor
protocol Greeting: Sendable {
    func callAsFunction() -> String
}

@DomainActor
final class Greeter: Greeting {
    func callAsFunction() -> String { "hello" }
}

// Registration is plain Factory. See docs/adr/0005.
extension Container {
    var greeter: Factory<any Greeting> { self { Greeter() }.scope(.cached) }
}

@ViewModelActor
@Observable
@ObservableViewModel(\.greeter)
final class CounterViewModel {
    @MainActor var state: CounterState

    func load() async {
        await setState(\.title, await greeter())
        await setState { $0.count += 1 }
    }
}

@Suite(.serialized)
struct MacroTests {

@Test @MainActor
func macroWiresUpStateAndDependencies() async throws {
    let viewModel = CounterViewModel()
    #expect(viewModel.state.title == "")

    await viewModel.load()

    #expect(viewModel.state.title == "hello")
    #expect(viewModel.state.count == 1)
}

@Test @MainActor
func initialStateCanBeSuppliedByTheView() async throws {
    let viewModel = CounterViewModel(initialState: CounterState(title: "seeded", count: 7))
    #expect(viewModel.state.title == "seeded")
    #expect(viewModel.state.count == 7)
}

@Test @MainActor
func theProtocolRegistrationLetsATestSwapTheDependency() async throws {
    @DomainActor final class Quiet: Greeting { func callAsFunction() -> String { "shh" } }
    Container.shared.greeter.register { Quiet() }
    // `.all` clears the scope cache too. A plain reset leaves the cached
    // mock in place for the next test.
    defer { Container.shared.greeter.reset(.all) }

    let viewModel = CounterViewModel()
    await viewModel.load()

    #expect(viewModel.state.title == "shh")
}

@Test @MainActor
func stateIsObservable() async throws {
    let viewModel = CounterViewModel()
    final class Box: @unchecked Sendable { var fired = false }
    let box = Box()

    withObservationTracking { _ = viewModel.state } onChange: { box.fired = true }
    await viewModel.load()

    #expect(box.fired)
}
}

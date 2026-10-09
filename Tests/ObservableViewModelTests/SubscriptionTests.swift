import SwiftUI
import Testing
import FactoryKit
@testable import ObservableViewModel

@DomainActor
protocol Ticker: Sendable {
    func ticks() -> AsyncStream<Int>
    func laps() -> AsyncStream<Int>
}

@DomainActor
final class FiniteTicker: Ticker {
    func ticks() -> AsyncStream<Int> {
        AsyncStream { $0.yield(1); $0.yield(2); $0.finish() }
    }

    func laps() -> AsyncStream<Int> {
        AsyncStream { $0.yield(7); $0.finish() }
    }
}

extension Container {
    var ticker: Factory<any Ticker> { self { FiniteTicker() }.scope(.cached) }
}

struct TickState: ViewState {
    var count = 0
    var laps = 0
}

@ViewModelActor
@Observable
@ObservableViewModel(\.ticker)
final class TickViewModel {
    @MainActor var state: TickState

    func observe() async {
        let ticks = await ticker.ticks()
        let laps = await ticker.laps()
        await withDiscardingTaskGroup { group in
            group.addTask { await self.bind(ticks, to: \.count) }
            group.addTask { await self.bind(laps, to: \.laps) }
        }
    }
}

struct StreamError: Error {}

@MainActor
@Observable
final class Source {
    var value = 1
}

/// Waits until the condition is true, or gives up after many turns.
@MainActor
func waitUntil(_ condition: () -> Bool) async {
    for _ in 0 ..< 10_000 {
        if condition() { return }
        await Task.yield()
    }
}

@Suite("Observe")
@MainActor
struct ObserveTests {

    @Test
    func theDefaultObserveReturnsAtOnce() async {
        await CounterViewModel().observe()
    }

    @Test
    func anOverrideBindsEachStream() async {
        let viewModel = TickViewModel()

        await viewModel.observe()

        #expect(viewModel.state.count == 2)
        #expect(viewModel.state.laps == 7)
    }

    @Test
    func aGenericCallerReachesTheOverride() async {
        // The modifier sees only `some ViewModel`. This call takes the same path.
        func observe(_ viewModel: some ViewModel) async { await viewModel.observe() }
        let viewModel = TickViewModel()

        await observe(viewModel)

        #expect(viewModel.state.count == 2)
    }

    @Test
    func cancellingTheTaskStopsTheBinding() async {
        let (stream, continuation) = AsyncStream<Int>.makeStream()
        let viewModel = TickViewModel()

        let task = Task { await viewModel.bind(stream, to: \.count) }
        continuation.yield(5)
        await waitUntil { viewModel.state.count == 5 }
        task.cancel()
        await task.value

        // The stream is still open. Only the cancellation can end the task.
        #expect(viewModel.state.count == 5)
    }

    @Test
    func aThrowingStreamKeepsItsValuesAndThrowsItsError() async {
        let (stream, continuation) = AsyncThrowingStream<Int, any Error>.makeStream()
        let viewModel = TickViewModel()

        continuation.yield(4)
        continuation.finish(throwing: StreamError())

        await #expect(throws: StreamError.self) {
            try await viewModel.bind(stream, to: \.count)
        }
        #expect(viewModel.state.count == 4)
    }

    @Test @available(iOS 26.0, macOS 26.0, *)
    func observationsBindWithoutTry() async {
        let source = Source()
        let viewModel = TickViewModel()

        let task = Task { await viewModel.bind(Observations { source.value }, to: \.count) }
        await waitUntil { viewModel.state.count == 1 }
        source.value = 3
        await waitUntil { viewModel.state.count == 3 }
        task.cancel()
        await task.value

        #expect(viewModel.state.count == 3)
    }

    @Test
    func theModifierAcceptsAnyViewModel() {
        _ = EmptyView().observe(on: TickViewModel())
        _ = EmptyView().observe(on: CounterViewModel())
    }
}

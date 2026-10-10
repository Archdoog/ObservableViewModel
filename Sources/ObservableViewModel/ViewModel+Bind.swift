/// Each `bind` method writes each value of a sequence to one field of the
/// state. It returns when the sequence finishes or the task is cancelled.
///
/// Each call waits for its sequence, so put two or more calls in a task group:
///
/// ```swift
/// func observe() async {
///     let ticks = await ticker.ticks()
///     let times = await clock.times()
///     await withDiscardingTaskGroup { group in
///         group.addTask { await self.bind(ticks, to: \.count) }
///         group.addTask { await self.bind(times, to: \.time) }
///     }
/// }
/// ```
extension ViewModel {

    public func bind<Value: Sendable>(
        _ stream: AsyncStream<Value>,
        to keyPath: WritableKeyPath<State, Value> & Sendable
    ) async {
        for await value in stream {
            await setState(keyPath, value)
        }
    }

    /// If the stream fails, the method throws the error. The values before
    /// the error stay in the state.
    public func bind<Value: Sendable>(
        _ stream: AsyncThrowingStream<Value, any Error>,
        to keyPath: WritableKeyPath<State, Value> & Sendable
    ) async throws {
        for try await value in stream {
            await setState(keyPath, value)
        }
    }

    /// Binds any sequence, such as `Observations`. The method throws only
    /// the failure type of the sequence, so a sequence that cannot fail
    /// needs no `try`.
    @available(iOS 18.0, macOS 15.0, *)
    public func bind<Sequence: AsyncSequence & Sendable>(
        _ sequence: Sequence,
        to keyPath: WritableKeyPath<State, Sequence.Element> & Sendable
    ) async throws(Sequence.Failure) where Sequence.Element: Sendable {
        for try await value in sequence {
            await setState(keyPath, value)
        }
    }
}

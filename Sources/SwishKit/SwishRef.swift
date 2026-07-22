import Synchronization

/// A Swish ref — a transactional mutable reference to a value, mutated only
/// within a `dosync` transaction via `ref-set`/`alter`/`commute`.
public final class SwishRef: @unchecked Sendable {
    private struct State {
        var value: Expr
        var version: Int = 0
        var metadata: [Expr: Expr]?
        var validator: Expr?
        var watches: [Expr: Expr] = [:]
        /// Recorded for API compatibility with `ref-min-history`/`ref-max-history`;
        /// this implementation does not retain ref history (see CLAUDE.md Known
        /// Limitations), so these have no effect on transactional behavior.
        var minHistory: Int = 0
        var maxHistory: Int = 10
    }

    private let state: Mutex<State>

    var value: Expr {
        state.withLock { $0.value }
    }
    var version: Int {
        state.withLock { $0.version }
    }
    var metadata: [Expr: Expr]? {
        get { state.withLock { $0.metadata } }
        set { state.withLock { $0.metadata = newValue } }
    }
    var validator: Expr? {
        get { state.withLock { $0.validator } }
        set { state.withLock { $0.validator = newValue } }
    }
    /// Snapshot of the current watches. Safe to iterate without holding the lock.
    var watches: [Expr: Expr] {
        state.withLock { $0.watches }
    }
    var minHistory: Int {
        get { state.withLock { $0.minHistory } }
        set { state.withLock { $0.minHistory = newValue } }
    }
    var maxHistory: Int {
        get { state.withLock { $0.maxHistory } }
        set { state.withLock { $0.maxHistory = newValue } }
    }

    init(_ value: Expr, metadata: [Expr: Expr]? = nil, validator: Expr? = nil) {
        state = Mutex(State(value: value, metadata: metadata, validator: validator))
    }

    /// Atomic read of (value, version) together, so a transaction's first touch
    /// of this ref never sees a torn value/version pair.
    func snapshot() -> (value: Expr, version: Int) {
        state.withLock { ($0.value, $0.version) }
    }

    /// The only mutator of a ref's value/version. Called only while holding the
    /// STM commit lock, only after commit-time verification has already confirmed
    /// `expected` matches for every ref touched by the committing transaction.
    func commitIfVersion(_ expected: Int, newValue: Expr) -> Bool {
        state.withLock { s in
            guard s.version == expected else { return false }
            s.value = newValue
            s.version += 1
            return true
        }
    }

}

extension SwishRef: Watchable {
    func mutateWatches(_ body: (inout [Expr: Expr]) -> Void) {
        state.withLock { body(&$0.watches) }
    }
}

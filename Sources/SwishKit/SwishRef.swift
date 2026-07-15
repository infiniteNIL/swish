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

    func addWatch(key: Expr, fn: Expr) {
        state.withLock { $0.watches[key] = fn }
    }

    func removeWatch(key: Expr) {
        state.withLock { _ = $0.watches.removeValue(forKey: key) }
    }
}

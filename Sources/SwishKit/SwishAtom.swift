import Synchronization

/// A Swish atom — a thread-safe mutable reference to a value.
public final class SwishAtom: @unchecked Sendable {
    private struct State {
        var value: Expr
        var metadata: [Expr: Expr]?
        var validator: Expr?
        var watches: [Expr: Expr] = [:]
    }

    private let state: Mutex<State>

    var value: Expr {
        get { state.withLock { $0.value } }
        set { state.withLock { $0.value = newValue } }
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

    /// Atomically replaces `value` with `newValue` if it currently equals `expected`.
    /// Returns whether the swap succeeded, so callers can retry on failure.
    func compareAndSet(expected: Expr, newValue: Expr) -> Bool {
        state.withLock { s in
            guard s.value == expected else { return false }
            s.value = newValue
            return true
        }
    }

    /// Atomically replaces `value` with `newValue`, returning the value it held immediately before.
    @discardableResult
    func getAndSet(_ newValue: Expr) -> Expr {
        state.withLock { s in
            let old = s.value
            s.value = newValue
            return old
        }
    }

    func addWatch(key: Expr, fn: Expr) {
        state.withLock { $0.watches[key] = fn }
    }

    func removeWatch(key: Expr) {
        state.withLock { _ = $0.watches.removeValue(forKey: key) }
    }
}

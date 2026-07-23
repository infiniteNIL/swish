import Synchronization

/// A Swish var — an interned, named reference to a value
public final class Var: @unchecked Sendable {
    public let name: String
    /// Safe as `unowned` only because `Namespace`s live for the process's
    /// entire lifetime today — there is no namespace-removal API anywhere in
    /// the codebase. Revisit (e.g. `unowned(unsafe)` → `weak` with explicit
    /// nil-handling) if namespace unloading is ever added.
    public unowned let namespace: Namespace

    private struct State {
        var value: Expr?
        var metadata: [Expr: Expr]?
        var isSystem: Bool = false
        var isDynamic: Bool = false
        var watches: [Expr: Expr] = [:]
    }

    private let state: Mutex<State>

    public var value: Expr? {
        get { state.withLock { $0.value } }
        set { state.withLock { $0.value = newValue } }
    }
    public var metadata: [Expr: Expr]? {
        get { state.withLock { $0.metadata } }
        set { state.withLock { $0.metadata = newValue } }
    }
    public var isSystem: Bool {
        get { state.withLock { $0.isSystem } }
        set { state.withLock { $0.isSystem = newValue } }
    }
    public var isDynamic: Bool {
        get { state.withLock { $0.isDynamic } }
        set { state.withLock { $0.isDynamic = newValue } }
    }
    /// Snapshot of the current watches. Safe to iterate without holding the lock.
    public var watches: [Expr: Expr] {
        state.withLock { $0.watches }
    }

    /// Reads `isDynamic` and `value` in a single lock acquisition instead of two —
    /// used by `Evaluator.dynamicValue(of:)`, the hot path for every global-symbol
    /// dereference.
    func snapshotIsDynamicAndValue() -> (isDynamic: Bool, value: Expr?) {
        state.withLock { ($0.isDynamic, $0.value) }
    }

    public init(name: String, namespace: Namespace, value: Expr? = nil) {
        self.name = name
        self.namespace = namespace
        state = Mutex(State(value: value))
    }

    public var isBound: Bool { value != nil }

    /// Atomically replaces `value` with `newValue` if it currently equals `expected`.
    /// Returns whether the swap succeeded, so callers can retry on failure.
    func compareAndSetValue(expected: Expr?, newValue: Expr?) -> Bool {
        state.withLock { s in
            guard s.value == expected else { return false }
            s.value = newValue
            return true
        }
    }

    /// Atomically replaces `metadata` with `newValue` if it currently equals `expected`.
    func compareAndSetMetadata(expected: [Expr: Expr]?, newValue: [Expr: Expr]?) -> Bool {
        state.withLock { s in
            guard s.metadata == expected else { return false }
            s.metadata = newValue
            return true
        }
    }

    /// Atomically replaces `metadata` with `newValue`, returning the value it held immediately before.
    @discardableResult
    func getAndSetMetadata(_ newValue: [Expr: Expr]?) -> [Expr: Expr]? {
        state.withLock { s in
            let old = s.metadata
            s.metadata = newValue
            return old
        }
    }

}

extension Var: Watchable {
    func mutateWatches(_ body: (inout [Expr: Expr]) -> Void) {
        state.withLock { body(&$0.watches) }
    }
}

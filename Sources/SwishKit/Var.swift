import Synchronization

/// A Swish var — an interned, named reference to a value
public final class Var: @unchecked Sendable {
    public let name: String
    /// `unowned` to break the `Namespace`↔`Var` retain cycle (a `Namespace` strongly
    /// holds its `Var`s via `mappings`). Safe for vars of live namespaces. But
    /// `remove-ns` can now remove a namespace from the registry: a `.varRef` to one
    /// of its vars that outlives the namespace leaves this reference dangling, and
    /// reading `namespace` then traps. That is a deliberate, documented risk — it
    /// matches Clojure's stance that removing a namespace whose vars you still hold is
    /// your problem (the JVM tolerates it; Swift crashes). Revisit (`weak` + explicit
    /// nil-handling, or a strong ref accepting that removed namespaces then leak) only
    /// if that footgun proves to matter in practice.
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

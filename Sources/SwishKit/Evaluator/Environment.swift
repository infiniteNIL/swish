/// Stores variable bindings for the evaluator — one lexical scope, with a link
/// to its enclosing scope.
///
/// Deliberately lock-free (`@unchecked Sendable` with a plain dictionary). The
/// invariant that makes this safe: every `Environment` is written only during its
/// setup phase, on the single thread that created it, *before* any closure can
/// capture it and escape to another thread. A closure escapes only when the body
/// runs (agent/future dispatch), and that dispatch provides the happens-before
/// memory barrier publishing the setup writes; after setup the env is read-only,
/// and concurrent reads of an unmutated dictionary are safe. `let`/`fn`/`letfn`
/// bindings and `fn` recur (a fresh env per iteration) already obeyed this;
/// `loop`/`recur` now does too (fresh env per iteration — see `evalLoop`), so
/// there is no post-setup mutation anywhere for a lock to guard against. This
/// replaced a blanket per-level `Mutex` (added defensively in the thread-safety
/// retrofit, not to fix an observed race) that cost a lock/unlock at every scope
/// level on every variable lookup — see CLAUDE.md.
public class Environment: @unchecked Sendable {
    private var bindings: [String: Expr] = [:]
    private let parent: Environment?

    public init(parent: Environment? = nil) {
        self.parent = parent
    }

    public func get(_ name: String) -> Expr? {
        bindings[name] ?? parent?.get(name)
    }

    public func set(_ name: String, _ value: Expr) {
        bindings[name] = value
    }

    /// Returns all names bound at any level of the environment chain.
    public func allNames() -> Set<String> {
        var names = Set(bindings.keys)
        if let p = parent { names.formUnion(p.allNames()) }
        return names
    }
}

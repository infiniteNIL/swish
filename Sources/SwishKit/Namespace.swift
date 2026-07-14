import Synchronization

/// A Swish namespace — a named container of interned Vars and refers
public final class Namespace: @unchecked Sendable {
    public let name: String

    private struct State {
        var mappings: [String: Var] = [:]
        var aliases: [String: Namespace] = [:]
        var metadata: [Expr: Expr]? = nil
    }
    private let state = Mutex(State())

    /// Snapshot of the current mappings. Dictionaries are value types (copy-on-write),
    /// so this is a safe, cheap point-in-time copy — callers that iterate it
    /// (e.g. auto-refer loops) don't hold the namespace's lock while doing so.
    public var mappings: [String: Var] { state.withLock { $0.mappings } }
    /// Snapshot of the current aliases, same rationale as `mappings`.
    public var aliases: [String: Namespace] { state.withLock { $0.aliases } }
    public var metadata: [Expr: Expr]? {
        get { state.withLock { $0.metadata } }
        set { state.withLock { $0.metadata = newValue } }
    }

    public init(name: String) {
        self.name = name
    }

    /// Returns the home Var for `name`, creating it if it doesn't exist.
    /// If a home Var already exists, updates its value (if provided) and returns it.
    /// A home Var is one whose namespace is this namespace.
    @discardableResult
    public func intern(name: String, value: Expr? = nil) -> Var {
        // The find-or-create decision must be one atomic step: two concurrent
        // interns of the same not-yet-existing name could otherwise both see
        // "absent," both create a Var, and the loser's insert would be lost.
        let (v, isNew) = state.withLock { s -> (Var, Bool) in
            if let existing = s.mappings[name], existing.namespace === self {
                return (existing, false)
            }
            let newVar = Var(name: name, namespace: self, value: value)
            s.mappings[name] = newVar
            return (newVar, true)
        }
        // Applied after releasing this namespace's lock, via the Var's own lock —
        // never nest Namespace's lock inside Var's lock or vice versa.
        if !isNew, let val = value {
            v.value = val
        }
        return v
    }

    /// Adds a reference to a Var from another namespace under its short name.
    /// Idempotent for the same Var. Throws if a different Var already occupies that name.
    public func refer(_ v: Var) throws {
        try state.withLock { s in
            if let existing = s.mappings[v.name], existing !== v {
                throw NamespaceError.referConflict(
                    name: v.name,
                    existing: "\(existing.namespace.name)/\(existing.name)",
                    new: "\(v.namespace.name)/\(v.name)")
            }
            s.mappings[v.name] = v
        }
    }

    public func findVar(name: String) -> Var? {
        state.withLock { $0.mappings[name] }
    }

    /// Maps `name` to `ns` as a local alias. Idempotent for the same namespace.
    /// Throws if a different namespace already occupies that alias.
    public func alias(name: String, ns: Namespace) throws {
        try state.withLock { s in
            if let existing = s.aliases[name], existing !== ns {
                throw NamespaceError.aliasConflict(
                    name: name,
                    existing: existing.name,
                    new: ns.name)
            }
            s.aliases[name] = ns
        }
    }

    public func findAlias(_ name: String) -> Namespace? {
        state.withLock { $0.aliases[name] }
    }
}

extension Namespace {
    /// Interns `value` under `name` and sets `:doc` / `:arglists` metadata,
    /// using the same `[[String]]` arglists format as `Evaluator.register()`.
    @discardableResult
    func register(name: String, value: Expr, doc: String, arglists: [[String]]) -> Var {
        let v = intern(name: name, value: value)
        v.metadata = [
            .keyword("doc"): .string(doc),
            .keyword("arglists"): .list(arglists.map { params in
                .vector(params.map { .symbol($0, metadata: nil) }, metadata: nil)
            }, metadata: nil),
        ]
        return v
    }
}

extension Evaluator {

    // MARK: - Namespace registry

    public func findNs(_ name: String) -> Namespace? {
        namespacesState.withLock { $0[name] }
    }

    public func findOrCreateNs(_ name: String) -> Namespace {
        // Insert *and* the auto-refer-from-clojure.core loop happen inside one
        // lock acquisition, so a concurrent findNs can never observe a namespace
        // before it's fully populated. Safe from deadlock: this only ever nests
        // Evaluator.namespaces's lock -> some other Namespace's own lock (via
        // ns.refer/core.mappings below), never the reverse order.
        namespacesState.withLock { s -> Namespace in
            if let existing = s[name] {
                return existing
            }
            let ns = Namespace(name: name)
            s[name] = ns
            if name != "clojure.core", let core = s["clojure.core"] {
                for (_, v) in core.mappings {
                    try? ns.refer(v)
                }
            }
            return ns
        }
    }

    // MARK: - Current namespace

    func currentNs() -> Namespace {
        let nsVar = findNs("clojure.core")!.findVar(name: "*ns*")!
        guard case .namespace(let ns) = nsVar.value else {
            fatalError("*ns* corrupted — expected .namespace, got \(String(describing: nsVar.value))")
        }
        return ns
    }

    public var currentNamespaceName: String {
        currentNs().name
    }

    // *ns* is a normal Var (never marked `isDynamic`), so it's read/written via its
    // root `.value` here rather than through `bindingFrames`. The Var-level lock
    // (see Var.swift) makes concurrent access to *ns* data-race-*safe*, but this is
    // NOT semantically per-thread-*correct*: two future threads calling `in-ns`
    // would still share one root value and stomp on each other's "current
    // namespace." Making *ns* genuinely dynamic + thread-local is deferred to
    // whichever later step first introduces real background execution.
    func setCurrentNs(_ ns: Namespace) {
        findNs("clojure.core")!.findVar(name: "*ns*")!.value = .namespace(ns)
    }

    // MARK: - Symbol resolution helpers

    /// Looks up an unqualified name in `ns`, falling through to clojure.core if not found there.
    func resolveVar(name: String, in ns: Namespace) -> Var? {
        ns.findVar(name: name)
            ?? (ns.name != "clojure.core" ? findNs("clojure.core")?.findVar(name: name) : nil)
    }

    /// Splits `ns/name` into its two parts. Returns nil for unqualified symbols or the bare "/" symbol.
    func splitQualified(_ name: String) -> (ns: String, member: String)? {
        guard name.contains("/"), name != "/" else { return nil }
        let idx = name.firstIndex(of: "/")!
        return (String(name[name.startIndex..<idx]), String(name[name.index(after: idx)...]))
    }

    /// Splits a qualified `ns/name` symbol and resolves it to a Var.
    /// Returns nil if the symbol is not qualified (no slash, or the bare "/" symbol).
    /// Throws undefinedSymbol if the namespace or var is not found.
    ///
    /// Cached under `name` (the full "ns/shortname" string) once resolved, but only
    /// when both of these hold — violating either would be a real correctness bug:
    ///   1. Resolution went through the literal-namespace-name branch (`findNs`), not
    ///      the alias branch (`currentNs().findAlias`) — an alias like `str` can mean
    ///      a different namespace depending on the *caller's* current namespace, so
    ///      caching an alias-based resolution under its bare alias text would leak
    ///      one caller's meaning of `str/...` into every other caller's.
    ///   2. The resolved Var's home namespace is the namespace that was searched
    ///      (`v.namespace === ns`) — a *referred* (non-home) var can later be shadowed
    ///      by a local `def` in that namespace (`Namespace.intern` creates a genuinely
    ///      new Var for that case), so a referred-var resolution must never be cached.
    /// No cache invalidation is needed for what *is* cached: `Namespace.intern` always
    /// reuses the existing Var object (never a new one) for an already-home mapping,
    /// `Namespace.refer` throws rather than silently replacing a differing Var, and
    /// there is no `ns-unmap`/`remove-ns`/any other API to delete a mapping — a home
    /// resolution, once cached, can never go stale.
    func resolveQualifiedVar(name: String) throws -> Var? {
        if let cached = qualifiedVarCache.withLock({ $0[name] }) {
            return cached
        }
        guard let (nsAlias, shortName) = splitQualified(name) else { return nil }

        let ns: Namespace
        let viaLiteralName: Bool
        if let aliased = currentNs().findAlias(nsAlias) {
            ns = aliased
            viaLiteralName = false
        } else if let literal = findNs(nsAlias) {
            ns = literal
            viaLiteralName = true
        } else {
            throw EvaluatorError.undefinedSymbol(name)
        }

        guard let v = ns.findVar(name: shortName) else { throw EvaluatorError.undefinedSymbol(name) }

        if viaLiteralName && v.namespace === ns {
            qualifiedVarCache.withLock { $0[name] = v }
        }

        return v
    }

    // MARK: - Native function registration

    /// Registers a native Swift function in the clojure.core namespace.
    public func register(
        name: String,
        arity: Arity,
        doc: String? = nil,
        arglists: [[String]]? = nil,
        body: @escaping @Sendable ([Expr]) throws -> Expr
    ) {
        let v = findNs("clojure.core")!.intern(name: name, value: .nativeFunction(name: name, arity: arity, body: body))
        var meta: [Expr: Expr] = [:]
        if let doc { meta[.keyword("doc")] = .string(doc) }
        if let arglists {
            meta[.keyword("arglists")] = .list(SwishPersistentList(arglists.map { params in
                .vector(params.map { .symbol($0, metadata: nil) }, metadata: nil)
            }), metadata: nil)
        }
        if !meta.isEmpty { v.metadata = meta }
    }
}

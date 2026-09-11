extension Evaluator {

    // MARK: - Namespace registry

    func findNs(_ name: String) -> Namespace? {
        namespacesState.withLock { $0[name] }
    }

    /// Returns the namespace named `name`, creating it **bare** (no auto-refer) if
    /// absent — matching Clojure, where `in-ns`/`create-ns` produce namespaces with
    /// clojure.core *not* referred. The default core refer is applied by the `ns`
    /// form (`evalNs` → `referClojureCore`) and by init for the `user` ns, never here.
    func findOrCreateNs(_ name: String) -> Namespace {
        namespacesState.withLock { s -> Namespace in
            if let existing = s[name] {
                return existing
            }
            let ns = Namespace(name: name)
            s[name] = ns
            return ns
        }
    }

    /// Refers clojure.core's vars into `ns` — the default namespace refer, relocated
    /// out of namespace creation into the `ns` form and init (so `in-ns`/`create-ns`
    /// stay bare like Clojure). `only`/`exclude` come from a `:refer-clojure`
    /// directive (nil `only` = refer all). clojure.core itself is skipped.
    func referClojureCore(into ns: Namespace, only: Set<String>? = nil, exclude: Set<String> = []) {
        guard ns.name != "clojure.core", let core = findNs("clojure.core") else { return }
        // Recorded so a *later* `register` can back-fill the new var into this
        // namespace — the refer below is a point-in-time copy of core's mappings,
        // and a host that registers after loading its Swish source would otherwise
        // find the name unresolvable. See `register(name:in:...)`.
        ns.recordCoreReferral(only: only, exclude: exclude)
        for (name, v) in core.mappings {
            if exclude.contains(name) {
                continue
            }
            if let only, !only.contains(name) {
                continue
            }
            ns.refer(v)
        }
    }

    /// Removes the namespace `name` from the registry and clears its cached
    /// qualified-var resolutions (`"<name>/…"` keys). Backs `remove-ns` (which
    /// guards `clojure.core`). WARNING: a `.varRef` to one of the removed
    /// namespace's vars that outlives it will dangle — `Var.namespace` is
    /// `unowned` — and reading it then traps. A deliberate, documented risk
    /// (matches Clojure's "removing a ns whose vars you still hold is your
    /// problem", except Swift crashes where the JVM tolerates). See `Var.swift`.
    func removeNs(_ name: String) {
        namespacesState.withLock { $0[name] = nil }
        let prefix = "\(name)/"
        qualifiedVarCache.withLock { cache in
            cache = cache.filter { !$0.key.hasPrefix(prefix) }
        }
    }

    // MARK: - Current namespace

    func currentNs() -> Namespace {
        guard case .namespace(let ns) = starNsVar.value else {
            fatalError("*ns* corrupted — expected .namespace, got \(String(describing: starNsVar.value))")
        }
        return ns
    }

    var currentNamespaceName: String {
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
        starNsVar.value = .namespace(ns)
    }

    // MARK: - Symbol resolution helpers

    /// Looks up an unqualified name in `ns`'s own mappings only — no implicit
    /// clojure.core fallback. Core is available because it's *referred* (by the `ns`
    /// form / init for `user`), so a referred namespace finds a core var here; a
    /// **bare** `in-ns`/`create-ns` namespace does not, matching Clojure (unqualified
    /// core names don't resolve until referred). clojure.core finds its own home vars.
    func resolveVar(name: String, in ns: Namespace) -> Var? {
        ns.findVar(name: name)
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
    /// A cached home resolution can only go stale if its mapping is *deleted*, and the
    /// two APIs that delete mappings invalidate it explicitly: `ns-unmap` (`coreNsUnmap`)
    /// removes the single `"<ns>/<name>"` key, and `remove-ns` (`Evaluator.removeNs`)
    /// prefix-clears every `"<ns>/…"` key. Nothing else can stale it: `Namespace.intern`
    /// reuses the existing Var object for an already-home mapping, and `Namespace.refer`
    /// never replaces a home var (its `checkReplacement` keeps it).
    func resolveQualifiedVar(name: String) throws -> Var? {
        // Split first, cache second. Every cache key contains a "/", so an unqualified
        // name can never hit — and unqualified is the overwhelmingly common case on the
        // eval hot path (every bare global reference lands here). Probing the cache
        // first cost all of them a `Mutex` acquisition plus a `String` hash to learn
        // nothing.
        guard let (nsAlias, shortName) = splitQualified(name) else { return nil }
        if let cached = qualifiedVarCache.withLock({ $0[name] }) {
            return cached
        }

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

    /// Registers a native Swift function, by default in the clojure.core namespace.
    ///
    /// Passing `namespace` targets another namespace instead, creating it if
    /// absent — host registrations that should not sit in core go there, and are
    /// called qualified (`(app/thing …)`).
    func register(
        name: String,
        arity: Arity,
        in namespace: String? = nil,
        doc: String? = nil,
        arglists: [[String]]? = nil,
        body: @escaping @Sendable ([Expr]) throws -> Expr
    ) {
        let target = namespace.map { findOrCreateNs($0) } ?? findNs("clojure.core")!
        let v = target.intern(name: name, value: .nativeFunction(name: name, arity: arity, body: body))
        if target.name == "clojure.core" {
            backFillReferral(of: v, named: name)
        }
        var meta: [Expr: Expr] = [:]
        if let doc { meta[.keyword("doc")] = .string(doc) }
        if let arglists {
            meta[.keyword("arglists")] = .list(SwishPersistentList(arglists.map { params in
                .vector(SwishPersistentVector(params.map { .symbol($0, metadata: nil) }), metadata: nil)
            }), metadata: nil)
        }
        if !meta.isEmpty { v.metadata = meta }
    }

    /// Refers a freshly-interned clojure.core var into every namespace that has
    /// already referred core in.
    ///
    /// `referClojureCore` copies core's mappings at `ns`-form time, and
    /// `resolveVar` has no core fallback, so without this a host function
    /// registered after its Swish source was loaded would be invisible as a bare
    /// name. Costs nothing during bootstrap, where clojure.core is the only
    /// namespace and this loop is empty.
    ///
    /// A conflict message from `refer` is deliberately discarded rather than
    /// written to `*err*`: `refer` already declines to replace a namespace's own
    /// interned var, which is the behavior we want (a namespace that defined its
    /// own `get-vowels` keeps it), and back-filling is a background fix-up the
    /// host never asked about.
    func backFillReferral(of v: Var, named name: String) {
        for ns in namespacesState.withLock({ Array($0.values) }) {
            guard ns.name != "clojure.core",
                  let referral = ns.coreReferral,
                  referral.admits(name)
            else {
                continue
            }
            _ = ns.refer(v)
        }
    }
}

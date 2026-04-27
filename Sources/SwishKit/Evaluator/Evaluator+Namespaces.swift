extension Evaluator {

    // MARK: - Namespace registry

    public func findNs(_ name: String) -> Namespace? {
        namespaces[name]
    }

    public func findOrCreateNs(_ name: String) -> Namespace {
        if let existing = namespaces[name] {
            return existing
        }
        let ns = Namespace(name: name)
        namespaces[name] = ns
        if name != "clojure.core", let core = findNs("clojure.core") {
            for (_, v) in core.mappings {
                try! ns.refer(v)
            }
        }
        return ns
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

    func setCurrentNs(_ ns: Namespace) {
        findNs("clojure.core")!.findVar(name: "*ns*")!.value = .namespace(ns)
    }

    // MARK: - Symbol resolution helpers

    /// Looks up an unqualified name in `ns`, falling through to clojure.core if not found there.
    func resolveVar(name: String, in ns: Namespace) -> Var? {
        ns.findVar(name: name)
            ?? (ns.name != "clojure.core" ? findNs("clojure.core")?.findVar(name: name) : nil)
    }

    /// Splits a qualified `ns/name` symbol and resolves it to a Var.
    /// Returns nil if the symbol is not qualified (no slash, or the bare "/" symbol).
    /// Throws undefinedSymbol if the namespace or var is not found.
    func resolveQualifiedVar(name: String) throws -> Var? {
        guard name.contains("/"), name != "/" else { return nil }
        let slashIdx = name.firstIndex(of: "/")!
        let nsAlias = String(name[name.startIndex..<slashIdx])
        let shortName = String(name[name.index(after: slashIdx)...])
        guard let ns = findNs(nsAlias) else { throw EvaluatorError.undefinedSymbol(name) }
        guard let v = ns.findVar(name: shortName) else { throw EvaluatorError.undefinedSymbol(name) }
        return v
    }

    // MARK: - Native function registration

    /// Registers a native Swift function in the clojure.core namespace.
    public func register(name: String, arity: Arity, body: @escaping @Sendable ([Expr]) throws -> Expr) {
        findNs("clojure.core")!.intern(name: name, value: .nativeFunction(name: name, arity: arity, body: body))
    }
}

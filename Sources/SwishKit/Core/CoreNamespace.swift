// MARK: - Registration

func registerNamespace(into evaluator: Evaluator) {
    evaluator.register(name: "create-ns", arity: .fixed(1),
        doc: "Create a new namespace named by the symbol if one doesn't already exist, returns it or the already-existing namespace of the same name.",
        arglists: [["sym"]]) { [evaluator] args in try coreCreateNs(evaluator, args) }
    evaluator.register(name: "find-ns", arity: .fixed(1),
        doc: "Returns the namespace named by the symbol or nil if it doesn't exist.",
        arglists: [["sym"]]) { [evaluator] args in try coreFindNs(evaluator, args) }
    evaluator.register(name: "in-ns", arity: .fixed(1),
        doc: "Sets *ns* to the namespace named by the symbol, creating it if needed.",
        arglists: [["name"]]) { [evaluator] args in try coreInNs(evaluator, args) }
    evaluator.register(name: "require", arity: .atLeastOne,
        doc: "Loads libs, skipping any that are already loaded. Each argument is a libspec that identifies a lib, its load options and its loading environment.",
        arglists: [["&", "args"]]) { [evaluator] args in try coreRequire(evaluator, args) }
    evaluator.register(name: "alias", arity: .fixed(2),
        doc: "Add an alias in the current namespace to another namespace. Arguments are two symbols: the alias and the namespace name.",
        arglists: [["alias", "namespace-sym"]]) { [evaluator] args in try coreAlias(evaluator, args) }
    evaluator.register(name: "refer", arity: .atLeastOne,
        doc: "refers to all public vars of ns, subject to filters. filters can include at most one each of: :exclude list-of-symbols, :only list-of-symbols, :rename map-of-fromsym-tosym",
        arglists: [["ns-sym", "&", "filters"]]) { [evaluator] args in try coreRefer(evaluator, args) }
    evaluator.register(name: "resolve", arity: .variadic,
        doc: "Returns the var or Class to which a symbol will be resolved in the current namespace (unless found in the environment), else nil.",
        arglists: [["sym"], ["env", "sym"]]) { [evaluator] args in try coreResolve(evaluator, args) }
    evaluator.register(name: "ns-resolve", arity: .variadic,
        doc: "Returns the var to which a symbol will be resolved in the namespace (unless found in the environment), else nil. Note that if the symbol is fully qualified, the var/Class to which it resolves need not be present in the namespace.",
        arglists: [["ns", "sym"], ["ns", "env", "sym"]]) { [evaluator] args in try coreNsResolve(evaluator, args) }
    evaluator.register(name: "ns-interns", arity: .fixed(1),
        doc: "Returns a map of the intern mappings for the namespace.",
        arglists: [["ns"]]) { [evaluator] args in try coreNsInterns(evaluator, args) }
    evaluator.register(name: "all-ns", arity: .fixed(0),
        doc: "Returns a sequence of all namespaces.",
        arglists: [[]]) { [evaluator] _ in coreAllNs(evaluator) }
    evaluator.register(name: "ns-name", arity: .fixed(1),
        doc: "Returns the name of the namespace, a Symbol.",
        arglists: [["ns"]]) { args in try coreNsName(args) }
    evaluator.register(name: "the-ns", arity: .fixed(1),
        doc: "If passed a namespace, returns it. Else, when passed a symbol, returns the namespace named by it, throwing an exception if not found.",
        arglists: [["x"]]) { [evaluator] args in try coreTheNs(evaluator, args) }
    evaluator.register(name: "intern", arity: .variadic,
        doc: "Finds or creates a var named by the symbol name in the namespace ns (which can be a symbol or a namespace), setting its root binding to val if supplied. The namespace must exist. The var will adopt any metadata from the name symbol. Returns the var.",
        arglists: [["ns", "name"], ["ns", "name", "val"]]) { [evaluator] args in try coreIntern(evaluator, args) }
    evaluator.register(name: "symbol", arity: .variadic,
        doc: "Returns a Symbol with the given namespace and name. Arity-1 coerces string to symbol.",
        arglists: [["name"], ["ns", "name"]]) { args in try coreSymbol(args) }
    evaluator.register(name: "ns-map", arity: .fixed(1),
        doc: "Returns a map of all the mappings for the namespace.",
        arglists: [["ns"]]) { [evaluator] args in try coreNsMap(evaluator, args) }
    evaluator.register(name: "ns-publics", arity: .fixed(1),
        doc: "Returns a map of the public intern mappings for the namespace.",
        arglists: [["ns"]]) { [evaluator] args in try coreNsPublics(evaluator, args) }
    evaluator.register(name: "ns-refers", arity: .fixed(1),
        doc: "Returns a map of the refer mappings for the namespace.",
        arglists: [["ns"]]) { [evaluator] args in try coreNsRefers(evaluator, args) }
    evaluator.register(name: "ns-aliases", arity: .fixed(1),
        doc: "Returns a map of the aliases for the namespace.",
        arglists: [["ns"]]) { [evaluator] args in try coreNsAliases(evaluator, args) }
    evaluator.register(name: "ns-imports", arity: .fixed(1),
        doc: "Returns a map of the import mappings for the namespace.",
        arglists: [["ns"]]) { [evaluator] args in try coreNsImports(evaluator, args) }
    evaluator.register(name: "ns-unalias", arity: .fixed(2),
        doc: "Removes the alias for the symbol from the namespace.",
        arglists: [["ns", "sym"]]) { [evaluator] args in try coreNsUnalias(evaluator, args) }
    evaluator.register(name: "ns-unmap", arity: .fixed(2),
        doc: "Removes the mappings for the symbol from the namespace.",
        arglists: [["ns", "sym"]]) { [evaluator] args in try coreNsUnmap(evaluator, args) }
    evaluator.register(name: "loaded-libs", arity: .fixed(0),
        doc: "Returns a sorted set of symbols naming the currently loaded libs.",
        arglists: [[]]) { [evaluator] _ in try coreLoadedLibs(evaluator) }
    evaluator.register(name: "remove-ns", arity: .fixed(1),
        doc: "Removes the namespace named by the symbol. Use with caution. Cannot be used to remove the clojure.core namespace.",
        arglists: [["sym"]]) { [evaluator] args in try coreRemoveNs(evaluator, args) }
}

// MARK: - Helpers

/// This namespace's house style for a bad symbol argument. Distinct from
/// `requireSymbol`'s bare default ("argument must be a symbol") — the `ns-*` fns have
/// always reported the offending value, and tests read these messages.
private func expectSymbol(_ expr: Expr, function: String) throws -> String {
    try requireSymbol(expr, function: function,
        message: "expected a symbol, got \(corePrinter.printString(expr))")
}

// MARK: - Implementations

private func coreFindNs(_ evaluator: Evaluator, _ args: [Expr]) throws -> Expr {
    let name = try expectSymbol(args[0], function: "find-ns")
    guard let ns = evaluator.findNs(name) else { return .nil }
    return .namespace(ns)
}

private func coreCreateNs(_ evaluator: Evaluator, _ args: [Expr]) throws -> Expr {
    let name = try expectSymbol(args[0], function: "create-ns")
    return .namespace(evaluator.findOrCreateNs(name))
}

private func coreInNs(_ evaluator: Evaluator, _ args: [Expr]) throws -> Expr {
    let name = try expectSymbol(args[0], function: "in-ns")
    let ns = evaluator.findOrCreateNs(name)
    evaluator.setCurrentNs(ns)
    return .namespace(ns)
}

private func coreRequire(_ evaluator: Evaluator, _ args: [Expr]) throws -> Expr {
    try evaluator.processRequireDirective(args, caller: "require")
    return .nil
}

private func coreAlias(_ evaluator: Evaluator, _ args: [Expr]) throws -> Expr {
    let aliasName = try requireSymbol(args[0], function: "alias",
        message: "first argument must be a symbol, got \(args[0])")
    let nsName = try requireSymbol(args[1], function: "alias",
        message: "second argument must be a symbol, got \(args[1])")
    guard let ns = evaluator.findNs(nsName) else {
        throw EvaluatorError.namespaceNotFound(nsName)
    }
    try evaluator.currentNs().alias(name: aliasName, ns: ns)
    return .nil
}

private func coreRefer(_ evaluator: Evaluator, _ args: [Expr]) throws -> Expr {
    let nsName = try requireSymbol(args[0], function: "refer",
        message: "first argument must be a symbol, got \(args[0])")
    guard let srcNs = evaluator.findNs(nsName) else {
        throw EvaluatorError.namespaceNotFound(nsName)
    }
    var only: Set<String>?
    var exclude: Set<String> = []
    var i = 1
    while i + 1 < args.count {
        guard case .keyword(let key) = args[i] else {
            i += 1
            continue
        }
        switch key {
        case "only":
            if case .vector(let syms, _) = args[i + 1] {
                only = Set(syms.compactMap { if case .symbol(let s, _) = $0 { s } else { nil } })
            }

        case "exclude":
            if case .vector(let syms, _) = args[i + 1] {
                exclude = Set(syms.compactMap { if case .symbol(let s, _) = $0 { s } else { nil } })
            }

        default:
            break
        }
        i += 2
    }
    let currentNs = evaluator.currentNs()
    for (varName, v) in srcNs.mappings where v.namespace === srcNs {
        let shouldRefer: Bool
        if let only {
            shouldRefer = only.contains(varName)
        }
        else {
            shouldRefer = !exclude.contains(varName)
        }
        if shouldRefer, let msg = currentNs.refer(v) {
            evaluator.writeErr(msg + "\n")
        }
    }
    return .nil
}

/// True when `env` — a local-binding map, as passed to the `env`-taking arities of
/// `resolve`/`ns-resolve` — binds `sym`, which real Clojure treats as shadowing any
/// var of that name. Anything that isn't a map (including `nil`, the value real
/// Clojure's 2-arity `ns-resolve` forwards) shadows nothing.
private func envShadows(_ env: Expr, _ sym: Expr) -> Bool {
    switch env {
    case .map(let sm):
        return sm.dict[sym] != nil

    case .sortedMap(let ssm):
        return ssm.keys.contains(sym)

    default:
        return false
    }
}

private func coreResolve(_ evaluator: Evaluator, _ args: [Expr]) throws -> Expr {
    // (resolve sym) or (resolve env sym) — the symbol is always the last arg.
    try requireArgCount(args, in: 1...2, function: "resolve")
    let symArg = args[args.count - 1]
    guard case .symbol(let name, _) = symArg else { return .nil }
    if args.count == 2, envShadows(args[0], symArg) {
        return .nil
    }
    if let v = try? evaluator.resolveQualifiedVar(name: name) { return .varRef(v) }
    if let v = evaluator.resolveVar(name: name, in: evaluator.currentNs()) { return .varRef(v) }
    // Special forms (let, if, deftype, ...) are hardcoded symbol matches in
    // evalList's switch, never interned as vars — without this, (resolve 'let)
    // etc. would incorrectly report "doesn't exist" even though they work.
    // Returns a sentinel, not a var: nothing is interned, so bare-symbol
    // evaluation of these names (which never goes through resolve) is
    // unaffected and still throws exactly as it does today.
    //
    // Note this reads Evaluator.specialFormNames, NOT the native special-symbol?
    // (CorePredicates.swift), whose set is deliberately different — it lists the
    // JVM-Clojure special symbols (let*, fn*, new, ., &, …) while this lists the
    // forms evalSpecialForm actually implements (let, fn, ns, reify, …).
    if Evaluator.specialFormNames.contains(name) { return .keyword("special-form") }
    return .nil
}

private func coreNsResolve(_ evaluator: Evaluator, _ args: [Expr]) throws -> Expr {
    // (ns-resolve ns sym) or (ns-resolve ns env sym), where env is a local-binding
    // map that shadows same-named vars. The symbol is always the last arg.
    try requireArgCount(args, in: 2...3, function: "ns-resolve")
    let symArg = args[args.count - 1]
    let name = try requireSymbol(symArg, function: "ns-resolve",
        message: "last argument must be a symbol, got \(corePrinter.printString(symArg))")
    if args.count == 3, envShadows(args[1], symArg) {
        return .nil
    }
    guard case .namespace(let ns) = try coreTheNs(evaluator, [args[0]]) else {
        throw EvaluatorError.invalidArgument(function: "ns-resolve",
            message: "first argument must be a namespace or symbol, got \(corePrinter.printString(args[0]))")
    }
    // A namespace-qualified symbol (ns/name) resolves by its qualified name,
    // independent of the passed ns; an unqualified name resolves within the
    // passed ns (with clojure.core fallback), matching real Clojure.
    if evaluator.splitQualified(name) != nil {
        if let v = try? evaluator.resolveQualifiedVar(name: name) { return .varRef(v) }
        return .nil
    }
    if let v = evaluator.resolveVar(name: name, in: ns) { return .varRef(v) }
    return .nil
}

/// Projects a namespace's mappings to the `{sym varRef}` map every `ns-*` introspection
/// read returns, keeping only the entries `include` accepts. The four readers differ
/// solely in that predicate: `ns-map` takes everything, `ns-interns` and `ns-publics`
/// take home vars (the latter also dropping `:private`), `ns-refers` takes the rest.
private func nsMappingsMap(_ ns: Namespace, include: (Var) -> Bool) -> Expr {
    var result: [Expr: Expr] = [:]
    for (name, v) in ns.mappings where include(v) {
        result[.symbol(name, metadata: nil)] = .varRef(v)
    }
    return .map(result, metadata: nil)
}

private func coreNsInterns(_ evaluator: Evaluator, _ args: [Expr]) throws -> Expr {
    // Unlike the other ns-* readers, a *symbol* naming a namespace that doesn't exist
    // yields {} here rather than throwing — so this keeps its own front end instead of
    // going through `namespaceArg`.
    let ns: Namespace
    switch args[0] {
    case .symbol(let name, _):
        guard let found = evaluator.findNs(name) else { return .map([:], metadata: nil) }
        ns = found

    case .namespace(let n):
        ns = n

    default:
        throw EvaluatorError.invalidArgument(
            function: "ns-interns",
            message: "expected a namespace or symbol, got \(corePrinter.printString(args[0]))")
    }
    return nsMappingsMap(ns) { $0.namespace === ns }
}

/// Resolves a namespace-or-symbol argument to its `Namespace`, throwing for
/// anything else — the shared front-end for the `ns-*` introspection reads.
private func namespaceArg(_ evaluator: Evaluator, _ arg: Expr, function: String) throws -> Namespace {
    guard case .namespace(let ns) = try coreTheNs(evaluator, [arg]) else {
        throw EvaluatorError.invalidArgument(
            function: function,
            message: "expected a namespace or symbol, got \(corePrinter.printString(arg))")
    }
    return ns
}

private func isPrivate(_ v: Var) -> Bool {
    v.metadata?[.keyword("private")] == .boolean(true)
}

private func coreNsMap(_ evaluator: Evaluator, _ args: [Expr]) throws -> Expr {
    let ns = try namespaceArg(evaluator, args[0], function: "ns-map")
    return nsMappingsMap(ns) { _ in true }
}

private func coreNsPublics(_ evaluator: Evaluator, _ args: [Expr]) throws -> Expr {
    let ns = try namespaceArg(evaluator, args[0], function: "ns-publics")
    return nsMappingsMap(ns) { $0.namespace === ns && !isPrivate($0) }
}

private func coreNsRefers(_ evaluator: Evaluator, _ args: [Expr]) throws -> Expr {
    let ns = try namespaceArg(evaluator, args[0], function: "ns-refers")
    return nsMappingsMap(ns) { $0.namespace !== ns }
}

private func coreNsAliases(_ evaluator: Evaluator, _ args: [Expr]) throws -> Expr {
    let ns = try namespaceArg(evaluator, args[0], function: "ns-aliases")
    var result: [Expr: Expr] = [:]
    for (alias, target) in ns.aliases {
        result[.symbol(alias, metadata: nil)] = .namespace(target)
    }
    return .map(result, metadata: nil)
}

private func coreNsImports(_ evaluator: Evaluator, _ args: [Expr]) throws -> Expr {
    // Swish has no host-class system, so a namespace never has import mappings.
    _ = try namespaceArg(evaluator, args[0], function: "ns-imports")
    return .map([:], metadata: nil)
}

private func coreNsUnalias(_ evaluator: Evaluator, _ args: [Expr]) throws -> Expr {
    let ns = try namespaceArg(evaluator, args[0], function: "ns-unalias")
    let aliasName = try requireSymbol(args[1], function: "ns-unalias",
        message: "second argument must be a symbol, got \(corePrinter.printString(args[1]))")
    ns.removeAlias(name: aliasName)
    return .nil
}

private func coreNsUnmap(_ evaluator: Evaluator, _ args: [Expr]) throws -> Expr {
    let ns = try namespaceArg(evaluator, args[0], function: "ns-unmap")
    let symName = try requireSymbol(args[1], function: "ns-unmap",
        message: "second argument must be a symbol, got \(corePrinter.printString(args[1]))")
    ns.unmap(name: symName)
    // A home-var mapping may be cached under "<ns>/<name>"; invalidate that one key.
    evaluator.qualifiedVarCache.withLock { $0["\(ns.name)/\(symName)"] = nil }
    return .nil
}

private func coreRemoveNs(_ evaluator: Evaluator, _ args: [Expr]) throws -> Expr {
    let name = try requireSymbol(args[0], function: "remove-ns",
        message: "argument must be a symbol, got \(corePrinter.printString(args[0]))")
    if name == "clojure.core" {
        throw EvaluatorError.invalidArgument(
            function: "remove-ns",
            message: "Cannot remove the clojure.core namespace")
    }
    guard let ns = evaluator.findNs(name) else { return .nil }
    evaluator.removeNs(name)
    return .namespace(ns)
}

private func coreLoadedLibs(_ evaluator: Evaluator) throws -> Expr {
    let names = evaluator.loadedLibs.withLock { $0 }
    let symbols = names.map { Expr.symbol($0, metadata: nil) }
    return .sortedSet(try buildSortedSet(evaluator, elements: symbols, comparator: nil))
}

private func coreAllNs(_ evaluator: Evaluator) -> Expr {
    .list(SwishPersistentList(evaluator.namespaces.values.map { .namespace($0) }), metadata: nil)
}

private func coreNsName(_ args: [Expr]) throws -> Expr {
    let ns = try requireNamespaceValue(args[0], function: "ns-name",
        message: "expected a namespace, got \(corePrinter.printString(args[0]))")
    return .symbol(ns.name, metadata: nil)
}

private func coreTheNs(_ evaluator: Evaluator, _ args: [Expr]) throws -> Expr {
    switch args[0] {
    case .namespace:
        return args[0]
    case .symbol(let name, _):
        guard let ns = evaluator.findNs(name) else {
            throw EvaluatorError.namespaceNotFound(name)
        }
        return .namespace(ns)
    default:
        throw EvaluatorError.invalidArgument(
            function: "the-ns",
            message: "expected a namespace or symbol, got \(corePrinter.printString(args[0]))")
    }
}

private func coreIntern(_ evaluator: Evaluator, _ args: [Expr]) throws -> Expr {
    try requireArgCount(args, in: 2...3, function: "intern")
    let ns = try namespaceArg(evaluator, args[0], function: "intern")
    let (name, symMeta) = try requireSymbolWithMeta(args[1], function: "intern",
        message: "name must be a symbol, got \(corePrinter.printString(args[1]))")
    let v = ns.intern(name: name, value: args.count == 3 ? args[2] : nil)
    if let symMeta {
        v.metadata = symMeta
    }
    return .varRef(v)
}

private func coreSymbol(_ args: [Expr]) throws -> Expr {
    switch args.count {
    case 1:
        switch args[0] {
        case .symbol: return args[0]

        case .string(let s): return .symbol(s, metadata: nil)

        case .keyword(let k): return .symbol(k, metadata: nil)

        case .varRef(let v): return .symbol("\(v.namespace.name)/\(v.name)", metadata: nil)

        default:
            throw EvaluatorError.invalidArgument(
                function: "symbol",
                message: "cannot coerce \(corePrinter.printString(args[0])) to symbol")
        }
    case 2:
        let ns: String?
        switch args[0] {
        case .nil:
            ns = nil

        case .string(let s):
            ns = s

        default:
            throw EvaluatorError.invalidArgument(function: "symbol", message: "namespace must be a string or nil")
        }
        let name = try requireString(args[1], function: "symbol", message: "name must be a string")
        if let ns {
            return .symbol("\(ns)/\(name)", metadata: nil)
        }
        return .symbol(name, metadata: nil)
    default:
        throw EvaluatorError.invalidArgument(function: "symbol", message: "requires 1 or 2 arguments")
    }
}

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
    evaluator.register(name: "resolve", arity: .fixed(1),
        doc: "Returns the var or Class to which a symbol will be resolved in the current namespace, else nil.",
        arglists: [["sym"]]) { [evaluator] args in try coreResolve(evaluator, args) }
}

// MARK: - Implementations

private func coreFindNs(_ evaluator: Evaluator, _ args: [Expr]) throws -> Expr {
    guard case .symbol(let name, _) = args[0]
    else {
        throw EvaluatorError.invalidArgument(
            function: "find-ns",
            message: "expected a symbol, got \(corePrinter.printString(args[0]))")
    }
    guard let ns = evaluator.findNs(name)
    else { return .nil }
    return .namespace(ns)
}

private func coreCreateNs(_ evaluator: Evaluator, _ args: [Expr]) throws -> Expr {
    guard case .symbol(let name, _) = args[0] else {
        throw EvaluatorError.invalidArgument(
            function: "create-ns",
            message: "expected a symbol, got \(args[0])")
    }
    return .namespace(evaluator.findOrCreateNs(name))
}

private func coreInNs(_ evaluator: Evaluator, _ args: [Expr]) throws -> Expr {
    guard case .symbol(let name, _) = args[0] else {
        throw EvaluatorError.invalidArgument(
            function: "in-ns",
            message: "expected a symbol, got \(args[0])")
    }
    let ns = evaluator.findOrCreateNs(name)
    evaluator.setCurrentNs(ns)
    return .namespace(ns)
}

private func coreRequire(_ evaluator: Evaluator, _ args: [Expr]) throws -> Expr {
    try evaluator.processRequireDirective(args, caller: "require")
    return .nil
}

private func coreAlias(_ evaluator: Evaluator, _ args: [Expr]) throws -> Expr {
    guard case .symbol(let aliasName, _) = args[0] else {
        throw EvaluatorError.invalidArgument(
            function: "alias",
            message: "first argument must be a symbol, got \(args[0])")
    }
    guard case .symbol(let nsName, _) = args[1] else {
        throw EvaluatorError.invalidArgument(
            function: "alias",
            message: "second argument must be a symbol, got \(args[1])")
    }
    guard let ns = evaluator.findNs(nsName) else {
        throw EvaluatorError.namespaceNotFound(nsName)
    }
    try evaluator.currentNs().alias(name: aliasName, ns: ns)
    return .nil
}

private func coreRefer(_ evaluator: Evaluator, _ args: [Expr]) throws -> Expr {
    guard case .symbol(let nsName, _) = args[0] else {
        throw EvaluatorError.invalidArgument(
            function: "refer",
            message: "first argument must be a symbol, got \(args[0])")
    }
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
        if let only {
            if only.contains(varName) { try currentNs.refer(v) }
        }
        else if !exclude.contains(varName) {
            try currentNs.refer(v)
        }
    }
    return .nil
}

private func coreResolve(_ evaluator: Evaluator, _ args: [Expr]) throws -> Expr {
    guard case .symbol(let name, _) = args[0] else { return .nil }
    if let v = try evaluator.resolveQualifiedVar(name: name) { return .varRef(v) }
    if let v = evaluator.resolveVar(name: name, in: evaluator.currentNs()) { return .varRef(v) }
    return .nil
}

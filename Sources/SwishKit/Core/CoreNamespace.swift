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
    evaluator.register(name: "symbol", arity: .variadic,
        doc: "Returns a Symbol with the given namespace and name. Arity-1 coerces string to symbol.",
        arglists: [["name"], ["ns", "name"]]) { args in try coreSymbol(args) }
}

// MARK: - Helpers

private func expectSymbol(_ expr: Expr, function: String) throws -> String {
    guard case .symbol(let name, _) = expr else {
        throw EvaluatorError.invalidArgument(
            function: function,
            message: "expected a symbol, got \(corePrinter.printString(expr))")
    }
    return name
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
    if let v = try? evaluator.resolveQualifiedVar(name: name) { return .varRef(v) }
    if let v = evaluator.resolveVar(name: name, in: evaluator.currentNs()) { return .varRef(v) }
    // Special forms (let, if, deftype, ...) are hardcoded symbol matches in
    // evalList's switch, never interned as vars — without this, (resolve 'let)
    // etc. would incorrectly report "doesn't exist" even though they work.
    // Returns a sentinel, not a var: nothing is interned, so bare-symbol
    // evaluation of these names (which never goes through resolve) is
    // unaffected and still throws exactly as it does today.
    if Evaluator.specialFormNames.contains(name) { return .keyword("special-form") }
    return .nil
}

private func coreNsInterns(_ evaluator: Evaluator, _ args: [Expr]) throws -> Expr {
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
    var result: [Expr: Expr] = [:]
    for (name, v) in ns.mappings where v.namespace === ns {
        result[.symbol(name, metadata: nil)] = .varRef(v)
    }
    return .map(result, metadata: nil)
}

private func coreAllNs(_ evaluator: Evaluator) -> Expr {
    .list(evaluator.namespaces.values.map { .namespace($0) }, metadata: nil)
}

private func coreNsName(_ args: [Expr]) throws -> Expr {
    guard case .namespace(let ns) = args[0] else {
        throw EvaluatorError.invalidArgument(
            function: "ns-name",
            message: "expected a namespace, got \(corePrinter.printString(args[0]))")
    }
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
        guard case .string(let name) = args[1] else {
            throw EvaluatorError.invalidArgument(function: "symbol", message: "name must be a string")
        }
        if let ns {
            return .symbol("\(ns)/\(name)", metadata: nil)
        }
        return .symbol(name, metadata: nil)
    default:
        throw EvaluatorError.invalidArgument(function: "symbol", message: "requires 1 or 2 arguments")
    }
}

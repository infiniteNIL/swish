private let firstMustBeAVar = "first argument must be a var"

// MARK: - Registration

func registerVar(into evaluator: Evaluator) {
    evaluator.register(name: "alter-var-root", arity: .atLeastOne,
        doc: "Atomically alters the root binding of var v by applying f to its current value plus any args. Returns the new value.",
        arglists: [["v", "f"], ["v", "f", "&", "args"]]) { [evaluator] args in try coreAlterVarRoot(evaluator, args) }
    evaluator.register(name: "var-get", arity: .fixed(1),
        doc: "Gets the value in the var object.",
        arglists: [["x"]]) { [evaluator] args in try coreVarGet(evaluator, args) }
    evaluator.register(name: "var-set", arity: .fixed(2),
        doc: "Sets the value in the var object to val. The var must be thread-locally bound.",
        arglists: [["x", "val"]]) { [evaluator] args in try coreVarSet(evaluator, args) }
    evaluator.register(name: "var-has-root?", arity: .fixed(1),
        doc: "Internal. Returns true if v has a root value (mirrors real Clojure's Var.hasRoot()). Backs defonce.",
        arglists: [["v"]]) { args in
        let v = try requireVarRef(args[0], function: "var-has-root?", message: firstMustBeAVar)
        return .boolean(v.isBound)
    }
    evaluator.register(name: "find-var", arity: .fixed(1),
        doc: "Returns the global var named by the namespace-qualified symbol, or nil if no var with that name.",
        arglists: [["sym"]]) { [evaluator] args in try coreFindVar(evaluator, args) }
    evaluator.register(name: "thread-bound?", arity: .variadic,
        doc: "Returns true if all of the vars provided as arguments have thread-local bindings. Implies that set!'ing the provided vars will succeed.",
        arglists: [["&", "vars"]]) { [evaluator] args in try coreThreadBound(evaluator, args) }
}

// MARK: - Implementations

private func coreAlterVarRoot(_ evaluator: Evaluator, _ args: [Expr]) throws -> Expr {
    guard args.count >= 2
    else {
        throw EvaluatorError.invalidArgument(
            function: "alter-var-root",
            message: "requires at least 2 arguments, got \(args.count)")
    }
    let v = try requireVarRef(args[0], function: "alter-var-root",
        message: "first argument must be a var reference, got \(corePrinter.printString(args[0]))")
    while true {
        guard let old = v.value
        else {
            throw EvaluatorError.unboundVar("\(v.namespace.name)/\(v.name)")
        }
        let newValue = try evaluator.call(args[1], args: [old] + Array(args.dropFirst(2)))
        if v.compareAndSetValue(expected: old, newValue: newValue) {
            try notifyWatches(evaluator, watches: v.watches, ref: args[0], old: old, new: newValue)
            return newValue
        }
    }
}

private func coreFindVar(_ evaluator: Evaluator, _ args: [Expr]) throws -> Expr {
    let qualified = try requireSymbol(args[0], function: "find-var",
        message: "argument must be a symbol, got \(corePrinter.printString(args[0]))")
    // Must be namespace-qualified — split on the first "/" (a leading "/" means an
    // empty namespace, which is not qualified). Matches Clojure's Var.find.
    guard let slash = qualified.firstIndex(of: "/"), slash != qualified.startIndex else {
        throw EvaluatorError.invalidArgument(
            function: "find-var", message: "Symbol \(qualified) is not fully qualified")
    }
    let nsName = String(qualified[..<slash])
    let name = String(qualified[qualified.index(after: slash)...])
    guard let ns = evaluator.findNs(nsName) else {
        throw EvaluatorError.invalidArgument(function: "find-var", message: "No such namespace: \(nsName)")
    }
    // Like Clojure's findInternedVar: return the mapping only if it's a home var of
    // this namespace (not a referred mapping); else nil.
    guard let v = ns.findVar(name: name), v.namespace === ns else {
        return .nil
    }
    return .varRef(v)
}

private func coreThreadBound(_ evaluator: Evaluator, _ args: [Expr]) throws -> Expr {
    let frames = evaluator.bindingFrames
    for arg in args {
        let v = try requireVarRef(arg, function: "thread-bound?",
            message: "argument must be a var, got \(corePrinter.printString(arg))")
        let id = ObjectIdentifier(v)
        if !frames.contains(where: { $0[id] != nil }) {
            return .boolean(false)
        }
    }
    return .boolean(true)
}

private func coreVarGet(_ evaluator: Evaluator, _ args: [Expr]) throws -> Expr {
    let v = try requireVarRef(args[0], function: "var-get",
        message: "first argument must be a var, got \(corePrinter.printString(args[0]))")
    guard let val = evaluator.dynamicValue(of: v)
    else {
        throw EvaluatorError.unboundVar("\(v.namespace.name)/\(v.name)")
    }
    return val
}

private func coreVarSet(_ evaluator: Evaluator, _ args: [Expr]) throws -> Expr {
    let v = try requireVarRef(args[0], function: "var-set",
        message: "first argument must be a var, got \(corePrinter.printString(args[0]))")
    let id = ObjectIdentifier(v)
    var frames = evaluator.bindingFrames
    for i in stride(from: frames.count - 1, through: 0, by: -1) {
        if frames[i][id] != nil {
            frames[i][id] = args[1]
            evaluator.bindingFrames = frames
            return args[1]
        }
    }
    throw EvaluatorError.invalidArgument(
        function: "var-set",
        message: "Var \(v.namespace.name)/\(v.name) is not dynamically bound")
}

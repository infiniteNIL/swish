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
        guard case .varRef(let v) = args[0] else {
            throw EvaluatorError.invalidArgument(function: "var-has-root?", message: "first argument must be a var")
        }
        return .boolean(v.isBound)
    }
}

// MARK: - Implementations

private func coreAlterVarRoot(_ evaluator: Evaluator, _ args: [Expr]) throws -> Expr {
    guard args.count >= 2
    else {
        throw EvaluatorError.invalidArgument(
            function: "alter-var-root",
            message: "requires at least 2 arguments, got \(args.count)")
    }
    guard case .varRef(let v) = args[0]
    else {
        throw EvaluatorError.invalidArgument(
            function: "alter-var-root",
            message: "first argument must be a var reference, got \(corePrinter.printString(args[0]))")
    }
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

private func coreVarGet(_ evaluator: Evaluator, _ args: [Expr]) throws -> Expr {
    guard case .varRef(let v) = args[0]
    else {
        throw EvaluatorError.invalidArgument(
            function: "var-get",
            message: "first argument must be a var, got \(corePrinter.printString(args[0]))")
    }
    guard let val = evaluator.dynamicValue(of: v)
    else {
        throw EvaluatorError.unboundVar("\(v.namespace.name)/\(v.name)")
    }
    return val
}

private func coreVarSet(_ evaluator: Evaluator, _ args: [Expr]) throws -> Expr {
    guard case .varRef(let v) = args[0]
    else {
        throw EvaluatorError.invalidArgument(
            function: "var-set",
            message: "first argument must be a var, got \(corePrinter.printString(args[0]))")
    }
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

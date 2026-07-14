// MARK: - Registration

func registerVar(into evaluator: Evaluator) {
    evaluator.register(name: "alter-var-root", arity: .atLeastOne,
        doc: "Atomically alters the root binding of var v by applying f to its current value plus any args. Returns the new value.",
        arglists: [["v", "f"], ["v", "f", "&", "args"]]) { [evaluator] args in try coreAlterVarRoot(evaluator, args) }
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
    guard let old = v.value
    else {
        throw EvaluatorError.unboundVar("\(v.namespace.name)/\(v.name)")
    }
    let newValue = try evaluator.call(args[1], args: [old] + Array(args.dropFirst(2)))
    v.value = newValue
    try notifyWatches(evaluator, watches: v.watches, ref: args[0], old: old, new: newValue)
    return newValue
}

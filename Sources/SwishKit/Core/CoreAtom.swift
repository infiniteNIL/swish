func registerAtom(into evaluator: Evaluator) {
    evaluator.register(name: "atom",   arity: .fixed(1),   body: coreAtom)
    evaluator.register(name: "atom?",  arity: .fixed(1),   body: coreIsAtom)
    evaluator.register(name: "reset!", arity: .fixed(2),   body: coreReset)
    evaluator.register(name: "deref",  arity: .fixed(1))   { [evaluator] args in try coreDeref(evaluator, args) }
    evaluator.register(name: "swap!",  arity: .atLeastOne) { [evaluator] args in try coreSwap(evaluator, args) }
}

private func coreAtom(_ args: [Expr]) throws -> Expr {
    .atom(SwishAtom(args[0]))
}

private func coreIsAtom(_ args: [Expr]) throws -> Expr {
    if case .atom = args[0] { return .boolean(true) }
    return .boolean(false)
}

private func coreDeref(_ evaluator: Evaluator, _ args: [Expr]) throws -> Expr {
    switch args[0] {
    case .atom(let a):
        return a.value

    case .varRef(let v):
        guard let value = v.value
        else { throw EvaluatorError.unboundVar("\(v.namespace.name)/\(v.name)") }
        return value

    default:
        throw EvaluatorError.invalidArgument(
            function: "deref",
            message: "argument must be an atom or var, got \(corePrinter.printString(args[0]))")
    }
}

private func coreReset(_ args: [Expr]) throws -> Expr {
    guard case .atom(let a) = args[0]
    else {
        throw EvaluatorError.invalidArgument(
            function: "reset!",
            message: "first argument must be an atom, got \(corePrinter.printString(args[0]))")
    }
    a.value = args[1]
    return args[1]
}

private func coreSwap(_ evaluator: Evaluator, _ args: [Expr]) throws -> Expr {
    guard args.count >= 2
    else {
        throw EvaluatorError.invalidArgument(
            function: "swap!",
            message: "requires at least 2 arguments")
    }
    guard case .atom(let a) = args[0]
    else {
        throw EvaluatorError.invalidArgument(
            function: "swap!",
            message: "first argument must be an atom, got \(corePrinter.printString(args[0]))")
    }
    let newValue = try evaluator.call(args[1], args: [a.value] + Array(args.dropFirst(2)))
    a.value = newValue
    return newValue
}

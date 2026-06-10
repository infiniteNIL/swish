func registerAtom(into evaluator: Evaluator) {
    evaluator.register(name: "atom", arity: .fixed(1),
        doc: "Creates and returns an Atom with an initial value of x and zero or more options (in any order): :meta metadata-map, :validator validate-fn. If metadata-map is supplied, it will become the metadata on the atom. validate-fn must be nil or a side-effect-free fn of one argument, which will be passed the intended new state on any state change. If the new state is unacceptable, the validate-fn should return false or throw an Error.",
        arglists: [["x"], ["x", "&", "options"]],
        body: coreAtom)
    evaluator.register(name: "atom?", arity: .fixed(1), doc: "Returns true if x is an atom, false otherwise.", arglists: [["x"]]) { args in if case .atom = args[0] { return .boolean(true) }; return .boolean(false) }
    evaluator.register(name: "reset!", arity: .fixed(2),
        doc: "Sets the value of atom to newval without regard for the current value. Returns newval.",
        arglists: [["atom", "newval"]],
        body: coreReset)
    evaluator.register(name: "deref", arity: .fixed(1),
        doc: "Also reader macro: @ref/@agent/@var/@atom/@delay/@future/@promise. Within a transaction, returns the in-transaction-value of ref, else returns the most-recently-committed value of ref. When applied to a var, agent or atom, returns its current state. When applied to a delay, forces it if not already forced. When applied to a future, will block if computation not complete. When applied to a promise, will block until a value is delivered.",
        arglists: [["ref"]]) { [evaluator] args in try coreDeref(evaluator, args) }
    evaluator.register(name: "swap!", arity: .atLeastOne,
        doc: "Atomically swaps the value of atom to be: (apply f current-value-of-atom args). Note that f may be called multiple times, and thus should be free of side effects. Returns the value that was swapped in.",
        arglists: [["atom", "f"], ["atom", "f", "x"], ["atom", "f", "x", "y"], ["atom", "f", "x", "y", "&", "args"]]) { [evaluator] args in try coreSwap(evaluator, args) }
}

private func coreAtom(_ args: [Expr]) throws -> Expr {
    .atom(SwishAtom(args[0]))
}

private func coreDeref(_ evaluator: Evaluator, _ args: [Expr]) throws -> Expr {
    switch args[0] {
    case .atom(let a):
        return a.value

    case .varRef(let v):
        guard let value = v.value
        else { throw EvaluatorError.unboundVar("\(v.namespace.name)/\(v.name)") }
        return value

    case .reduced(let v):
        return v

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

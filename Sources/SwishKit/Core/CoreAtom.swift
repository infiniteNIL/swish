func registerAtom(into evaluator: Evaluator) {
    evaluator.register(name: "atom", arity: .variadic,
        doc: "Creates and returns an Atom with an initial value of x and zero or more options (in any order): :meta metadata-map, :validator validate-fn. If metadata-map is supplied, it will become the metadata on the atom. validate-fn must be nil or a side-effect-free fn of one argument, which will be passed the intended new state on any state change. If the new state is unacceptable, the validate-fn should return false or throw an Error.",
        arglists: [["x"], ["x", "&", "options"]]) { [evaluator] args in try coreAtom(evaluator, args) }
    evaluator.register(name: "atom?", arity: .fixed(1), doc: "Returns true if x is an atom, false otherwise.", arglists: [["x"]]) { args in if case .atom = args[0] { return .boolean(true) }; return .boolean(false) }
    evaluator.register(name: "delay?", arity: .fixed(1),
        doc: "Returns true if x is a Delay created with delay.",
        arglists: [["x"]]) { args in
        if case .delay = args[0] { return .boolean(true) }
        return .boolean(false)
    }
    evaluator.register(name: "force", arity: .fixed(1),
        doc: "If x is a Delay, forces it and returns the value. Otherwise returns x.",
        arglists: [["x"]]) { args in
        if case .delay(let box) = args[0] { return try box.force() }
        return args[0]
    }
    evaluator.register(name: "reset!", arity: .fixed(2),
        doc: "Sets the value of atom to newval without regard for the current value. Returns newval.",
        arglists: [["atom", "newval"]]) { [evaluator] args in try coreReset(evaluator, args) }
    evaluator.register(name: "deref", arity: .fixed(1),
        doc: "Also reader macro: @ref/@agent/@var/@atom/@delay/@future/@promise. Within a transaction, returns the in-transaction-value of ref, else returns the most-recently-committed value of ref. When applied to a var, agent or atom, returns its current state. When applied to a delay, forces it if not already forced. When applied to a future, will block if computation not complete. When applied to a promise, will block until a value is delivered.",
        arglists: [["ref"]]) { [evaluator] args in try coreDeref(evaluator, args) }
    evaluator.register(name: "swap!", arity: .atLeastOne,
        doc: "Atomically swaps the value of atom to be: (apply f current-value-of-atom args). Note that f may be called multiple times, and thus should be free of side effects. Returns the value that was swapped in.",
        arglists: [["atom", "f"], ["atom", "f", "x"], ["atom", "f", "x", "y"], ["atom", "f", "x", "y", "&", "args"]]) { [evaluator] args in try coreSwap(evaluator, args) }
    evaluator.register(name: "get-validator", arity: .fixed(1),
        doc: "Gets the validator-fn for a var/ref/agent/atom. Returns nil if none.",
        arglists: [["ref"]]) { args in
            guard case .atom(let a) = args[0] else { return .nil }
            return a.validator ?? .nil
        }
}

// MARK: - Helpers

private func coreAtom(_ evaluator: Evaluator, _ args: [Expr]) throws -> Expr {
    guard !args.isEmpty else {
        throw EvaluatorError.arityMismatch(name: "atom", expected: .atLeastOne, got: 0)
    }
    let initialValue = args[0]
    var atomMeta: [Expr: Expr]? = nil
    var atomValidator: Expr? = nil

    var i = 1
    while i + 1 < args.count {
        let key = args[i]
        let val = args[i + 1]
        if key == .keyword("meta") {
            switch val {
            case .map(let sm):
                atomMeta = sm.dict
            case .sortedMap(let m, _):
                atomMeta = m
            case .nil:
                atomMeta = nil
            default:
                throw EvaluatorError.invalidArgument(function: "atom",
                    message: "metadata must be a map or nil, got \(corePrinter.printString(val))")
            }
        }
        else if key == .keyword("validator") {
            atomValidator = (val == .nil) ? nil : val
        }
        i += 2
    }

    let a = SwishAtom(initialValue, metadata: atomMeta, validator: atomValidator)
    if let vf = atomValidator {
        try checkValidator(evaluator, fn: vf, value: initialValue, context: "atom")
    }
    return .atom(a)
}

private func checkValidator(_ evaluator: Evaluator, fn: Expr, value: Expr, context: String) throws {
    let result = try evaluator.call(fn, args: [value])
    let valid: Bool
    switch result {
    case .boolean(false), .nil:
        valid = false
    default:
        valid = true
    }
    guard valid else {
        throw EvaluatorError.invalidArgument(function: context,
            message: "Invalid reference state")
    }
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

    case .delay(let box):
        return try box.force()

    default:
        throw EvaluatorError.invalidArgument(
            function: "deref",
            message: "argument must be an atom or var, got \(corePrinter.printString(args[0]))")
    }
}

private func coreReset(_ evaluator: Evaluator, _ args: [Expr]) throws -> Expr {
    guard case .atom(let a) = args[0]
    else {
        throw EvaluatorError.invalidArgument(
            function: "reset!",
            message: "first argument must be an atom, got \(corePrinter.printString(args[0]))")
    }
    if let vf = a.validator {
        try checkValidator(evaluator, fn: vf, value: args[1], context: "reset!")
    }
    let old = a.getAndSet(args[1])
    try notifyWatches(evaluator, watches: a.watches, ref: args[0], old: old, new: args[1])
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
    var old: Expr
    var newValue: Expr
    repeat {
        old = a.value
        newValue = try evaluator.call(args[1], args: [old] + Array(args.dropFirst(2)))
        if let vf = a.validator {
            try checkValidator(evaluator, fn: vf, value: newValue, context: "swap!")
        }
    } while !a.compareAndSet(expected: old, newValue: newValue)
    try notifyWatches(evaluator, watches: a.watches, ref: args[0], old: old, new: newValue)
    return newValue
}

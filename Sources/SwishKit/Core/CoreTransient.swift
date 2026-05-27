// MARK: - Registration

func registerTransient(into evaluator: Evaluator) {
    evaluator.register(name: "transient", arity: .fixed(1),
        doc: "Returns a new, transient version of the collection, in constant time.",
        arglists: [["coll"]],
        body: coreTransient)
    evaluator.register(name: "persistent!", arity: .fixed(1),
        doc: "Returns a new, persistent version of the transient collection, in constant time. The transient collection cannot be used after this call.",
        arglists: [["coll"]],
        body: corePersistentBang)
    evaluator.register(name: "assoc!", arity: .variadic,
        doc: "When applied to a transient map, adds mapping of key(s) to val(s). Returns the transient itself.",
        arglists: [["map", "key", "val"], ["map", "key", "val", "&", "kvs"]],
        body: coreAssocBang)
    evaluator.register(name: "dissoc!", arity: .variadic,
        doc: "Returns a transient map that doesn't contain a mapping for key(s).",
        arglists: [["map", "key"], ["map", "key", "&", "ks"]],
        body: coreDisjocBang)
    evaluator.register(name: "conj!", arity: .fixed(2),
        doc: "Adds x to the transient collection, and return coll. The addition may happen at different places depending on the concrete type.",
        arglists: [["coll", "x"]],
        body: coreConjBang)
}

// MARK: - Implementations

private func coreTransient(_ args: [Expr]) throws -> Expr {
    .transient(TransientCollection(args[0]))
}

private func corePersistentBang(_ args: [Expr]) throws -> Expr {
    guard case .transient(let tc) = args[0] else {
        throw EvaluatorError.invalidArgument(function: "persistent!",
            message: "expected transient, got \(corePrinter.printString(args[0]))")
    }
    return tc.value
}

private func coreAssocBang(_ args: [Expr]) throws -> Expr {
    guard case .transient(let tc) = args[0] else {
        throw EvaluatorError.invalidArgument(function: "assoc!",
            message: "expected transient, got \(corePrinter.printString(args[0]))")
    }
    tc.value = try coreAssoc([tc.value] + Array(args.dropFirst()))
    return args[0]
}

private func coreDisjocBang(_ args: [Expr]) throws -> Expr {
    guard case .transient(let tc) = args[0] else {
        throw EvaluatorError.invalidArgument(function: "dissoc!",
            message: "expected transient, got \(corePrinter.printString(args[0]))")
    }
    tc.value = try coreDissoc([tc.value] + Array(args.dropFirst()))
    return args[0]
}

private func coreConjBang(_ args: [Expr]) throws -> Expr {
    guard case .transient(let tc) = args[0] else {
        throw EvaluatorError.invalidArgument(function: "conj!",
            message: "expected transient, got \(corePrinter.printString(args[0]))")
    }
    tc.value = try conjOne(tc.value, args[1])
    return args[0]
}

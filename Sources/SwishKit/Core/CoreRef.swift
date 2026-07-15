// MARK: - Registration

private let transactionRetryLimit = 10_000

func registerRef(into evaluator: Evaluator) {
    evaluator.register(name: "ref", arity: .atLeastOne,
        doc: "Creates and returns a Ref with an initial value of x and zero or more options (in any order): :meta metadata-map, :validator validate-fn. If metadata-map is supplied, it will become the metadata on the ref. validate-fn must be nil or a side-effect-free fn of one argument, which will be passed the intended new state on any state change. If the new state is unacceptable, the validate-fn should return false or throw an Error.",
        arglists: [["x"], ["x", "&", "options"]]) { [evaluator] args in try coreRef(evaluator, args) }
    evaluator.register(name: "ref?", arity: .fixed(1),
        doc: "Returns true if x is a Ref, false otherwise.",
        arglists: [["x"]]) { args in
        if case .ref = args[0] { return .boolean(true) }
        return .boolean(false)
    }
    evaluator.register(name: "dosync-call", arity: .fixed(1),
        doc: "Runs f (a function of no args) as a transaction body, joining the current transaction if one is already running on this thread, otherwise starting a new one and retrying it on version conflicts. Backs the dosync macro.",
        arglists: [["f"]]) { [evaluator] args in try coreDosync(evaluator, args) }
    evaluator.register(name: "ref-set", arity: .fixed(2),
        doc: "Must be called in a transaction. Sets the value of ref. Returns val.",
        arglists: [["ref", "val"]]) { [evaluator] args in try coreRefSet(evaluator, args) }
    evaluator.register(name: "alter", arity: .atLeastOne,
        doc: "Must be called in a transaction. Sets the in-transaction-value of ref to: (apply f in-transaction-value-of-ref args). Returns the in-transaction-value of ref.",
        arglists: [["ref", "f"], ["ref", "f", "&", "args"]]) { [evaluator] args in try coreAlter(evaluator, args, functionName: "alter") }
    evaluator.register(name: "commute", arity: .atLeastOne,
        doc: "Must be called in a transaction. Sets the in-transaction-value of ref to: (apply f in-transaction-value-of-ref args). In this implementation, commute has the same full conflict-checked semantics as alter (a correctness-preserving simplification: real Clojure's commute is a throughput optimization for commutative ops, which this implementation gives up in favor of always checking).",
        arglists: [["ref", "f"], ["ref", "f", "&", "args"]]) { [evaluator] args in try coreAlter(evaluator, args, functionName: "commute") }
    evaluator.register(name: "ensure", arity: .fixed(1),
        doc: "Must be called in a transaction. Protects the ref from modification by other transactions and returns its in-transaction-value. Returns the value.",
        arglists: [["ref"]]) { [evaluator] args in try coreEnsure(evaluator, args) }
    evaluator.register(name: "ref-history-count", arity: .fixed(1),
        doc: "Returns the history count for ref. Always 0 in this implementation — see ref-min-history/ref-max-history.",
        arglists: [["ref"]]) { args in
        guard case .ref = args[0] else {
            throw EvaluatorError.invalidArgument(function: "ref-history-count", message: "argument must be a ref")
        }
        return .integer(0)
    }
    evaluator.register(name: "ref-min-history", arity: .atLeastOne,
        doc: "Gets/sets the min-history of ref (default 0). Recorded for API compatibility; this implementation does not retain ref history (see CLAUDE.md Known Limitations), so it has no effect on ref-history-count or transactional read behavior.",
        arglists: [["ref"], ["ref", "n"]]) { args in try coreRefHistory(args, which: \.minHistory, functionName: "ref-min-history") }
    evaluator.register(name: "ref-max-history", arity: .atLeastOne,
        doc: "Gets/sets the max-history of ref (default 10). Recorded for API compatibility; this implementation does not retain ref history (see CLAUDE.md Known Limitations), so it has no effect on ref-history-count or transactional read behavior.",
        arglists: [["ref"], ["ref", "n"]]) { args in try coreRefHistory(args, which: \.maxHistory, functionName: "ref-max-history") }
}

// MARK: - Helpers

private func coreRef(_ evaluator: Evaluator, _ args: [Expr]) throws -> Expr {
    guard !args.isEmpty else {
        throw EvaluatorError.arityMismatch(name: "ref", expected: .atLeastOne, got: 0)
    }
    let initialValue = args[0]
    let (refMeta, refValidator) = try parseMetaValidatorOptions(args, startingAt: 1, functionName: "ref")

    let r = SwishRef(initialValue, metadata: refMeta, validator: refValidator)
    if let vf = refValidator {
        try checkValidator(evaluator, fn: vf, value: initialValue, context: "ref")
    }
    return .ref(r)
}

private func requireTransaction(_ evaluator: Evaluator, function: String) throws -> TransactionContext {
    guard let tx = evaluator.currentTransaction else {
        throw EvaluatorError.invalidArgument(function: function, message: "No transaction running")
    }
    return tx
}

private func coreDosync(_ evaluator: Evaluator, _ args: [Expr]) throws -> Expr {
    let fn = args[0]

    // Nested dosync: join the existing transaction, no new retry loop or commit.
    if evaluator.currentTransaction != nil {
        return try evaluator.call(fn, args: [])
    }

    var attempts = 0
    while true {
        attempts += 1
        guard attempts <= transactionRetryLimit else {
            throw EvaluatorError.invalidArgument(function: "dosync",
                message: "Transaction failed after \(transactionRetryLimit) retries")
        }

        let tx = TransactionContext()
        evaluator.currentTransaction = tx
        let result: Expr
        do {
            result = try evaluator.call(fn, args: [])
        } catch {
            // An exception from the body aborts the transaction immediately —
            // only a version conflict at commit time retries.
            evaluator.currentTransaction = nil
            throw error
        }
        evaluator.currentTransaction = nil

        guard let committed = tx.attemptCommit() else {
            continue
        }
        for c in committed {
            try notifyWatches(evaluator, watches: c.ref.watches, ref: c.refExpr, old: c.old, new: c.new)
        }
        return result
    }
}

private func coreRefSet(_ evaluator: Evaluator, _ args: [Expr]) throws -> Expr {
    guard case .ref(let r) = args[0] else {
        throw EvaluatorError.invalidArgument(function: "ref-set",
            message: "first argument must be a ref, got \(corePrinter.printString(args[0]))")
    }
    let tx = try requireTransaction(evaluator, function: "ref-set")
    if let vf = r.validator {
        try checkValidator(evaluator, fn: vf, value: args[1], context: "ref-set")
    }
    tx.write(args[1], to: r, refExpr: args[0])
    return args[1]
}

private func coreAlter(_ evaluator: Evaluator, _ args: [Expr], functionName: String) throws -> Expr {
    guard args.count >= 2 else {
        throw EvaluatorError.invalidArgument(function: functionName, message: "requires at least 2 arguments")
    }
    guard case .ref(let r) = args[0] else {
        throw EvaluatorError.invalidArgument(function: functionName,
            message: "first argument must be a ref, got \(corePrinter.printString(args[0]))")
    }
    let tx = try requireTransaction(evaluator, function: functionName)
    let current = tx.read(r, refExpr: args[0])
    let newValue = try evaluator.call(args[1], args: [current] + Array(args.dropFirst(2)))
    if let vf = r.validator {
        try checkValidator(evaluator, fn: vf, value: newValue, context: functionName)
    }
    tx.write(newValue, to: r, refExpr: args[0])
    return newValue
}

private func coreEnsure(_ evaluator: Evaluator, _ args: [Expr]) throws -> Expr {
    guard case .ref(let r) = args[0] else {
        throw EvaluatorError.invalidArgument(function: "ensure",
            message: "first argument must be a ref, got \(corePrinter.printString(args[0]))")
    }
    let tx = try requireTransaction(evaluator, function: "ensure")
    return tx.read(r, refExpr: args[0])
}

private func coreRefHistory(_ args: [Expr], which keyPath: ReferenceWritableKeyPath<SwishRef, Int>, functionName: String) throws -> Expr {
    guard case .ref(let r) = args[0] else {
        throw EvaluatorError.invalidArgument(function: functionName, message: "first argument must be a ref")
    }
    if args.count >= 2 {
        guard case .integer(let n) = args[1] else {
            throw EvaluatorError.invalidArgument(function: functionName, message: "second argument must be an integer")
        }
        r[keyPath: keyPath] = n
        return args[0]
    }
    return .integer(r[keyPath: keyPath])
}

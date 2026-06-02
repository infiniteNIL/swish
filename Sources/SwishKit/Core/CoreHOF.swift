// MARK: - Registration

func registerHOF(into evaluator: Evaluator) {
    evaluator.register(name: "apply", arity: .atLeastOne,
        doc: "Applies fn f to the argument list formed by prepending intervening arguments to args.",
        arglists: [["f", "args"], ["f", "x", "args"], ["f", "x", "y", "args"], ["f", "x", "y", "z", "args"], ["f", "a", "b", "c", "d", "&", "args"]]) { [evaluator] args in try coreApply(evaluator, args) }
    // map, filter, keep, and mapcat are defined lazily in clojure/core.clj
    // and shadow these bootstrap registrations once core.clj loads.
    evaluator.register(name: "map", arity: .atLeastOne,
        doc: "Returns a lazy sequence consisting of the result of applying f to the set of first items of each coll, followed by applying f to the set of second items in each coll, until any one of the colls is exhausted. Any remaining items in other colls are ignored. Function f should accept number-of-colls arguments.",
        arglists: [["f"], ["f", "coll"], ["f", "c1", "c2"], ["f", "c1", "c2", "c3"], ["f", "c1", "c2", "c3", "&", "colls"]]) { [evaluator] args in try coreMap(evaluator, args) }
    evaluator.register(name: "filter", arity: .fixed(2),
        doc: "Returns a lazy sequence of the items in coll for which (pred item) returns logical true. pred must be free of side-effects.",
        arglists: [["pred"], ["pred", "coll"]]) { [evaluator] args in try coreFilter(evaluator, args) }
    evaluator.register(name: "reduce", arity: .atLeastOne,
        doc: "f should be a function of 2 arguments. If val is not supplied, returns the result of applying f to the first 2 items in coll, then applying f to that result and the 3rd item, etc. If coll contains no items, f must accept no arguments as well, and reduce returns the result of calling f with no arguments. If coll has only 1 item, it is returned and f is not called. If val is supplied, returns the result of applying f to val and the first item in coll, then applying f to that result and the 2nd item, etc. If coll contains no items, returns val and f is not called.",
        arglists: [["f", "coll"], ["f", "val", "coll"]]) { [evaluator] args in try coreReduce(evaluator, args) }
}

// MARK: - Implementations

private func isTruthy(_ expr: Expr) -> Bool {
    switch expr {
    case .nil, .boolean(false): return false
    default: return true
    }
}

func seqOf(_ expr: Expr, function name: String) throws -> [Expr] {
    guard let elems = asSequence(expr) else {
        throw EvaluatorError.invalidArgument(function: name,
            message: "don't know how to create seq from \(corePrinter.printString(expr))")
    }
    return elems
}

private func coreApply(_ evaluator: Evaluator, _ args: [Expr]) throws -> Expr {
    guard args.count >= 2 else {
        throw EvaluatorError.invalidArgument(function: "apply", message: "requires at least 2 args")
    }
    let f = args[0]
    let lastArg = args[args.count - 1]
    let tail: [Expr]
    switch lastArg {
    case .list(let elems, _):
        tail = elems

    case .vector(let elems, _):
        tail = elems

    case .nil:
        tail = []

    case .lazySeq:
        tail = try seqOf(lastArg, function: "apply")

    default:
        throw EvaluatorError.invalidArgument(function: "apply",
            message: "last argument must be a sequence, got \(corePrinter.printString(lastArg))")
    }
    let allArgs = Array(args.dropFirst().dropLast()) + tail
    return try evaluator.call(f, args: allArgs)
}

private func coreMap(_ evaluator: Evaluator, _ args: [Expr]) throws -> Expr {
    guard args.count >= 2 else {
        throw EvaluatorError.invalidArgument(function: "map", message: "requires at least 2 args")
    }
    let f = args[0]
    if args.count == 2 {
        let elems = try seqOf(args[1], function: "map")
        return .list(try elems.map { try evaluator.call(f, args: [$0]) }, metadata: nil)
    }
    let seqs = try args.dropFirst().map { try seqOf($0, function: "map") }
    let minLen = seqs.map(\.count).min() ?? 0
    var result: [Expr] = []
    for i in 0..<minLen {
        result.append(try evaluator.call(f, args: seqs.map { $0[i] }))
    }
    return .list(result, metadata: nil)
}

private func coreFilter(_ evaluator: Evaluator, _ args: [Expr]) throws -> Expr {
    let elems = try seqOf(args[1], function: "filter")
    var result: [Expr] = []
    for elem in elems {
        if isTruthy(try evaluator.call(args[0], args: [elem])) { result.append(elem) }
    }
    return .list(result, metadata: nil)
}

private func coreReduce(_ evaluator: Evaluator, _ args: [Expr]) throws -> Expr {
    guard args.count == 2 || args.count == 3 else {
        throw EvaluatorError.invalidArgument(function: "reduce", message: "requires 2 or 3 args")
    }
    let f = args[0]
    let init_: Expr?
    let elems: [Expr]
    if args.count == 2 {
        init_ = nil
        elems = try seqOf(args[1], function: "reduce")
    } else {
        init_ = args[1]
        elems = try seqOf(args[2], function: "reduce")
    }
    if elems.isEmpty {
        if let v = init_ { return v }
        return try evaluator.call(f, args: [])
    }
    var acc: Expr
    let rest: ArraySlice<Expr>
    if let v = init_ {
        acc  = v
        rest = elems[...]
    } else if elems.count == 1 {
        return elems[0]
    } else {
        acc  = elems[0]
        rest = elems[1...]
    }
    for elem in rest { acc = try evaluator.call(f, args: [acc, elem]) }
    return acc
}

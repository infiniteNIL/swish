// MARK: - Registration

func registerHOF(into evaluator: Evaluator) {
    evaluator.register(name: "apply", arity: .atLeastOne,
        doc: "Applies fn f to the argument list formed by prepending intervening arguments to args.",
        arglists: [["f", "args"], ["f", "x", "args"], ["f", "x", "y", "args"], ["f", "x", "y", "z", "args"], ["f", "a", "b", "c", "d", "&", "args"]]) { [evaluator] args in try coreApply(evaluator, args) }
    // map and filter are defined lazily in clojure/core.clj and shadow
    // these bootstrap registrations once core.clj loads.
    evaluator.register(name: "map", arity: .atLeastOne,
        doc: "Returns a lazy sequence consisting of the result of applying f to the set of first items of each coll, followed by applying f to the set of second items in each coll, until any one of the colls is exhausted. Any remaining items in other colls are ignored. Function f should accept number-of-colls arguments.",
        arglists: [["f"], ["f", "coll"], ["f", "c1", "c2"], ["f", "c1", "c2", "c3"], ["f", "c1", "c2", "c3", "&", "colls"]]) { [evaluator] args in try coreMap(evaluator, args) }
    evaluator.register(name: "filter", arity: .fixed(2),
        doc: "Returns a lazy sequence of the items in coll for which (pred item) returns logical true. pred must be free of side-effects.",
        arglists: [["pred"], ["pred", "coll"]]) { [evaluator] args in try coreFilter(evaluator, args) }
    evaluator.register(name: "reduce", arity: .atLeastOne,
        doc: "f should be a function of 2 arguments. If val is not supplied, returns the result of applying f to the first 2 items in coll, then applying f to that result and the 3rd item, etc. If coll contains no items, f must accept no arguments as well, and reduce returns the result of calling f with no arguments. If coll has only 1 item, it is returned and f is not called. If val is supplied, returns the result of applying f to val and the first item in coll, then applying f to that result and the 2nd item, etc. If coll contains no items, returns val and f is not called.",
        arglists: [["f", "coll"], ["f", "val", "coll"]]) { [evaluator] args in try coreReduce(evaluator, args) }
    evaluator.register(name: "reduced", arity: .fixed(1),
        doc: "Wraps x in a way that will cause a reduce to terminate early.",
        arglists: [["x"]]) { args in .reduced(args[0]) }
    evaluator.register(name: "reduced?", arity: .fixed(1),
        doc: "Returns true if x is the result of a call to reduced.",
        arglists: [["x"]]) { args in
        if case .reduced = args[0] { return .boolean(true) }
        return .boolean(false)
    }
    evaluator.register(name: "unreduced", arity: .fixed(1),
        doc: "If x is already reduced?, returns (deref x), else returns x.",
        arglists: [["x"]]) { args in
        if case .reduced(let v) = args[0] { return v }
        return args[0]
    }
    evaluator.register(name: "ensure-reduced", arity: .fixed(1),
        doc: "If x is already reduced?, returns it, else returns (reduced x).",
        arglists: [["x"]]) { args in
        if case .reduced = args[0] { return args[0] }
        return .reduced(args[0])
    }
    evaluator.register(name: "inst-ms", arity: .fixed(1),
        doc: "Return the number of milliseconds since January 1, 1970, 00:00:00 Coordinated Universal Time.",
        arglists: [["inst"]]) { args in
        guard case .inst(let date) = args[0] else {
            throw EvaluatorError.invalidArgument(function: "inst-ms", message: "expected inst, got \(args[0])")
        }
        return .integer(Int((date.timeIntervalSince1970 * 1000).rounded()))
    }
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

private func variadicFixedCount(_ f: Expr) -> Int? {
    switch f {
    case .function(let f):
        return f.params.firstIndex(of: "&")

    case .multiArityFunction(let maf):
        for a in maf.arities {
            if let i = a.params.firstIndex(of: "&") { return i }
        }
        return nil
        
    default:
        return nil
    }
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
        let middle = Array(args.dropFirst().dropLast())
        if let fixedCount = variadicFixedCount(f) {
            // Realize only the elements needed for the function's fixed params,
            // then pass the remaining lazy tail as the & rest binding directly.
            let needed = max(0, fixedCount - middle.count)
            var realized: [Expr] = []
            var remaining: Expr = lastArg
            for _ in 0..<needed {
                if case .lazySeq(let box) = remaining {
                    if let head = try box.forceHead() {
                        realized.append(head)
                        remaining = try box.forceTail()
                    } else {
                        remaining = .nil  // seq exhausted before filling fixed params
                        break
                    }
                } else {
                    break  // remaining became a list or nil after forcing tail
                }
            }
            let allArgs = middle + realized
            if case .nil = remaining {
                return try evaluator.call(f, args: allArgs)
            } else {
                return try evaluator.call(f, args: allArgs, rest: remaining)
            }
        }
        tail = try seqOf(lastArg, function: "apply")

    case .string(let s):
        tail = s.map { .character($0) }

    default:
        tail = try seqOf(lastArg, function: "apply")
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
    var acc: Expr?
    var current: Expr

    if args.count == 3 {
        acc = args[1]
        current = args[2]
    }
    else {
        acc = nil
        current = args[1]
    }

    // Normalise non-lazy, non-list collections once upfront.
    switch current {
    case .nil, .list, .lazySeq:
        break

    default:
        if let elems = asSequence(current) {
            current = .list(elems, metadata: nil)
        }
        else {
            throw EvaluatorError.invalidArgument(function: "reduce",
                message: "don't know how to create seq from \(corePrinter.printString(current))")
        }
    }

    while true {
        // Peel one element from the front of current.
        let head: Expr?
        let tail: Expr
        switch current {
        case .nil:
            head = nil
            tail = .nil

        case .list(let elems, _) where elems.isEmpty:
            head = nil
            tail = .nil

        case .list(let elems, _):
            head = elems[0]
            tail = elems.count == 1 ? .nil : .list(Array(elems.dropFirst()), metadata: nil)

        case .lazySeq(let box):
            head = try box.forceHead()
            tail = head != nil ? ((try? box.forceTail()) ?? .nil) : .nil

        default:
            head = nil
            tail = .nil
        }

        guard let h = head else {
            // Exhausted — return accumulator or call 0-arity f.
            if let a = acc { return a }
            return try evaluator.call(f, args: [])
        }

        if acc == nil {
            acc = h
        }
        else {
            let result = try evaluator.call(f, args: [acc!, h])
            if case .reduced(let v) = result { return v }
            acc = result
        }
        current = tail
    }
}

func registerSet(into evaluator: Evaluator) {
    evaluator.register(name: "set?", arity: .fixed(1),
        doc: "Returns true if x implements IPersistentSet",
        arglists: [["x"]]) { args in
        if case .set = args[0] { return .boolean(true) }
        if case .sortedSet = args[0] { return .boolean(true) }
        return .boolean(false)
    }

    evaluator.register(name: "disj", arity: .atLeastOne,
        doc: "disj[oin]. Returns a new set that does not contain key(s).",
        arglists: [["set"], ["set", "key"], ["set", "key", "&", "ks"]]) { [evaluator] args in
        switch args[0] {
        case .set(let ss):
            var elements = ss.elements
            for key in args.dropFirst() { elements.remove(key) }
            return .set(SwishSet(elements: elements, metadata: ss.metadata))

        case .sortedSet(let sss):
            let compare = evaluator.makeComparator(sss.comparator)
            var result = sss
            for key in args.dropFirst() { result = try result.removing(key, compare) }
            return .sortedSet(result)

        case .nil:
            return .nil

        default:
            throw EvaluatorError.invalidArgument(function: "disj", message: "first argument must be a set")
        }
    }

    evaluator.register(name: "sorted?", arity: .fixed(1),
        doc: "Returns true if coll implements Sorted.",
        arglists: [["coll"]]) { args in
        switch args[0] {
        case .sortedSet, .sortedMap:
            return .boolean(true)

        default:
            return .boolean(false)
        }
    }

    evaluator.register(name: "sorted-map", arity: .variadic,
        doc: "keyval => key val. Returns a new sorted map with supplied mappings.",
        arglists: [["&", "keyvals"]]) { [evaluator] args in
        guard args.count % 2 == 0 else {
            throw EvaluatorError.invalidArgument(function: "sorted-map",
                message: "requires an even number of args, got \(args.count)")
        }
        return .sortedMap(try buildSortedMap(evaluator, keyvals: Array(args), comparator: nil))
    }

    evaluator.register(name: "sorted-map-by", arity: .atLeastOne,
        doc: "keyval => key val. Returns a new sorted map with supplied mappings, using the supplied comparator.",
        arglists: [["comparator", "&", "keyvals"]]) { [evaluator] args in
        let kvs = Array(args.dropFirst())
        guard kvs.count % 2 == 0 else {
            throw EvaluatorError.invalidArgument(function: "sorted-map-by",
                message: "requires a comparator and an even number of key/val args")
        }
        return .sortedMap(try buildSortedMap(evaluator, keyvals: kvs, comparator: args[0]))
    }

    evaluator.register(name: "sorted-set-by", arity: .atLeastOne,
        doc: "Returns a new sorted set with supplied keys, using the supplied comparator.",
        arglists: [["comparator", "&", "keys"]]) { [evaluator] args in
        return .sortedSet(try buildSortedSet(evaluator, elements: Array(args.dropFirst()), comparator: args[0]))
    }

    evaluator.register(name: "sorted-set", arity: .variadic,
        doc: "Returns a new sorted set with supplied keys.",
        arglists: [["&", "keys"]]) { [evaluator] args in
        return .sortedSet(try buildSortedSet(evaluator, elements: Array(args), comparator: nil))
    }

    evaluator.register(name: "subseq", arity: .variadic,
        doc: "sc must be a sorted collection, test(s) one of <, <=, > or >=. Returns a seq of those entries with keys ek for which (test (.. sc comparator (compare ek key)) 0) is true, in ascending order.",
        arglists: [["sc", "test", "key"], ["sc", "start-test", "start-key", "end-test", "end-key"]]) { [evaluator] args in
        try coreSubseq(evaluator, args, ascending: true)
    }

    evaluator.register(name: "rsubseq", arity: .variadic,
        doc: "sc must be a sorted collection, test(s) one of <, <=, > or >=. Returns a reverse seq of those entries with keys ek for which (test (.. sc comparator (compare ek key)) 0) is true, in descending order.",
        arglists: [["sc", "test", "key"], ["sc", "start-test", "start-key", "end-test", "end-key"]]) { [evaluator] args in
        try coreSubseq(evaluator, args, ascending: false)
    }
}

/// Backs `subseq`/`rsubseq`. Selects sorted entries whose key `ek` satisfies the
/// test(s) applied to `(compare ek key)` vs 0 — the same bound-fn semantics as
/// Clojure's `mk-bound-fn`, honoring the collection's comparator. O(n): filters the
/// already-sorted backing (subseq is not a hot path); `rsubseq` reverses the result.
private func coreSubseq(_ evaluator: Evaluator, _ args: [Expr], ascending: Bool) throws -> Expr {
    let fn = ascending ? "subseq" : "rsubseq"
    guard args.count == 3 || args.count == 5 else {
        throw EvaluatorError.invalidArgument(function: fn, message: "requires 3 or 5 arguments, got \(args.count)")
    }
    // (searchKey, resulting entry) pairs, in ascending comparator order.
    let comparator: Expr?
    let entries: [(key: Expr, entry: Expr)]
    switch args[0] {
    case .sortedSet(let sss):
        comparator = sss.comparator
        entries = sss.elements.map { ($0, $0) }

    case .sortedMap(let ssm):
        comparator = ssm.comparator
        entries = zip(ssm.keys, ssm.values).map { ($0, .mapEntry($0, $1)) }

    default:
        throw EvaluatorError.invalidArgument(function: fn,
            message: "first argument must be a sorted collection, got \(corePrinter.printString(args[0]))")
    }
    let compare = evaluator.makeComparator(comparator)

    // Predicate from a test fn (<, <=, >, >=) + bound key: applies the test to the
    // sign of (compare entryKey boundKey) vs 0.
    func bound(_ test: Expr, _ key: Expr) -> (Expr) throws -> Bool {
        { ek in
            let c = try compare(ek, key)
            guard case .boolean(let b) = try evaluator.call(test, args: [.integer(c), .integer(0)]) else {
                throw EvaluatorError.invalidArgument(function: fn, message: "test must be one of <, <=, >, >=")
            }
            return b
        }
    }

    let selected: [(key: Expr, entry: Expr)]
    if args.count == 3 {
        let pred = bound(args[1], args[2])
        selected = try entries.filter { try pred($0.key) }
    }
    else {
        let startPred = bound(args[1], args[2])
        let endPred = bound(args[3], args[4])
        selected = try entries.filter { try startPred($0.key) && endPred($0.key) }
    }
    let ordered = ascending ? selected : selected.reversed()
    return ordered.isEmpty ? .nil : .list(SwishPersistentList(ordered.map { $0.entry }), metadata: nil)
}

// MARK: - Sorted collection construction

/// Builds a sorted set from arbitrary elements, sorting/deduping via the comparator
/// (`nil` = default `compareExprValue`). Insert-based, so O(n²) for large inputs —
/// acceptable for construction; sorted collections are typically small.
func buildSortedSet(_ evaluator: Evaluator, elements: [Expr], comparator: Expr?) throws -> SwishSortedSet {
    let compare = evaluator.makeComparator(comparator)
    var result = SwishSortedSet(elements: [], comparator: comparator, metadata: nil)
    for item in elements { result = try result.inserting(item, compare) }
    return result
}

/// Builds a sorted map from a flat key/val list; duplicate keys (comparing 0)
/// resolve last-wins (via `assoc`'s value-replace).
func buildSortedMap(_ evaluator: Evaluator, keyvals: [Expr], comparator: Expr?) throws -> SwishSortedMap {
    let compare = evaluator.makeComparator(comparator)
    var result = SwishSortedMap(keys: [], values: [], comparator: comparator, metadata: nil)
    for i in stride(from: 0, to: keyvals.count, by: 2) {
        result = try result.assoc(keyvals[i], keyvals[i + 1], compare)
    }
    return result
}


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
        arglists: [["set"], ["set", "key"], ["set", "key", "&", "ks"]]) { args in
        switch args[0] {
        case .set(var elements, _, let meta):
            for key in args.dropFirst() { elements.remove(key) }
            return .set(elements, _id: CollectionID(), metadata: meta)

        case .sortedSet(let elements, let meta):
            var result = elements
            for key in args.dropFirst() {
                result = result.filter { $0 != key }
            }
            return .sortedSet(result, metadata: meta)

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
        arglists: [["&", "keyvals"]]) { args in
        guard args.count % 2 == 0 else {
            throw EvaluatorError.invalidArgument(function: "sorted-map",
                message: "requires an even number of args, got \(args.count)")
        }
        var dict: [Expr: Expr] = [:]
        for i in stride(from: 0, to: args.count, by: 2) { dict[args[i]] = args[i + 1] }
        return .sortedMap(dict, metadata: nil)
    }

    evaluator.register(name: "sorted-map-by", arity: .atLeastOne,
        doc: "keyval => key val. Returns a new sorted map with supplied mappings, using the supplied comparator.",
        arglists: [["comparator", "&", "keyvals"]]) { args in
        let kvs = Array(args.dropFirst())
        guard kvs.count % 2 == 0 else {
            throw EvaluatorError.invalidArgument(function: "sorted-map-by",
                message: "requires a comparator and an even number of key/val args")
        }
        var dict: [Expr: Expr] = [:]
        for i in stride(from: 0, to: kvs.count, by: 2) { dict[kvs[i]] = kvs[i + 1] }
        return .sortedMap(dict, metadata: nil)
    }

    evaluator.register(name: "sorted-set-by", arity: .atLeastOne,
        doc: "Returns a new sorted set with supplied keys, using the supplied comparator.",
        arglists: [["comparator", "&", "keys"]]) { args in
        var result: [Expr] = []
        for item in args.dropFirst() { result = try sortedSetInsert(result, item) }
        return .sortedSet(result, metadata: nil)
    }

    evaluator.register(name: "sorted-set", arity: .variadic,
        doc: "Returns a new sorted set with supplied keys.",
        arglists: [["&", "keys"]]) { args in
        var result: [Expr] = []
        for item in args {
            result = try sortedSetInsert(result, item)
        }
        return .sortedSet(result, metadata: nil)
    }
}

// MARK: - Sorted set helpers

func sortedSetInsert(_ sorted: [Expr], _ item: Expr) throws -> [Expr] {
    var lo = 0, hi = sorted.count
    while lo < hi {
        let mid = (lo + hi) / 2
        let cmp = try compareExprValue(sorted[mid], item)
        if cmp == 0 { return sorted }
        if cmp < 0 { lo = mid + 1 } else { hi = mid }
    }
    var result = sorted
    result.insert(item, at: lo)
    return result
}

func sortedSetContains(_ sorted: [Expr], _ item: Expr) throws -> Bool {
    var lo = 0, hi = sorted.count
    while lo < hi {
        let mid = (lo + hi) / 2
        let cmp = try compareExprValue(sorted[mid], item)
        if cmp == 0 { return true }
        if cmp < 0 { lo = mid + 1 } else { hi = mid }
    }
    return false
}

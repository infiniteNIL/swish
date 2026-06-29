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
        case .set(var elements, let meta):
            for key in args.dropFirst() { elements.remove(key) }
            return .set(elements, metadata: meta)

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
        if case .sortedSet = args[0] { return .boolean(true) }
        return .boolean(false)
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

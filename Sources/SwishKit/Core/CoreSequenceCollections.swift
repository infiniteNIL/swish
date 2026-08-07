// MARK: - Registration

func registerSequenceCollections(into evaluator: Evaluator) {
    evaluator.register(name: "count", arity: .fixed(1),
        doc: "Returns the number of items in the collection. (count nil) returns 0. Also works on strings, arrays, and Java Collections and Maps.",
        arglists: [["coll"]],
        body: coreCount)
    evaluator.register(name: "empty", arity: .fixed(1),
        doc: "Returns an empty collection of the same category as coll, or nil.",
        arglists: [["coll"]],
        body: coreEmpty)
    evaluator.register(name: "to-array", arity: .fixed(1),
        doc: "Returns an array of the elements of coll.",
        arglists: [["coll"]]) { args in
        let elements = try asSequence(args[0]) ?? []
        return .array(SwishArray(elements))
    }
    evaluator.register(name: "into-array", arity: .variadic,
        doc: "Returns an array with components set to the values in aseq. An optional leading type argument is accepted for source compatibility but not enforced — Swish arrays are untyped.",
        arglists: [["aseq"], ["type", "aseq"]]) { args in
        try requireArgCount(args, in: 1...2, function: "into-array")
        let aseq = args.count == 2 ? args[1] : args[0]
        return .array(SwishArray(try seqOf(aseq, function: "into-array")))
    }
    evaluator.register(name: "vector", arity: .variadic,
        doc: "Creates a new vector containing the args.",
        arglists: [["&", "args"]],
        body: coreVector)
    evaluator.register(name: "hash-map", arity: .variadic,
        doc: "keyval => key val. Returns a new hash map with supplied mappings. If any keys are equal, they are handled as if by repeated uses of assoc.",
        arglists: [["&", "keyvals"]],
        body: coreHashMap)
    evaluator.register(name: "hash-set", arity: .variadic,
        doc: "Returns a new hash set with supplied keys. Any equal keys are handled as if by repeated uses of conj.",
        arglists: [["&", "keys"]],
        body: coreHashSet)
    evaluator.register(name: "contains?", arity: .fixed(2),
        doc: "Returns true if key is present in the given collection, otherwise returns false. Note that for numerically indexed collections like vectors and Java arrays, this tests if the numeric key is within the range of indexes. 'contains?' operates constant or logarithmic time; it will not perform a linear search for a value. See also 'some'.",
        arglists: [["coll", "key"]]) { [evaluator] args in try coreContains(evaluator, args) }
    evaluator.register(name: "nth", arity: .atLeastOne,
        doc: "Returns the value at the index. get returns nil if index out of bounds, nth throws an exception unless not-found is supplied. nth also works for strings, Java arrays, regex Matchers and Lists, and, in O(n) time, for sequences.",
        arglists: [["coll", "index"], ["coll", "index", "not-found"]],
        body: coreNth)
}

// MARK: - Implementations

private func coreCount(_ args: [Expr]) throws -> Expr {
    switch args[0] {
    case .nil:
        return .integer(0)

    case .list(let elements, _):
        return .integer(elements.count)

    case .seq(let elements):
        return .integer(elements.count)

    case .vector(let elements, _):
        return .integer(elements.count)

    case .array(let sa):
        return .integer(sa.elements.count)

    case .sharedVector(let sa, _):
        return .integer(sa.elements.count)

    case .mapEntry:
        return .integer(2)

    case .record(_, _, let data, _):
        return .integer(data.count)

    case .map(let sm):
        return .integer(sm.dict.count)

    case .sortedMap(let ssm):
        return .integer(ssm.count)

    case .set(let ss):
        return .integer(ss.elements.count)

    case .sortedSet(let sss):
        return .integer(sss.count)

    case .string(let s):
        return .integer(s.count)

    case .lazySeq:
        let elements = try seqOf(args[0], function: "count")
        return .integer(elements.count)

    case .transient(let tc):
        return try coreCount([tc.value])

    default:
        throw EvaluatorError.invalidArgument(
            function: "count",
            message: "not a countable collection, got \(corePrinter.printString(args[0]))")
    }
}

private func coreEmpty(_ args: [Expr]) throws -> Expr {
    switch args[0] {
    case .vector(_, let meta):
        return .vector([], metadata: meta)

    case .sharedVector(_, let meta):
        return .vector([], metadata: meta)

    case .list(_, let meta):
        return .list([], metadata: meta)

    case .seq, .lazySeq:
        return .list([], metadata: nil)

    case .mapEntry:
        return .vector([], metadata: nil)

    case .map(let sm):
        return .map(SwishMap(dict: [:], metadata: sm.metadata))

    case .set(let ss):
        return .set([], metadata: ss.metadata)

    case .sortedMap(let ssm):
        return .sortedMap(sortedKeys: [], sortedValues: [], comparator: ssm.comparator, metadata: ssm.metadata)

    case .sortedSet(let sss):
        return .sortedSet([], comparator: sss.comparator, metadata: sss.metadata)

    case .record:
        // Real JVM Clojure: defrecord instances are IPersistentCollection
        // (via IPersistentMap) so the instance? check passes, but defrecord
        // never generates an .empty() override, so (.empty a-record) throws.
        throw EvaluatorError.invalidArgument(function: "empty",
            message: "records do not support empty")

    default:
        return .nil
    }
}

private func coreVector(_ args: [Expr]) throws -> Expr {
    .vector(SwishPersistentVector(args), metadata: nil)
}

private func coreHashMap(_ args: [Expr]) throws -> Expr {
    guard args.count % 2 == 0 else {
        throw EvaluatorError.invalidArgument(function: "hash-map",
            message: "requires an even number of args, got \(args.count)")
    }
    var dict: [Expr: Expr] = [:]
    for i in stride(from: 0, to: args.count, by: 2) { dict[args[i]] = args[i + 1] }
    return .map(dict, metadata: nil)
}

private func coreHashSet(_ args: [Expr]) throws -> Expr {
    .set(Set(args), metadata: nil)
}

private func coreContains(_ evaluator: Evaluator, _ args: [Expr]) throws -> Expr {
    let key = args[1]
    switch args[0] {
    case .nil:
        return .boolean(false)

    case .map(let sm):
        return .boolean(sm.dict[key] != nil)

    case .sortedMap(let ssm):
        return .boolean(try ssm.get(key, evaluator.makeComparator(ssm.comparator)) != nil)

    case .set(let ss):
        return .boolean(ss.elements.contains(key))

    case .sortedSet(let sss):
        return .boolean(try sss.contains(key, evaluator.makeComparator(sss.comparator)))

    case .vector, .sharedVector:
        guard case .integer(let idx) = key else { return .boolean(false) }
        return .boolean(idx >= 0 && idx < (vectorCount(args[0]) ?? 0))

    case .array(let sa):
        guard case .integer(let idx) = key else {
            throw EvaluatorError.invalidArgument(function: "contains?",
                message: "contains? on array requires integer key, got \(corePrinter.printString(key))")
        }
        return .boolean(idx >= 0 && idx < sa.elements.count)

    case .mapEntry:
        guard case .integer(let idx) = key else { return .boolean(false) }
        return .boolean(idx == 0 || idx == 1)

    case .string(let s):
        guard case .integer(let idx) = key else {
            throw EvaluatorError.invalidArgument(function: "contains?",
                message: "contains? on string requires integer key, got \(corePrinter.printString(key))")
        }
        return .boolean(idx >= 0 && idx < s.count)

    case .transient(let tc):
        return try coreContains(evaluator, [tc.value, key])

    default:
        throw EvaluatorError.invalidArgument(function: "contains?",
            message: "\(corePrinter.printString(args[0])) is not supported")
    }
}

private func coreNth(_ args: [Expr]) throws -> Expr {
    try requireArgCount(args, atLeast: 2, function: "nth")
    guard case .integer(let idx) = args[1]
    else {
        throw EvaluatorError.invalidArgument(function: "nth", message: "index must be an integer")
    }
    let notFound: Expr? = args.count >= 3 ? args[2] : nil
    func outOfBounds() throws -> Expr {
        if let nf = notFound { return nf }
        throw EvaluatorError.invalidArgument(function: "nth",
            message: "Index \(idx) out of bounds")
    }
    switch args[0] {
    case .nil:
        return notFound ?? .nil

    case .vector, .sharedVector:
        guard let element = vectorElement(args[0], at: idx) else { return try outOfBounds() }
        return element

    case .lazySeq:
        var current: Expr = args[0]
        var i = 0
        while true {
            switch current {
            case .lazySeq(let box):
                guard let head = try box.forceHead() else { return try outOfBounds() }
                if i == idx { return head }
                current = try box.forceTail()
                i += 1

            case .list(let elems, _):
                let remaining = idx - i
                guard remaining >= 0 && remaining < elems.count else { return try outOfBounds() }
                return elems[remaining]

            default:
                return try outOfBounds()
            }
        }

    case .list(let elems, _):
        guard idx >= 0 && idx < elems.count else { return try outOfBounds() }
        return elems[idx]

    case .transient(let tc):
        var delegated = [tc.value, args[1]]
        if args.count >= 3 { delegated.append(args[2]) }
        return try coreNth(delegated)

    // Clojure's `nth` indexes a Matcher's *current* match: index 0 is the whole match
    // and 1…n are its capture groups, exactly what `re-groups` returns. `SwishMatcher`
    // already stores that shape in `last` (a `.vector` when the pattern has groups, a
    // bare `.string` when it doesn't — see `regexMatchResult`), so this reads it rather
    // than re-deriving anything. Deliberately confined to `nth`: a Matcher is not
    // seqable in Clojure either, so `asSequence` still rejects it and `seq`/`first`/
    // `map` keep throwing.
    case .matcher(let m):
        guard let current = m.last else { return try outOfBounds() }
        if case .vector = current {
            guard let group = vectorElement(current, at: idx) else { return try outOfBounds() }
            return group
        }
        // No capture groups: the whole match is the only addressable index.
        guard idx == 0 else { return try outOfBounds() }
        return current

    // Clojure's `nth` takes Indexed or sequential things only, so an unordered
    // collection throws — even though Swish's `asSequence` would happily produce
    // entries/elements for one. `(nth (seq m) 0)` still works: it is the *collection*
    // that is rejected here, never the seq you get from calling `seq` on it.
    case .map, .sortedMap, .set, .sortedSet, .record:
        throw EvaluatorError.invalidArgument(function: "nth",
            message: "nth not supported on this type: \(corePrinter.printString(args[0]))")

    default:
        let elements = try seqOf(args[0], function: "nth")
        guard idx >= 0 && idx < elements.count else { return try outOfBounds() }
        return elements[idx]
    }
}

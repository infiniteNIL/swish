// MARK: - Registration

func registerSequence(into evaluator: Evaluator) {
    evaluator.register(name: "list", arity: .variadic,
        doc: "Creates a new list containing the items.",
        arglists: [["&", "items"]],
        body: coreList)
    evaluator.register(name: "cons", arity: .fixed(2),
        doc: "Returns a new seq where x is the first element and seq is the rest.",
        arglists: [["x", "seq"]],
        body: coreCons)
    evaluator.register(name: "first", arity: .fixed(1),
        doc: "Returns the first item in the collection. Calls seq on its argument. If coll is nil, returns nil.",
        arglists: [["coll"]],
        body: coreFirst)
    evaluator.register(name: "rest", arity: .fixed(1),
        doc: "Returns a possibly empty seq of the items after the first. Calls seq on its argument.",
        arglists: [["coll"]],
        body: coreRest)
    evaluator.register(name: "list*", arity: .atLeastOne,
        doc: "Creates a new seq containing the items prepended to the rest, the last of which will be treated as a sequence.",
        arglists: [["args"], ["a", "args"], ["a", "b", "args"], ["a", "b", "c", "args"], ["a", "b", "c", "d", "&", "more"]],
        body: coreListStar)
    evaluator.register(name: "count", arity: .fixed(1),
        doc: "Returns the number of items in the collection. (count nil) returns 0. Also works on strings, arrays, and Java Collections and Maps.",
        arglists: [["coll"]],
        body: coreCount)
    evaluator.register(name: "vector?", arity: .fixed(1), doc: "Return true if x implements IPersistentVector",    arglists: [["x"]]) { args in if case .vector = args[0] { return .boolean(true) }; return .boolean(false) }
    evaluator.register(name: "peek", arity: .fixed(1),
        doc: "For a vector, returns the last element. For a list, returns the first element. Returns nil for empty or nil.",
        arglists: [["coll"]]) { args in
        switch args[0] {
        case .vector(let elems, _):
            return elems.last ?? .nil

        case .list(let elems, _):
            return elems.first ?? .nil

        case .nil:
            return .nil

        default:
            throw EvaluatorError.invalidArgument(function: "peek", message: "not a vector or list")
        }
    }
    evaluator.register(name: "pop", arity: .fixed(1),
        doc: "For a vector, returns a new vector without the last element. For a list, returns a new list without the first element.",
        arglists: [["coll"]]) { args in
        switch args[0] {
        case .vector(let elems, _):
            guard !elems.isEmpty
            else {
                throw EvaluatorError.invalidArgument(function: "pop", message: "Can't pop empty vector")
            }
            return .vector(Array(elems.dropLast()), metadata: nil)

        case .list(let elems, _):
            guard !elems.isEmpty
            else {
                throw EvaluatorError.invalidArgument(function: "pop", message: "Can't pop empty list")
            }
            return .list(Array(elems.dropFirst()), metadata: nil)

        default:
            throw EvaluatorError.invalidArgument(function: "pop", message: "not a vector or list")
        }
    }
    evaluator.register(name: "list?", arity: .fixed(1), doc: "Returns true if x implements IPersistentList",        arglists: [["x"]]) { args in if case .list = args[0] { return .boolean(true) }; return .boolean(false) }
    evaluator.register(name: "seq?",      arity: .fixed(1), doc: "Returns true if x implements ISeq",               arglists: [["x"]]) { args in switch args[0] { case .list, .lazySeq: return .boolean(true); default: return .boolean(false) } }
    evaluator.register(name: "lazy-seq?", arity: .fixed(1), doc: "Return true if x is a LazySeq.",                   arglists: [["x"]]) { args in if case .lazySeq = args[0] { return .boolean(true) }; return .boolean(false) }
    evaluator.register(name: "realized?", arity: .fixed(1),
        doc: "Returns true if a lazy sequence has been forced.",
        arglists: [["x"]]) { args in
        guard case .lazySeq(let box) = args[0] else {
            throw EvaluatorError.invalidArgument(function: "realized?",
                message: "realized? requires a lazy seq, got \(corePrinter.printString(args[0]))")
        }
        return .boolean(box.isRealized)
    }
    evaluator.register(name: "seq", arity: .fixed(1),
        doc: "Returns a seq on the collection. If the collection is empty, returns nil. (seq nil) returns nil. seq also works on Strings, native Java arrays (of reference types) and any objects that implement Iterable. Note that seqs cache values, thus seq should not be used on any Iterable whose iterator repeatedly returns the same mutable object.",
        arglists: [["coll"]],
        body: coreSeq)
    evaluator.register(name: "next", arity: .fixed(1),
        doc: "Returns a seq of the items after the first. Calls seq on its argument. If there are no more items, returns nil.",
        arglists: [["coll"]],
        body: coreNext)
    evaluator.register(name: "conj", arity: .variadic,
        doc: "conj[oin]. Returns a new collection with the xs 'added'. (conj nil item) returns (item). The 'addition' may happen at different 'places' depending on the concrete type.",
        arglists: [["coll", "x"], ["coll", "x", "&", "xs"]],
        body: coreConj)
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
        arglists: [["coll", "key"]],
        body: coreContains)
    evaluator.register(name: "nth", arity: .atLeastOne,
        doc: "Returns the value at the index. get returns nil if index out of bounds, nth throws an exception unless not-found is supplied. nth also works for strings, Java arrays, regex Matchers and Lists, and, in O(n) time, for sequences.",
        arglists: [["coll", "index"], ["coll", "index", "not-found"]],
        body: coreNth)
}

// MARK: - Implementations

private func coreList(_ args: [Expr]) throws -> Expr {
    .list(args, metadata: nil)
}

func asSequence(_ expr: Expr) -> [Expr]? {
    switch expr {
    case .list(let elements, _):
        return elements

    case .vector(let elements, _):
        return elements

    case .string(let s):
        return s.map { .character($0) }

    case .nil:
        return []

    case .map(let dict, _):
        return dict.map { .vector([$0.key, $0.value], metadata: nil) }

    case .set(let elements, _):
        return Array(elements)

    case .lazySeq:
        // Iteratively realize the full lazy seq into an array.
        // Never call this on a known-infinite seq.
        var result: [Expr] = []
        var current = expr
        while true {
            switch current {
            case .lazySeq(let box):
                guard let head = try? box.forceHead() else { return result }
                result.append(head)
                current = (try? box.forceTail()) ?? .nil

            case .list(let rest, _):
                result += rest
                return result

            case .nil:
                return result

            default:
                return result
            }
        }

    default:
        return nil
    }
}

private func coreFirst(_ args: [Expr]) throws -> Expr {
    if case .lazySeq(let box) = args[0] {
        return (try box.forceHead()) ?? .nil
    }
    let elements = try seqOf(args[0], function: "first")
    return elements.first ?? .nil
}

private func coreRest(_ args: [Expr]) throws -> Expr {
    if case .lazySeq(let box) = args[0] {
        return try box.forceTail()
    }
    let elements = try seqOf(args[0], function: "rest")
    return .list(Array(elements.dropFirst()), metadata: nil)
}

private func coreListStar(_ args: [Expr]) throws -> Expr {
    let prefix = Array(args.dropLast())
    let tail: [Expr]
    switch args.last! {
    case .list(let elements, _):
        tail = elements

    case .vector(let elements, _):
        tail = elements

    case .nil:
        tail = []

    case .lazySeq:
        tail = try seqOf(args.last!, function: "list*")

    case .string(let s):
        tail = s.map { .character($0) }

    default:
        throw EvaluatorError.invalidArgument(
            function: "list*",
            message: "last argument must be a sequence or nil, got \(corePrinter.printString(args.last!))")
    }
    return .list(prefix + tail, metadata: nil)
}

private func coreCount(_ args: [Expr]) throws -> Expr {
    switch args[0] {
    case .nil:
        return .integer(0)

    case .list(let elements, _):
        return .integer(elements.count)

    case .vector(let elements, _):
        return .integer(elements.count)

    case .map(let dict, _):
        return .integer(dict.count)

    case .set(let elements, _):
        return .integer(elements.count)

    case .string(let s):
        return .integer(s.count)

    case .lazySeq:
        let elements = try seqOf(args[0], function: "count")
        return .integer(elements.count)

    default:
        throw EvaluatorError.invalidArgument(
            function: "count",
            message: "not a countable collection, got \(corePrinter.printString(args[0]))")
    }
}

private func coreCons(_ args: [Expr]) throws -> Expr {
    // When the tail is a lazy seq, create a pre-realized lazy cons so we never force the tail.
    if case .lazySeq = args[1] {
        return .lazySeq(LazySeqBox(head: args[0], tail: args[1]))
    }
    guard let elements = asSequence(args[1])
    else {
        throw EvaluatorError.invalidArgument(
            function: "cons",
            message: "cannot cons onto \(corePrinter.printString(args[1]))")
    }
    return .list([args[0]] + elements, metadata: nil)
}

private func coreSeq(_ args: [Expr]) throws -> Expr {
    if case .lazySeq(let box) = args[0] {
        guard let head = try box.forceHead() else { return .nil }
        let tail = try box.forceTail()
        return .lazySeq(LazySeqBox(head: head, tail: tail))
    }
    let elements = try seqOf(args[0], function: "seq")
    return elements.isEmpty ? .nil : .list(elements, metadata: nil)
}

private func coreNext(_ args: [Expr]) throws -> Expr {
    if case .lazySeq(let box) = args[0] {
        let tail = try box.forceTail()
        // next returns nil when the tail is empty
        return try coreSeq([tail])
    }
    let elements = try seqOf(args[0], function: "next")
    let rest = Array(elements.dropFirst())
    return rest.isEmpty ? .nil : .list(rest, metadata: nil)
}

private func coreConj(_ args: [Expr]) throws -> Expr {
    guard !args.isEmpty else { return .nil }
    var result = args[0]
    for item in args.dropFirst() { result = try conjOne(result, item) }
    return result
}

func conjOne(_ coll: Expr, _ item: Expr) throws -> Expr {
    switch coll {
    case .nil:
        return .list([item], metadata: nil)

    case .list(let elems, let meta):
        return .list([item] + elems, metadata: meta)

    case .vector(let elems, let meta):
        return .vector(elems + [item], metadata: meta)

    case .map(var dict, let meta):
        if case .nil = item { return coll }
        if case .map(let other, _) = item {
            for (k, v) in other { dict[k] = v }
            return .map(dict, metadata: meta)
        }
        guard case .vector(let entry, _) = item, entry.count == 2
        else {
            throw EvaluatorError.invalidArgument(function: "conj",
                message: "map conj requires a [key val] vector")
        }
        dict[entry[0]] = entry[1]
        return .map(dict, metadata: meta)

    case .set(var elems, let meta):
        elems.insert(item)
        return .set(elems, metadata: meta)

    case .lazySeq:
        return .lazySeq(LazySeqBox(head: item, tail: coll))

    default:
        throw EvaluatorError.invalidArgument(function: "conj",
            message: "cannot conj onto \(corePrinter.printString(coll))")
    }
}

private func coreVector(_ args: [Expr]) throws -> Expr {
    .vector(args, metadata: nil)
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

private func coreContains(_ args: [Expr]) throws -> Expr {
    let key = args[1]
    switch args[0] {
    case .nil:
        return .boolean(false)

    case .map(let dict, _):
        return .boolean(dict[key] != nil)

    case .set(let elements, _):
        return .boolean(elements.contains(key))

    case .vector(let elements, _):
        guard case .integer(let idx) = key else {
            throw EvaluatorError.invalidArgument(function: "contains?",
                message: "key for vector must be an integer")
        }
        return .boolean(idx >= 0 && idx < elements.count)

    default:
        throw EvaluatorError.invalidArgument(function: "contains?",
            message: "\(corePrinter.printString(args[0])) is not supported")
    }
}

private func coreNth(_ args: [Expr]) throws -> Expr {
    guard args.count >= 2
    else {
        throw EvaluatorError.invalidArgument(function: "nth",
                                             message: "requires at least 2 arguments")
    }
    guard case .integer(let idx) = args[1]
    else {
        throw EvaluatorError.invalidArgument(function: "nth", message: "index must be an integer")
    }
    let notFound: Expr = args.count >= 3 ? args[2] : .nil
    switch args[0] {
    case .nil:
        return notFound

    case .vector(let elements, _):
        guard idx >= 0 && idx < elements.count else { return notFound }
        return elements[idx]

    case .lazySeq:
        var current: Expr = args[0]
        var i = 0
        while true {
            switch current {
            case .lazySeq(let box):
                guard let head = try box.forceHead() else { return notFound }
                if i == idx { return head }
                current = try box.forceTail()
                i += 1

            case .list(let elems, _):
                let remaining = idx - i
                guard remaining >= 0 && remaining < elems.count else { return notFound }
                return elems[remaining]

            default:
                return notFound
            }
        }

    default:
        let elements = try seqOf(args[0], function: "nth")
        guard idx >= 0 && idx < elements.count else { return notFound }
        return elements[idx]
    }
}



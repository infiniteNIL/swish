// MARK: - Registration

func registerSequenceCore(into evaluator: Evaluator) {
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
}

// MARK: - Implementations

private func coreList(_ args: [Expr]) throws -> Expr {
    .list(SwishPersistentList(args), metadata: nil)
}

func asSequence(_ expr: Expr) throws -> [Expr]? {
    switch expr {
    case .list(let elements, _):
        return elements.elements

    case .seq(let elements):
        return elements

    case .vector(let elements, _):
        return elements

    case .array(let sa):
        return sa.elements

    case .sharedVector(let sa, _):
        return sa.elements

    case .string(let s):
        return s.map { .character($0) }

    case .nil:
        return []

    case .map(let sm):
        let sortedKeys = sm.dict.keys.sorted { (try? compareExprValue($0, $1)).map { $0 < 0 } ?? false }
        return sortedKeys.map { .mapEntry($0, sm.dict[$0]!) }

    case .sortedMap(let dict, _):
        let sortedKeys = dict.keys.sorted { (try? compareExprValue($0, $1)).map { $0 < 0 } ?? false }
        return sortedKeys.map { .mapEntry($0, dict[$0]!) }

    case .mapEntry(let k, let v):
        return [k, v]

    case .set(let ss):
        return Array(ss.elements)

    case .sortedSet(let elements, _):
        return elements

    case .lazySeq:
        // Iteratively realize the full lazy seq into an array.
        // Never call this on a known-infinite seq.
        var result: [Expr] = []
        var current = expr
        while true {
            switch current {
            case .lazySeq(let box):
                guard let head = try box.forceHead() else { return result }
                result.append(head)
                current = try box.forceTail()

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
        let tail = try box.forceTail()
        if case .nil = tail { return .list([], metadata: nil) }
        return tail
    }
    if case .list(let elems, _) = args[0] {
        return .list(elems.dropFirst(1), metadata: nil)
    }
    let elements = try seqOf(args[0], function: "rest")
    return .list(SwishPersistentList(Array(elements.dropFirst())), metadata: nil)
}

private func coreListStar(_ args: [Expr]) throws -> Expr {
    let prefix = Array(args.dropLast())
    let tail: [Expr]
    switch args.last! {
    case .list(let elements, _):
        tail = elements.elements

    case .seq(let elements):
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
    return .list(SwishPersistentList(prefix + tail), metadata: nil)
}

private func coreCons(_ args: [Expr]) throws -> Expr {
    // When the tail is a lazy seq, create a pre-realized lazy cons so we never force the tail.
    if case .lazySeq = args[1] {
        return .lazySeq(LazySeqBox(head: args[0], tail: args[1]))
    }
    guard let elements = try asSequence(args[1])
    else {
        throw EvaluatorError.invalidArgument(
            function: "cons",
            message: "cannot cons onto \(corePrinter.printString(args[1]))")
    }
    return .seq([args[0]] + elements)
}

private func coreSeq(_ args: [Expr]) throws -> Expr {
    switch args[0] {
    case .lazySeq(let box):
        guard let head = try box.forceHead() else { return .nil }
        let tail = try box.forceTail()
        return .lazySeq(LazySeqBox(head: head, tail: tail))

    case .list(let elements, _):
        return elements.isEmpty ? .nil : .list(elements, metadata: nil)

    default:
        let elements = try seqOf(args[0], function: "seq")
        return elements.isEmpty ? .nil : .seq(elements)
    }
}

private func coreNext(_ args: [Expr]) throws -> Expr {
    if case .lazySeq(let box) = args[0] {
        let tail = try box.forceTail()
        // next returns nil when the tail is empty
        return try coreSeq([tail])
    }
    if case .list(let elems, _) = args[0] {
        let rest = elems.dropFirst(1)
        return rest.isEmpty ? .nil : .list(rest, metadata: nil)
    }
    let elements = try seqOf(args[0], function: "next")
    let rest = Array(elements.dropFirst())
    return rest.isEmpty ? .nil : .list(SwishPersistentList(rest), metadata: nil)
}

private func coreConj(_ args: [Expr]) throws -> Expr {
    guard !args.isEmpty else { return .vector([], metadata: nil) }
    var result = args[0]
    for item in args.dropFirst() { result = try conjOne(result, item) }
    return result
}

/// Merges a `conj`-style item (another map/sortedMap, a map entry, or a `[k v]`
/// vector) into `dict` in place — shared by `conjOne`'s `.map` and `.sortedMap`
/// cases, which differ only in which `Expr` case they wrap the result back into.
private func mergeIntoDict(_ dict: inout [Expr: Expr], item: Expr) throws {
    if case .map(let other) = item {
        for (k, v) in other.dict { dict[k] = v }
        return
    }
    if case .sortedMap(let other, _) = item {
        for (k, v) in other { dict[k] = v }
        return
    }
    if case .mapEntry(let k, let v) = item {
        dict[k] = v
        return
    }
    guard case .vector(let entry, _) = item, entry.count == 2
    else {
        throw EvaluatorError.invalidArgument(function: "conj",
            message: "map conj requires a [key val] vector")
    }
    dict[entry[0]] = entry[1]
}

func conjOne(_ coll: Expr, _ item: Expr) throws -> Expr {
    switch coll {
    case .nil:
        return .list([item], metadata: nil)

    case .list(let elems, let meta):
        return .list(elems.cons(item), metadata: meta)

    case .seq(let elems):
        return .seq([item] + elems)

    case .mapEntry(let k, let v):
        return .vector([k, v, item], metadata: nil)

    case .vector(let elems, let meta):
        return .vector(elems + [item], metadata: meta)

    case .sharedVector(let sa, let meta):
        return .vector(sa.elements + [item], metadata: meta)

    case .map(let sm):
        if case .nil = item { return coll }
        var dict = sm.dict
        try mergeIntoDict(&dict, item: item)
        return .map(dict, metadata: sm.metadata)

    case .sortedMap(var dict, let meta):
        if case .nil = item { return coll }
        try mergeIntoDict(&dict, item: item)
        return .sortedMap(dict, metadata: meta)

    case .set(let ss):
        var elems = ss.elements
        elems.insert(item)
        return .set(SwishSet(elements: elems, metadata: ss.metadata))

    case .sortedSet(let elems, let meta):
        return .sortedSet(try sortedSetInsert(elems, item), metadata: meta)

    case .lazySeq:
        return .lazySeq(LazySeqBox(head: item, tail: coll))

    default:
        throw EvaluatorError.invalidArgument(function: "conj",
            message: "cannot conj onto \(corePrinter.printString(coll))")
    }
}

// MARK: - Registration

func registerSequence(into evaluator: Evaluator) {
    evaluator.register(name: "list",     arity: .variadic,    body: coreList)
    evaluator.register(name: "cons",     arity: .fixed(2),    body: coreCons)
    evaluator.register(name: "first",    arity: .fixed(1),    body: coreFirst)
    evaluator.register(name: "rest",     arity: .fixed(1),    body: coreRest)
    evaluator.register(name: "string?",  arity: .fixed(1),    body: coreIsString)
    evaluator.register(name: "list*",    arity: .atLeastOne,  body: coreListStar)
    evaluator.register(name: "count",    arity: .fixed(1),    body: coreCount)
    evaluator.register(name: "vector?",  arity: .fixed(1),    body: coreIsVector)
    evaluator.register(name: "nil?",     arity: .fixed(1),    body: coreIsNil)
    evaluator.register(name: "list?",    arity: .fixed(1),    body: coreIsList)
    evaluator.register(name: "seq?",     arity: .fixed(1),    body: coreIsList)
    evaluator.register(name: "seq",      arity: .fixed(1),    body: coreSeq)
    evaluator.register(name: "next",     arity: .fixed(1),    body: coreNext)
    evaluator.register(name: "conj",     arity: .variadic,    body: coreConj)
    evaluator.register(name: "vector",   arity: .variadic,    body: coreVector)
    evaluator.register(name: "hash-map", arity: .variadic,    body: coreHashMap)
    evaluator.register(name: "hash-set", arity: .variadic,    body: coreHashSet)
    evaluator.register(name: "concat",    arity: .variadic,    body: coreConcat)
    evaluator.register(name: "contains?", arity: .fixed(2),    body: coreContains)
    evaluator.register(name: "nth",       arity: .atLeastOne,  body: coreNth)
    evaluator.register(name: "drop",      arity: .fixed(2),    body: coreDrop)
}

// MARK: - Implementations

private func coreList(_ args: [Expr]) throws -> Expr {
    .list(args, metadata: nil)
}

func asSequence(_ expr: Expr) -> [Expr]? {
    switch expr {
    case .list(let elements, _):   return elements
    case .vector(let elements, _): return elements
    case .string(let s):           return s.map { .character($0) }
    case .nil:                     return []
    case .map(let dict, _):        return dict.map { .vector([$0.key, $0.value], metadata: nil) }
    case .set(let elements, _):    return Array(elements)
    default:                       return nil
    }
}

private func coreFirst(_ args: [Expr]) throws -> Expr {
    let elements = try seqOf(args[0], function: "first")
    return elements.first ?? .nil
}

private func coreRest(_ args: [Expr]) throws -> Expr {
    let elements = try seqOf(args[0], function: "rest")
    return .list(Array(elements.dropFirst()), metadata: nil)
}

private func coreIsString(_ args: [Expr]) throws -> Expr {
    if case .string = args[0] { return .boolean(true) }
    return .boolean(false)
}

private func coreIsVector(_ args: [Expr]) throws -> Expr {
    if case .vector = args[0] { return .boolean(true) }
    return .boolean(false)
}

private func coreIsNil(_ args: [Expr]) throws -> Expr {
    if case .nil = args[0] { return .boolean(true) }
    return .boolean(false)
}

private func coreIsList(_ args: [Expr]) throws -> Expr {
    if case .list = args[0] { return .boolean(true) }
    return .boolean(false)
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

    default:
        throw EvaluatorError.invalidArgument(
            function: "count",
            message: "not a countable collection, got \(corePrinter.printString(args[0]))")
    }
}

private func coreCons(_ args: [Expr]) throws -> Expr {
    guard let elements = asSequence(args[1])
    else {
        throw EvaluatorError.invalidArgument(
            function: "cons",
            message: "cannot cons onto \(corePrinter.printString(args[1]))")
    }
    return .list([args[0]] + elements, metadata: nil)
}

private func coreSeq(_ args: [Expr]) throws -> Expr {
    let elements = try seqOf(args[0], function: "seq")
    return elements.isEmpty ? .nil : .list(elements, metadata: nil)
}

private func coreNext(_ args: [Expr]) throws -> Expr {
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

private func conjOne(_ coll: Expr, _ item: Expr) throws -> Expr {
    switch coll {
    case .nil:
        return .list([item], metadata: nil)
    case .list(let elems, let meta):
        return .list([item] + elems, metadata: meta)
    case .vector(let elems, let meta):
        return .vector(elems + [item], metadata: meta)
    case .map(var dict, let meta):
        guard case .vector(let entry, _) = item, entry.count == 2 else {
            throw EvaluatorError.invalidArgument(function: "conj",
                message: "map conj requires a [key val] vector")
        }
        dict[entry[0]] = entry[1]
        return .map(dict, metadata: meta)
    case .set(var elems, let meta):
        elems.insert(item)
        return .set(elems, metadata: meta)
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

private func coreConcat(_ args: [Expr]) throws -> Expr {
    var result: [Expr] = []
    for arg in args {
        result.append(contentsOf: try seqOf(arg, function: "concat"))
    }
    return result.isEmpty ? .nil : .list(result, metadata: nil)
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
    default:
        let elements = try seqOf(args[0], function: "nth")
        guard idx >= 0 && idx < elements.count else { return notFound }
        return elements[idx]
    }
}

private func coreDrop(_ args: [Expr]) throws -> Expr {
    guard case .integer(let n) = args[0] else {
        throw EvaluatorError.invalidArgument(function: "drop", message: "n must be an integer")
    }
    let elements = try seqOf(args[1], function: "drop")
    let count = max(0, n)
    if count >= elements.count { return .nil }
    let result = Array(elements.dropFirst(count))
    return result.isEmpty ? .nil : .list(result, metadata: nil)
}

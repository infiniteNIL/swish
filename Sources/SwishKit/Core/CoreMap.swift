func registerMap(into evaluator: Evaluator) {
    evaluator.register(name: "get",   arity: .variadic, body: coreGet)
    evaluator.register(name: "assoc", arity: .variadic, body: coreAssoc)
    evaluator.register(name: "merge", arity: .variadic, body: coreMerge)
    evaluator.register(name: "map?",  arity: .fixed(1), body: coreIsMap)
}

private func coreMerge(_ args: [Expr]) throws -> Expr {
    var result: [Expr: Expr] = [:]
    for arg in args {
        switch arg {
        case .map(let d, _):
            for (k, v) in d { result[k] = v }

        case .nil:
            break

        default:
            throw EvaluatorError.invalidArgument(
                function: "merge",
                message: "arguments must be maps or nil, got \(corePrinter.printString(arg))")
        }
    }
    return result.isEmpty ? .nil : .map(result, metadata: nil)
}

private func coreIsMap(_ args: [Expr]) throws -> Expr {
    if case .map = args[0] { return .boolean(true) }
    return .boolean(false)
}

private func coreAssoc(_ args: [Expr]) throws -> Expr {
    guard args.count >= 3, (args.count - 1) % 2 == 0 else {
        throw EvaluatorError.invalidArgument(
            function: "assoc",
            message: "requires a map and an even number of key/value pairs")
    }

    var dict: [Expr: Expr]
    switch args[0] {
    case .map(let d, _):
        dict = d

    case .nil:
        dict = [:]

    default:
        throw EvaluatorError.invalidArgument(
            function: "assoc",
            message: "first argument must be a map or nil, got \(corePrinter.printString(args[0]))")
    }

    var i = 1
    while i < args.count {
        dict[args[i]] = args[i + 1]
        i += 2
    }
    return .map(dict, metadata: nil)
}

private func coreGet(_ args: [Expr]) throws -> Expr {
    guard args.count == 2 || args.count == 3 else {
        throw EvaluatorError.invalidArgument(
            function: "get",
            message: "requires 2 or 3 arguments, got \(args.count)")
    }

    let notFound: Expr = args.count == 3 ? args[2] : .nil

    switch args[0] {
    case .nil:
        return notFound

    case .map(let dict, _):
        return dict[args[1]] ?? notFound

    case .vector(let elements, _):
        guard case .integer(let idx) = args[1], idx >= 0, idx < elements.count else {
            return notFound
        }
        return elements[idx]

    case .string(let s):
        guard case .integer(let idx) = args[1], idx >= 0 else { return notFound }
        guard let i = s.index(s.startIndex, offsetBy: idx, limitedBy: s.endIndex),
              i < s.endIndex
        else { return notFound }
        return .character(s[i])

    default:
        return notFound
    }
}

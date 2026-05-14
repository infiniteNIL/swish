func registerMap(into evaluator: Evaluator) {
    evaluator.register(name: "get",   arity: .variadic, body: coreGet)
    evaluator.register(name: "assoc", arity: .variadic, body: coreAssoc)
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

// MARK: - Registration

func registerSequence(into evaluator: Evaluator) {
    evaluator.register(name: "list",    arity: .variadic, body: coreList)
    evaluator.register(name: "cons",    arity: .fixed(2), body: coreCons)
    evaluator.register(name: "first",   arity: .fixed(1),   body: coreFirst)
    evaluator.register(name: "rest",    arity: .fixed(1),   body: coreRest)
    evaluator.register(name: "string?", arity: .fixed(1),   body: coreIsString)
    evaluator.register(name: "list*",   arity: .atLeastOne, body: coreListStar)
    evaluator.register(name: "count",   arity: .fixed(1),   body: coreCount)
    evaluator.register(name: "vector?", arity: .fixed(1),   body: coreIsVector)
}

// MARK: - Implementations

private func coreList(_ args: [Expr]) throws -> Expr {
    .list(args, metadata: nil)
}

private func asSequence(_ expr: Expr) -> [Expr]? {
    switch expr {
    case .list(let elements, _):
        return elements

    case .vector(let elements, _):
        return elements

    case .string(let s):
        return s.map { .character($0) }

    case .nil:
        return []

    default:
        return nil
    }
}

private func coreFirst(_ args: [Expr]) throws -> Expr {
    guard let elements = asSequence(args[0])
    else {
        throw EvaluatorError.invalidArgument(
            function: "first",
            message: "cannot take first of \(corePrinter.printString(args[0]))")
    }
    return elements.first ?? .nil
}

private func coreRest(_ args: [Expr]) throws -> Expr {
    guard let elements = asSequence(args[0])
    else {
        throw EvaluatorError.invalidArgument(
            function: "rest",
            message: "cannot take rest of \(corePrinter.printString(args[0]))")
    }
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

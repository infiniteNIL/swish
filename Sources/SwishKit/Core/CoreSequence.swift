// MARK: - Registration

func registerSequence(into evaluator: Evaluator) {
    evaluator.register(name: "list",    arity: .variadic, body: coreList)
    evaluator.register(name: "cons",    arity: .fixed(2), body: coreCons)
    evaluator.register(name: "first",   arity: .fixed(1),   body: coreFirst)
    evaluator.register(name: "rest",    arity: .fixed(1),   body: coreRest)
    evaluator.register(name: "string?", arity: .fixed(1),   body: coreIsString)
    evaluator.register(name: "list*",   arity: .atLeastOne, body: coreListStar)
}

// MARK: - Implementations

private func coreList(_ args: [Expr]) throws -> Expr {
    .list(args, metadata: nil)
}

private func coreFirst(_ args: [Expr]) throws -> Expr {
    switch args[0] {
    case .list(let elements, _):
        return elements.first ?? .nil

    case .vector(let elements, _):
        return elements.first ?? .nil

    case .string(let s):
        guard let c = s.first else { return .nil }
        return .character(c)

    case .nil:
        return .nil

    default:
        throw EvaluatorError.invalidArgument(
            function: "first",
            message: "cannot take first of \(corePrinter.printString(args[0]))")
    }
}

private func coreRest(_ args: [Expr]) throws -> Expr {
    switch args[0] {
    case .list(let elements, _):
        return .list(Array(elements.dropFirst()), metadata: nil)

    case .vector(let elements, _):
        return .list(Array(elements.dropFirst()), metadata: nil)

    case .string(let s):
        return .list(s.dropFirst().map { .character($0) }, metadata: nil)

    case .nil:
        return .list([], metadata: nil)

    default:
        throw EvaluatorError.invalidArgument(
            function: "rest",
            message: "cannot take rest of \(corePrinter.printString(args[0]))")
    }
}

private func coreIsString(_ args: [Expr]) throws -> Expr {
    if case .string = args[0] { return .boolean(true) }
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

private func coreCons(_ args: [Expr]) throws -> Expr {
    let element = args[0]
    switch args[1] {
    case .list(let elements, _):
        return .list([element] + elements, metadata: nil)

    case .vector(let elements, _):
        return .list([element] + elements, metadata: nil)

    case .nil:
        return .list([element], metadata: nil)

    case .string(let s):
        return .list([element] + s.map { .character($0) }, metadata: nil)

    default:
        throw EvaluatorError.invalidArgument(
            function: "cons",
            message: "cannot cons onto \(corePrinter.printString(args[1]))")
    }
}

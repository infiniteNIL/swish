// MARK: - Registration

func registerSequence(into evaluator: Evaluator) {
    evaluator.register(name: "list", arity: .variadic, body: coreList)
    evaluator.register(name: "cons", arity: .fixed(2), body: coreCons)
}

// MARK: - Implementations

private func coreList(_ args: [Expr]) throws -> Expr {
    .list(args, metadata: nil)
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

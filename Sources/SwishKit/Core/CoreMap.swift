func registerMap(into evaluator: Evaluator) {
    evaluator.register(name: "get", arity: .variadic, body: coreGet)
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

    case .map(let dict):
        return dict[args[1]] ?? notFound

    case .vector(let elements):
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

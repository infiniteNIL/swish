// MARK: - Registration

func registerSequence(into evaluator: Evaluator) {
    evaluator.register(name: "list", arity: .variadic, body: coreList)
}

// MARK: - Implementations

private func coreList(_ args: [Expr]) throws -> Expr {
    .list(args)
}

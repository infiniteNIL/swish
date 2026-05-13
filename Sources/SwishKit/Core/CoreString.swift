// MARK: - Registration

func registerString(into evaluator: Evaluator) {
    evaluator.register(name: "str", arity: .variadic, body: coreStr)
}

// MARK: - Implementations

private func coreStr(_ args: [Expr]) throws -> Expr {
    .string(args.map { corePrinter.strString($0) }.joined())
}

// MARK: - Registration

func registerString(into evaluator: Evaluator) {
    evaluator.register(name: "str", arity: .variadic,
        doc: "With no args, returns the empty string. With one arg x, returns x.toString(). (str nil) returns the empty string. With more than one arg, returns the concatenation of the str values of the args.",
        arglists: [[], ["x"], ["x", "&", "ys"]],
        body: coreStr)
}

// MARK: - Implementations

private func coreStr(_ args: [Expr]) throws -> Expr {
    .string(args.map { corePrinter.strString($0) }.joined())
}

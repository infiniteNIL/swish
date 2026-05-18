func registerSet(into evaluator: Evaluator) {
    evaluator.register(name: "set?", arity: .fixed(1), body: coreIsSet)
}

private func coreIsSet(_ args: [Expr]) throws -> Expr {
    if case .set = args[0] { return .boolean(true) }
    return .boolean(false)
}

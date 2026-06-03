// MARK: - Registration

func registerPredicates(into evaluator: Evaluator) {
    evaluator.register(name: "nil?", arity: .fixed(1),
        doc: "Returns true if x is nil, false otherwise.",
        arglists: [["x"]],
        body: coreIsNil)
    evaluator.register(name: "keyword?", arity: .fixed(1),
        doc: "Returns true if x is a keyword, false otherwise.",
        arglists: [["x"]]) { args in
        if case .keyword = args[0] { return .boolean(true) }
        return .boolean(false)
    }
    evaluator.register(name: "symbol?", arity: .fixed(1),
        doc: "Return true if x is a Symbol",
        arglists: [["x"]]) { args in
        if case .symbol = args[0] { return .boolean(true) }
        return .boolean(false)
    }
    evaluator.register(name: "string?", arity: .fixed(1),
        doc: "Return true if x is a String",
        arglists: [["x"]],
        body: coreIsString)
}

private func coreIsNil(_ args: [Expr]) throws -> Expr {
    if case .nil = args[0] { return .boolean(true) }
    return .boolean(false)
}

private func coreIsString(_ args: [Expr]) throws -> Expr {
    if case .string = args[0] { return .boolean(true) }
    return .boolean(false)
}

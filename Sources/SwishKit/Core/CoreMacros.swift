// MARK: - Registration

func registerMacros(into evaluator: Evaluator) {
    evaluator.register(name: "gensym",        arity: .variadic) { [evaluator] args in try coreGensym(evaluator, args) }
    evaluator.register(name: "macroexpand-1", arity: .fixed(1)) { [evaluator] args in try coreMacroexpand1(evaluator, args) }
    evaluator.register(name: "macroexpand",   arity: .fixed(1)) { [evaluator] args in try coreMacroexpand(evaluator, args) }
}

// MARK: - Implementations

private func coreGensym(_ evaluator: Evaluator, _ args: [Expr]) throws -> Expr {
    let prefix: String
    if let first = args.first, case .string(let p) = first {
        prefix = p
    } else {
        prefix = "G__"
    }
    return .symbol(evaluator.gensym(prefix: prefix))
}

private func coreMacroexpand1(_ evaluator: Evaluator, _ args: [Expr]) throws -> Expr {
    try evaluator.macroexpand1(args[0]) ?? args[0]
}

private func coreMacroexpand(_ evaluator: Evaluator, _ args: [Expr]) throws -> Expr {
    var form = args[0]
    while let expanded = try evaluator.macroexpand1(form) {
        form = expanded
    }
    return form
}

// MARK: - Registration

func registerMacros(into evaluator: Evaluator) {
    evaluator.register(name: "gensym", arity: .variadic,
        doc: "Returns a new symbol with a unique name. If a prefix string is supplied, the name is prefix# where # is some unique number. If prefix is not supplied, the prefix is 'G__'.",
        arglists: [[], ["prefix-string"]]) { [evaluator] args in try coreGensym(evaluator, args) }
    evaluator.register(name: "macroexpand-1", arity: .fixed(1),
        doc: "If form represents a macro form, returns its expansion, else returns form.",
        arglists: [["form"]]) { [evaluator] args in try coreMacroexpand1(evaluator, args) }
    evaluator.register(name: "macroexpand", arity: .fixed(1),
        doc: "Repeatedly calls macroexpand-1 on form until it no longer represents a macro form, then returns it. Note neither macroexpand-1 nor macroexpand expand macros in subforms.",
        arglists: [["form"]]) { [evaluator] args in try coreMacroexpand(evaluator, args) }
    evaluator.register(name: "eval", arity: .fixed(1),
        doc: "Evaluates the form data structure (not text!) and returns the result.",
        arglists: [["form"]]) { [evaluator] args in try evaluator.eval(args[0]) }
}

// MARK: - Implementations

private func coreGensym(_ evaluator: Evaluator, _ args: [Expr]) throws -> Expr {
    let prefix: String
    if let first = args.first, case .string(let p) = first {
        prefix = p
    }
    else {
        prefix = "G__"
    }
    return .symbol(evaluator.gensym(prefix: prefix), metadata: nil)
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

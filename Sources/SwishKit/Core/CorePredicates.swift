// MARK: - Registration

func registerPredicates(into evaluator: Evaluator) {
    evaluator.register(name: "nil?",     arity: .fixed(1), doc: "Returns true if x is nil, false otherwise.",       arglists: [["x"]]) { args in if case .nil     = args[0] { return .boolean(true) }; return .boolean(false) }
    evaluator.register(name: "keyword?", arity: .fixed(1), doc: "Returns true if x is a keyword, false otherwise.",  arglists: [["x"]]) { args in if case .keyword = args[0] { return .boolean(true) }; return .boolean(false) }
    evaluator.register(name: "symbol?",  arity: .fixed(1), doc: "Return true if x is a Symbol",                      arglists: [["x"]]) { args in if case .symbol  = args[0] { return .boolean(true) }; return .boolean(false) }
    evaluator.register(name: "string?",  arity: .fixed(1), doc: "Return true if x is a String",                      arglists: [["x"]]) { args in if case .string  = args[0] { return .boolean(true) }; return .boolean(false) }
    evaluator.register(name: "reader?",  arity: .fixed(1), doc: "Returns true if x is a SwishReader.",               arglists: [["x"]]) { args in if case .reader  = args[0] { return .boolean(true) }; return .boolean(false) }
    evaluator.register(name: "writer?",  arity: .fixed(1), doc: "Returns true if x is a SwishWriter.",               arglists: [["x"]]) { args in if case .writer  = args[0] { return .boolean(true) }; return .boolean(false) }
}

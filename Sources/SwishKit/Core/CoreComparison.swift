// MARK: - Registration

func registerComparison(into evaluator: Evaluator) {
    evaluator.register(name: "<",    arity: .atLeastOne, body: coreLessThan)
    evaluator.register(name: ">",    arity: .atLeastOne, body: coreGreaterThan)
    evaluator.register(name: "<=",   arity: .atLeastOne, body: coreLessOrEqual)
    evaluator.register(name: ">=",   arity: .atLeastOne, body: coreGreaterOrEqual)
    evaluator.register(name: "=",    arity: .atLeastOne, body: coreEqual)
    evaluator.register(name: "not=", arity: .atLeastOne, body: coreNotEqual)
}

// MARK: - Implementations

private func coreLessThan(_ args: [Expr]) throws -> Expr {
    if args.count == 1 { return .boolean(true) }
    return try .boolean(zip(args, args.dropFirst()).allSatisfy { try numericLessThan($0, $1, function: "<") })
}

private func coreGreaterThan(_ args: [Expr]) throws -> Expr {
    if args.count == 1 { return .boolean(true) }
    return try .boolean(zip(args, args.dropFirst()).allSatisfy { try numericLessThan($1, $0, function: ">") })
}

private func coreLessOrEqual(_ args: [Expr]) throws -> Expr {
    if args.count == 1 { return .boolean(true) }
    return try .boolean(zip(args, args.dropFirst()).allSatisfy { try !numericLessThan($1, $0, function: "<=") })
}

private func coreGreaterOrEqual(_ args: [Expr]) throws -> Expr {
    if args.count == 1 { return .boolean(true) }
    return try .boolean(zip(args, args.dropFirst()).allSatisfy { try !numericLessThan($0, $1, function: ">=") })
}

private func coreEqual(_ args: [Expr]) throws -> Expr {
    if args.count == 1 { return .boolean(true) }
    return .boolean(zip(args, args.dropFirst()).allSatisfy { $0 == $1 })
}

private func coreNotEqual(_ args: [Expr]) throws -> Expr {
    if args.count == 1 { return .boolean(false) }
    return .boolean(!zip(args, args.dropFirst()).allSatisfy { $0 == $1 })
}

// MARK: - Numeric helper

private func numericLessThan(_ a: Expr, _ b: Expr, function: String) throws -> Bool {
    switch try coerceNumericPair(a, b, function: function) {
    case .ints(let x, let y):     return x < y
    case .floats(let x, let y):   return x < y
    case .ratios(let x, let y):   return x.numerator * y.denominator < y.numerator * x.denominator
    }
}

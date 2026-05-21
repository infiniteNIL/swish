// MARK: - Registration

func registerComparison(into evaluator: Evaluator) {
    evaluator.register(name: "<", arity: .atLeastOne,
        doc: "Returns non-nil if nums are in monotonically increasing order, otherwise false.",
        arglists: [["x"], ["x", "y"], ["x", "y", "&", "more"]],
        body: coreLessThan)
    evaluator.register(name: ">", arity: .atLeastOne,
        doc: "Returns non-nil if nums are in monotonically decreasing order, otherwise false.",
        arglists: [["x"], ["x", "y"], ["x", "y", "&", "more"]],
        body: coreGreaterThan)
    evaluator.register(name: "<=", arity: .atLeastOne,
        doc: "Returns non-nil if nums are in monotonically non-decreasing order, otherwise false.",
        arglists: [["x"], ["x", "y"], ["x", "y", "&", "more"]],
        body: coreLessOrEqual)
    evaluator.register(name: ">=", arity: .atLeastOne,
        doc: "Returns non-nil if nums are in monotonically non-increasing order, otherwise false.",
        arglists: [["x"], ["x", "y"], ["x", "y", "&", "more"]],
        body: coreGreaterOrEqual)
    evaluator.register(name: "=", arity: .atLeastOne,
        doc: "Equality. Returns true if x equals y, false if not. Same as Java x.equals(y) except it also works for nil, and compares numbers and collections in a type-independent manner. Clojure's immutable data structures define equals() (and thus =) as a value, not an identity, comparison.",
        arglists: [["x"], ["x", "y"], ["x", "y", "&", "more"]],
        body: coreEqual)
    evaluator.register(name: "not=", arity: .atLeastOne,
        doc: "Same as (not (= obj1 obj2))",
        arglists: [["x"], ["x", "y"], ["x", "y", "&", "more"]],
        body: coreNotEqual)
}

// MARK: - Implementations

private func coreLessThan(_ args: [Expr]) throws -> Expr {
    try compareConsecutivePairs(args, singleArgResult: true) { try numericLessThan($0, $1, function: "<") }
}

private func coreGreaterThan(_ args: [Expr]) throws -> Expr {
    try compareConsecutivePairs(args, singleArgResult: true) { try numericLessThan($1, $0, function: ">") }
}

private func coreLessOrEqual(_ args: [Expr]) throws -> Expr {
    try compareConsecutivePairs(args, singleArgResult: true) { try !numericLessThan($1, $0, function: "<=") }
}

private func coreGreaterOrEqual(_ args: [Expr]) throws -> Expr {
    try compareConsecutivePairs(args, singleArgResult: true) { try !numericLessThan($0, $1, function: ">=") }
}

private func coreEqual(_ args: [Expr]) throws -> Expr {
    try compareConsecutivePairs(args, singleArgResult: true) { $0 == $1 }
}

private func coreNotEqual(_ args: [Expr]) throws -> Expr {
    if args.count == 1 { return .boolean(false) }
    return .boolean(!zip(args, args.dropFirst()).allSatisfy { $0 == $1 })
}

// MARK: - Numeric helper

private func numericLessThan(_ a: Expr, _ b: Expr, function: String) throws -> Bool {
    switch try coerceNumericPair(a, b, function: function) {
    case .ints(let x, let y):
        return x < y

    case .floats(let x, let y):
        return x < y

    case .ratios(let x, let y):
        return x.numerator * y.denominator < y.numerator * x.denominator
    }
}

private func compareConsecutivePairs(
    _ args: [Expr],
    singleArgResult: Bool,
    by compare: (Expr, Expr) throws -> Bool
) throws -> Expr {
    if args.count == 1 { return .boolean(singleArgResult) }
    return try .boolean(zip(args, args.dropFirst()).allSatisfy { try compare($0, $1) })
}

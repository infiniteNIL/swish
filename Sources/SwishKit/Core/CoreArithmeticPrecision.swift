import BigInt

// MARK: - Registration

func registerArithmeticPrecision(into evaluator: Evaluator) {
    evaluator.register(name: "inc'", arity: .fixed(1),
        doc: "Returns a number one greater than x. Supports arbitrary precision. See also: inc",
        arglists: [["x"]],
        body: coreIncP)
    evaluator.register(name: "dec'", arity: .fixed(1),
        doc: "Returns a number one less than x. Supports arbitrary precision. See also: dec",
        arglists: [["x"]],
        body: coreDecP)
    evaluator.register(name: "+'", arity: .variadic,
        doc: "Returns the sum of nums. (+') returns 0. Supports arbitrary precision. See also: +",
        arglists: [[], ["x"], ["x", "y"], ["x", "y", "&", "more"]],
        body: coreAddP)
    evaluator.register(name: "*'", arity: .variadic,
        doc: "Returns the product of nums. (*') returns 1. Supports arbitrary precision. See also: *",
        arglists: [[], ["x"], ["x", "y"], ["x", "y", "&", "more"]],
        body: coreMultiplyP)
}

// MARK: - Implementations

private func coreIncP(_ args: [Expr]) throws -> Expr {
    if case .integer(let x) = args[0] {
        let (result, overflow) = x.addingReportingOverflow(1)
        return overflow ? .bigInteger(BigInt(x) + 1) : .integer(result)
    }
    return try coreAdd([args[0], .integer(1)])
}

private func coreDecP(_ args: [Expr]) throws -> Expr {
    if case .integer(let x) = args[0] {
        let (result, overflow) = x.subtractingReportingOverflow(1)
        return overflow ? .bigInteger(BigInt(x) - 1) : .integer(result)
    }
    return try coreSubtract([args[0], .integer(1)])
}

private func numericAddP(_ a: Expr, _ b: Expr) throws -> Expr {
    try numericAddImpl(a, b, function: "+'") { x, y in .bigInteger(BigInt(x) + BigInt(y)) }
}

private func numericMultiplyP(_ a: Expr, _ b: Expr) throws -> Expr {
    try numericMultiplyImpl(a, b, function: "*'") { x, y in .bigInteger(BigInt(x) * BigInt(y)) }
}

private func coreAddP(_ args: [Expr]) throws -> Expr {
    if args.isEmpty { return .integer(0) }
    if args.count == 1 { return try coreNum([args[0]]) }
    return try args.dropFirst().reduce(args[0]) { try numericAddP($0, $1) }
}

private func coreMultiplyP(_ args: [Expr]) throws -> Expr {
    if args.isEmpty { return .integer(1) }
    if args.count == 1 { return try coreNum([args[0]]) }
    return try args.dropFirst().reduce(args[0]) { try numericMultiplyP($0, $1) }
}

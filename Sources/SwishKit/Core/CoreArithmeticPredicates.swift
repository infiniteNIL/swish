// MARK: - Registration

func registerArithmeticPredicates(into evaluator: Evaluator) {
    evaluator.register(
        name: "number?",
        arity: .fixed(1),
        doc: "Returns true if x is a Number",
        arglists: [["x"]],
        body: coreIsNumber
    )
    evaluator.register(
        name: "integer?",
        arity: .fixed(1),
        doc: "Returns true if n is an integer",
        arglists: [["n"]],
        body: coreIsInteger
    )
    evaluator.register(
        name: "int?",
        arity: .fixed(1),
        doc: "Return true if x is a fixed-precision integer.",
        arglists: [["x"]],
        body: coreIsInt
    )
    evaluator.register(
        name: "float?",
        arity: .fixed(1),
        doc: "Returns true if n is a floating point number",
        arglists: [["n"]],
        body: coreIsFloat
    )
    evaluator.register(
        name: "double?",
        arity: .fixed(1),
        doc: "Returns true if x is a 64-bit floating point Double",
        arglists: [["x"]],
        body: coreIsDouble
    )
    evaluator.register(
        name: "ratio?",
        arity: .fixed(1),
        doc: "Returns true if n is a Ratio",
        arglists: [["n"]],
        body: coreIsRatio
    )
    evaluator.register(
        name: "bigint?",
        arity: .fixed(1),
        doc: "Returns true if n is an arbitrary-precision integer",
        arglists: [["n"]],
        body: coreIsBigInt
    )
    evaluator.register(
        name: "decimal?",
        arity: .fixed(1),
        doc: "Returns true if n is a BigDecimal",
        arglists: [["n"]],
        body: coreIsDecimal
    )
    evaluator.register(
        name: "NaN?",
        arity: .fixed(1),
        doc: "Returns true if num is NaN, else false.",
        arglists: [["num"]],
        body: coreIsNaN
    )
}

// MARK: - Implementations

private func coreIsNumber(_ args: [Expr]) throws -> Expr {
    switch args[0] {
    case .integer, .float, .double, .ratio, .bigInteger, .bigDecimal:
        return .boolean(true)

    default:
        return .boolean(false)
    }
}

private func coreIsInteger(_ args: [Expr]) throws -> Expr {
    switch args[0] {
    case .integer, .bigInteger:
        return .boolean(true)

    default:
        return .boolean(false)
    }
}

private func coreIsInt(_ args: [Expr]) throws -> Expr {
    if case .integer = args[0] { return .boolean(true) }
    return .boolean(false)
}

private func coreIsFloat(_ args: [Expr]) throws -> Expr {
    switch args[0] {
    case .float, .double:
        return .boolean(true)

    default:
        return .boolean(false)
    }
}

private func coreIsDouble(_ args: [Expr]) throws -> Expr {
    if case .double = args[0] { return .boolean(true) }
    return .boolean(false)
}

private func coreIsRatio(_ args: [Expr]) throws -> Expr {
    if case .ratio = args[0] { return .boolean(true) }
    return .boolean(false)
}

private func coreIsBigInt(_ args: [Expr]) throws -> Expr {
    if case .bigInteger = args[0] { return .boolean(true) }
    return .boolean(false)
}

private func coreIsDecimal(_ args: [Expr]) throws -> Expr {
    if case .bigDecimal = args[0] { return .boolean(true) }
    return .boolean(false)
}

private func coreIsNaN(_ args: [Expr]) throws -> Expr {
    switch args[0] {
    case .double(let f): return .boolean(f.isNaN)
    case .float(let f):  return .boolean(f.isNaN)
    case .integer, .bigInteger, .ratio, .bigDecimal:
        return .boolean(false)
    default:
        throw EvaluatorError.invalidArgument(function: "NaN?",
            message: "expected a number, got \(corePrinter.printString(args[0]))")
    }
}

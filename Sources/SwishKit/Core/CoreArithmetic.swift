// MARK: - Registration

func registerArithmetic(into evaluator: Evaluator) {
    evaluator.register(name: "+",    arity: .variadic,  body: coreAdd)
    evaluator.register(name: "-",    arity: .variadic,  body: coreSubtract)
    evaluator.register(name: "*",    arity: .variadic,  body: coreMultiply)
    evaluator.register(name: "/",    arity: .variadic,  body: coreDivide)
    evaluator.register(name: "mod",  arity: .fixed(2),  body: coreMod)
    evaluator.register(name: "rem",  arity: .fixed(2),  body: coreRem)
    evaluator.register(name: "quot", arity: .fixed(2),  body: coreQuot)
    evaluator.register(name: "number?",  arity: .fixed(1), body: coreIsNumber)
    evaluator.register(name: "integer?", arity: .fixed(1), body: coreIsInteger)
    evaluator.register(name: "float?",   arity: .fixed(1), body: coreIsFloat)
    evaluator.register(name: "ratio?",   arity: .fixed(1), body: coreIsRatio)
}

// MARK: - Implementations

private func coreAdd(_ args: [Expr]) throws -> Expr {
    if args.isEmpty {
        return .integer(0)
    }

    if args.count == 1 {
        return try assertSingleNumeric(args[0], function: "+")
    }

    return try args.dropFirst().reduce(args[0]) { try numericAdd($0, $1) }
}

private func coreSubtract(_ args: [Expr]) throws -> Expr {
    if args.isEmpty {
        throw EvaluatorError.invalidArgument(function: "-", message: "requires at least 1 argument")
    }

    if args.count == 1 {
        switch args[0] {
        case .integer(let x):
            let (result, overflow) = (0 as Int).subtractingReportingOverflow(x)
            if overflow { throw EvaluatorError.integerOverflow(operation: "-", lhs: 0, rhs: x) }
            return .integer(result)

        case .float(let x):
            return .float(-x)

        case .ratio(let x):
            return .ratio(Ratio(-x.numerator, x.denominator))

        default:
            throw EvaluatorError.invalidArgument(
                function: "-", message: "expected a number, got \(corePrinter.printString(args[0]))")
        }
    }

    return try args.dropFirst().reduce(args[0]) { try numericSubtract($0, $1) }
}

private func coreMultiply(_ args: [Expr]) throws -> Expr {
    if args.isEmpty {
        return .integer(1)
    }
    if args.count == 1 {
        return try assertSingleNumeric(args[0], function: "*")
    }
    return try args.dropFirst().reduce(args[0]) { try numericMultiply($0, $1) }
}

private func coreDivide(_ args: [Expr]) throws -> Expr {
    if args.isEmpty {
        throw EvaluatorError.invalidArgument(function: "/", message: "requires at least 1 argument")
    }

    if args.count == 1 {
        switch args[0] {
        case .integer(let x):
            if x == 0 {
                throw EvaluatorError.invalidArgument(function: "/", message: "division by zero")
            }
            let r = Ratio(1, x)
            return r.denominator == 1 ? .integer(r.numerator) : .ratio(r)

        case .float(let x):
            return .float(1.0 / x)

        case .ratio(let x):
            if x.numerator == 0 {
                throw EvaluatorError.invalidArgument(function: "/", message: "division by zero")
            }
            let r = Ratio(x.denominator, x.numerator)
            return r.denominator == 1 ? .integer(r.numerator) : .ratio(r)

        default:
            throw EvaluatorError.invalidArgument(
                function: "/", message: "expected a number, got \(corePrinter.printString(args[0]))")
        }
    }

    return try args.dropFirst().reduce(args[0]) { try numericDivide($0, $1) }
}

// MARK: - Numeric coercion (internal — used by CoreComparison via numericLessThan)

enum NumericPair {
    case ints(Int, Int)
    case floats(Double, Double)
    case ratios(Ratio, Ratio)
}

func coerceNumericPair(_ a: Expr, _ b: Expr, function: String) throws -> NumericPair {
    switch (a, b) {
    case (.integer(let x), .integer(let y)):
        return .ints(x, y)

    case (.float(let x), .float(let y)):
        return .floats(x, y)

    case (.float(let x), .integer(let y)):
        return .floats(x, Double(y))

    case (.integer(let x), .float(let y)):
        return .floats(Double(x), y)

    case (.float(let x), .ratio(let y)):
        return .floats(x, Double(y.numerator) / Double(y.denominator))

    case (.ratio(let x), .float(let y)):
        return .floats(Double(x.numerator) / Double(x.denominator), y)

    case (.ratio(let x), .ratio(let y)):
        return .ratios(x, y)

    case (.ratio(let x), .integer(let y)):
        return .ratios(x, Ratio(y, 1))

    case (.integer(let x), .ratio(let y)):
        return .ratios(Ratio(x, 1), y)

    default:
        throw EvaluatorError.invalidArgument(
            function: function,
            message: "expected numbers, got \(corePrinter.printString(a)) and \(corePrinter.printString(b))")
    }
}

// MARK: - Numeric helpers

private func ratioExpr(_ r: Ratio) -> Expr {
    r.denominator == 1 ? .integer(r.numerator) : .ratio(r)
}

private func assertSingleNumeric(_ arg: Expr, function: String) throws -> Expr {
    switch arg {
    case .integer, .float, .ratio:
        return arg

    default:
        throw EvaluatorError.invalidArgument(
            function: function, message: "expected a number, got \(corePrinter.printString(arg))")
    }
}

private func numericAdd(_ a: Expr, _ b: Expr) throws -> Expr {
    switch try coerceNumericPair(a, b, function: "+") {
    case .ints(let x, let y):
        let (result, overflow) = x.addingReportingOverflow(y)
        if overflow { throw EvaluatorError.integerOverflow(operation: "+", lhs: x, rhs: y) }
        return .integer(result)

    case .floats(let x, let y):
        return .float(x + y)

    case .ratios(let x, let y):
        let (n1, o1) = x.numerator.multipliedReportingOverflow(by: y.denominator)
        let (n2, o2) = y.numerator.multipliedReportingOverflow(by: x.denominator)
        let (num, o3) = n1.addingReportingOverflow(n2)
        let (den, o4) = x.denominator.multipliedReportingOverflow(by: y.denominator)
        guard !o1 && !o2 && !o3 && !o4
        else { throw EvaluatorError.invalidArgument(function: "+", message: "integer overflow in ratio arithmetic") }
        return ratioExpr(Ratio(num, den))
    }
}

private func numericSubtract(_ a: Expr, _ b: Expr) throws -> Expr {
    switch try coerceNumericPair(a, b, function: "-") {
    case .ints(let x, let y):
        let (result, overflow) = x.subtractingReportingOverflow(y)
        if overflow { throw EvaluatorError.integerOverflow(operation: "-", lhs: x, rhs: y) }
        return .integer(result)

    case .floats(let x, let y):
        return .float(x - y)

    case .ratios(let x, let y):
        let (n1, o1) = x.numerator.multipliedReportingOverflow(by: y.denominator)
        let (n2, o2) = y.numerator.multipliedReportingOverflow(by: x.denominator)
        let (num, o3) = n1.subtractingReportingOverflow(n2)
        let (den, o4) = x.denominator.multipliedReportingOverflow(by: y.denominator)
        guard !o1 && !o2 && !o3 && !o4
        else { throw EvaluatorError.invalidArgument(function: "-", message: "integer overflow in ratio arithmetic") }
        return ratioExpr(Ratio(num, den))
    }
}

private func numericMultiply(_ a: Expr, _ b: Expr) throws -> Expr {
    switch try coerceNumericPair(a, b, function: "*") {
    case .ints(let x, let y):
        let (result, overflow) = x.multipliedReportingOverflow(by: y)
        if overflow { throw EvaluatorError.integerOverflow(operation: "*", lhs: x, rhs: y) }
        return .integer(result)

    case .floats(let x, let y):
        return .float(x * y)

    case .ratios(let x, let y):
        let (num, o1) = x.numerator.multipliedReportingOverflow(by: y.numerator)
        let (den, o2) = x.denominator.multipliedReportingOverflow(by: y.denominator)
        guard !o1 && !o2
        else { throw EvaluatorError.invalidArgument(function: "*", message: "integer overflow in ratio arithmetic") }
        return ratioExpr(Ratio(num, den))
    }
}

private func numericDivide(_ a: Expr, _ b: Expr) throws -> Expr {
    switch try coerceNumericPair(a, b, function: "/") {
    case .ints(let x, let y):
        if y == 0 {
            throw EvaluatorError.invalidArgument(function: "/", message: "division by zero")
        }
        return ratioExpr(Ratio(x, y))

    case .floats(let x, let y):
        return .float(x / y)

    case .ratios(let x, let y):
        if y.numerator == 0 {
            throw EvaluatorError.invalidArgument(function: "/", message: "division by zero")
        }
        let (num, o1) = x.numerator.multipliedReportingOverflow(by: y.denominator)
        let (den, o2) = x.denominator.multipliedReportingOverflow(by: y.numerator)
        guard !o1 && !o2
        else { throw EvaluatorError.invalidArgument(function: "/", message: "integer overflow in ratio arithmetic") }
        return ratioExpr(Ratio(num, den))
    }
}

private func coreIntPair(_ args: [Expr], function name: String) throws -> (Int, Int) {
    guard case .integer(let a) = args[0], case .integer(let b) = args[1] else {
        throw EvaluatorError.invalidArgument(function: name, message: "arguments must be integers")
    }
    return (a, b)
}

private func coreMod(_ args: [Expr]) throws -> Expr {
    let (a, b) = try coreIntPair(args, function: "mod")
    guard b != 0 else { throw EvaluatorError.invalidArgument(function: "mod", message: "division by zero") }
    let r = a % b
    return .integer(r == 0 ? 0 : (r < 0) != (b < 0) ? r + b : r)
}

private func coreRem(_ args: [Expr]) throws -> Expr {
    let (a, b) = try coreIntPair(args, function: "rem")
    guard b != 0 else { throw EvaluatorError.invalidArgument(function: "rem", message: "division by zero") }
    return .integer(a % b)
}

private func coreQuot(_ args: [Expr]) throws -> Expr {
    let (a, b) = try coreIntPair(args, function: "quot")
    guard b != 0 else { throw EvaluatorError.invalidArgument(function: "quot", message: "division by zero") }
    return .integer(a / b)
}

private func coreIsNumber(_ args: [Expr]) throws -> Expr {
    switch args[0] {
    case .integer, .float, .ratio: return .boolean(true)
    default: return .boolean(false)
    }
}

private func coreIsInteger(_ args: [Expr]) throws -> Expr {
    if case .integer = args[0] { return .boolean(true) }
    return .boolean(false)
}

private func coreIsFloat(_ args: [Expr]) throws -> Expr {
    if case .float = args[0] { return .boolean(true) }
    return .boolean(false)
}

private func coreIsRatio(_ args: [Expr]) throws -> Expr {
    if case .ratio = args[0] { return .boolean(true) }
    return .boolean(false)
}

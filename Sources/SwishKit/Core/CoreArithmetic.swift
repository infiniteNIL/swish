private let printer = Printer()

// MARK: - Registration

func registerArithmetic(into evaluator: Evaluator) {
    evaluator.register(name: "+", arity: .variadic, body: coreAdd)
    evaluator.register(name: "-", arity: .variadic, body: coreSubtract)
    evaluator.register(name: "*", arity: .variadic, body: coreMultiply)
    evaluator.register(name: "/", arity: .variadic, body: coreDivide)
}

// MARK: - Implementations

private func coreAdd(_ args: [Expr]) throws -> Expr {
    if args.isEmpty { return .integer(0) }
    if args.count == 1 { return try assertSingleNumeric(args[0], function: "+") }
    return try args.dropFirst().reduce(args[0]) { try numericAdd($0, $1) }
}

private func coreSubtract(_ args: [Expr]) throws -> Expr {
    if args.isEmpty {
        throw EvaluatorError.invalidArgument(function: "-", message: "requires at least 1 argument")
    }
    if args.count == 1 {
        switch args[0] {
        case .integer(let x):  return .integer(-x)
        case .float(let x):    return .float(-x)
        case .ratio(let x):    return .ratio(Ratio(-x.numerator, x.denominator))
        default:
            throw EvaluatorError.invalidArgument(
                function: "-", message: "expected a number, got \(printer.printString(args[0]))")
        }
    }
    return try args.dropFirst().reduce(args[0]) { try numericSubtract($0, $1) }
}

private func coreMultiply(_ args: [Expr]) throws -> Expr {
    if args.isEmpty { return .integer(1) }
    if args.count == 1 { return try assertSingleNumeric(args[0], function: "*") }
    return try args.dropFirst().reduce(args[0]) { try numericMultiply($0, $1) }
}

private func coreDivide(_ args: [Expr]) throws -> Expr {
    if args.isEmpty {
        throw EvaluatorError.invalidArgument(function: "/", message: "requires at least 1 argument")
    }
    if args.count == 1 {
        switch args[0] {
        case .integer(let x):
            if x == 0 { throw EvaluatorError.invalidArgument(function: "/", message: "division by zero") }
            let r = Ratio(1, x)
            return r.denominator == 1 ? .integer(r.numerator) : .ratio(r)
        case .float(let x):
            return .float(1.0 / x)
        case .ratio(let x):
            if x.numerator == 0 { throw EvaluatorError.invalidArgument(function: "/", message: "division by zero") }
            let r = Ratio(x.denominator, x.numerator)
            return r.denominator == 1 ? .integer(r.numerator) : .ratio(r)
        default:
            throw EvaluatorError.invalidArgument(
                function: "/", message: "expected a number, got \(printer.printString(args[0]))")
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
    case (.integer(let x), .integer(let y)): return .ints(x, y)
    case (.float(let x),   .float(let y)):   return .floats(x, y)
    case (.float(let x),   .integer(let y)): return .floats(x, Double(y))
    case (.integer(let x), .float(let y)):   return .floats(Double(x), y)
    case (.float(let x),   .ratio(let y)):   return .floats(x, Double(y.numerator) / Double(y.denominator))
    case (.ratio(let x),   .float(let y)):   return .floats(Double(x.numerator) / Double(x.denominator), y)
    case (.ratio(let x),   .ratio(let y)):   return .ratios(x, y)
    case (.ratio(let x),   .integer(let y)): return .ratios(x, Ratio(y, 1))
    case (.integer(let x), .ratio(let y)):   return .ratios(Ratio(x, 1), y)
    default:
        throw EvaluatorError.invalidArgument(
            function: function,
            message: "expected numbers, got \(printer.printString(a)) and \(printer.printString(b))")
    }
}

// MARK: - Numeric helpers

private func ratioExpr(_ r: Ratio) -> Expr {
    r.denominator == 1 ? .integer(r.numerator) : .ratio(r)
}

private func assertSingleNumeric(_ arg: Expr, function: String) throws -> Expr {
    switch arg {
    case .integer, .float, .ratio: return arg
    default:
        throw EvaluatorError.invalidArgument(
            function: function, message: "expected a number, got \(printer.printString(arg))")
    }
}

private func numericAdd(_ a: Expr, _ b: Expr) throws -> Expr {
    switch try coerceNumericPair(a, b, function: "+") {
    case .ints(let x, let y):   return .integer(x + y)
    case .floats(let x, let y): return .float(x + y)
    case .ratios(let x, let y):
        return ratioExpr(Ratio(x.numerator * y.denominator + y.numerator * x.denominator,
                               x.denominator * y.denominator))
    }
}

private func numericSubtract(_ a: Expr, _ b: Expr) throws -> Expr {
    switch try coerceNumericPair(a, b, function: "-") {
    case .ints(let x, let y):   return .integer(x - y)
    case .floats(let x, let y): return .float(x - y)
    case .ratios(let x, let y):
        return ratioExpr(Ratio(x.numerator * y.denominator - y.numerator * x.denominator,
                               x.denominator * y.denominator))
    }
}

private func numericMultiply(_ a: Expr, _ b: Expr) throws -> Expr {
    switch try coerceNumericPair(a, b, function: "*") {
    case .ints(let x, let y):   return .integer(x * y)
    case .floats(let x, let y): return .float(x * y)
    case .ratios(let x, let y):
        return ratioExpr(Ratio(x.numerator * y.numerator, x.denominator * y.denominator))
    }
}

private func numericDivide(_ a: Expr, _ b: Expr) throws -> Expr {
    switch try coerceNumericPair(a, b, function: "/") {
    case .ints(let x, let y):
        if y == 0 { throw EvaluatorError.invalidArgument(function: "/", message: "division by zero") }
        return ratioExpr(Ratio(x, y))
    case .floats(let x, let y):
        return .float(x / y)
    case .ratios(let x, let y):
        if y.numerator == 0 { throw EvaluatorError.invalidArgument(function: "/", message: "division by zero") }
        return ratioExpr(Ratio(x.numerator * y.denominator, x.denominator * y.numerator))
    }
}

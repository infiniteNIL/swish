import BigInt
import BigDecimal

// MARK: - Registration

func registerArithmetic(into evaluator: Evaluator) {
    evaluator.register(name: "+", arity: .variadic,
        doc: "Returns the sum of nums. (+) returns 0. Does not auto-promote longs, will throw on overflow. See also: +'",
        arglists: [[], ["x"], ["x", "y"], ["x", "y", "&", "more"]],
        body: coreAdd)
    evaluator.register(name: "-", arity: .variadic,
        doc: "If no ys are supplied, returns the negation of x, else subtracts the ys from x and returns the result. Does not auto-promote longs, will throw on overflow. See also: -'",
        arglists: [["x"], ["x", "y"], ["x", "y", "&", "more"]],
        body: coreSubtract)
    evaluator.register(name: "*", arity: .variadic,
        doc: "Returns the product of nums. (*) returns 1. Does not auto-promote longs, will throw on overflow. See also: *'",
        arglists: [[], ["x"], ["x", "y"], ["x", "y", "&", "more"]],
        body: coreMultiply)
    evaluator.register(name: "/", arity: .variadic,
        doc: "If no denominators are supplied, returns 1/numerator, else returns numerator divided by all of the denominators.",
        arglists: [["x"], ["x", "y"], ["x", "y", "&", "more"]],
        body: coreDivide)
    evaluator.register(name: "mod", arity: .fixed(2),
        doc: "Modulus of num and div. Truncates toward negative infinity.",
        arglists: [["num", "div"]],
        body: coreMod)
    evaluator.register(name: "rem", arity: .fixed(2),
        doc: "remainder of dividing numerator by denominator.",
        arglists: [["num", "div"]],
        body: coreRem)
    evaluator.register(name: "quot", arity: .fixed(2),
        doc: "quot[ient] of dividing numerator by denominator.",
        arglists: [["num", "div"]],
        body: coreQuot)
    evaluator.register(name: "number?",  arity: .fixed(1), doc: "Returns true if x is a Number",                     arglists: [["x"]]) { args in switch args[0] { case .integer, .float, .ratio, .bigInteger, .bigDecimal: return .boolean(true); default: return .boolean(false) } }
    evaluator.register(name: "integer?", arity: .fixed(1), doc: "Returns true if n is an integer",                   arglists: [["n"]]) { args in switch args[0] { case .integer, .bigInteger: return .boolean(true); default: return .boolean(false) } }
    evaluator.register(name: "int?",     arity: .fixed(1), doc: "Return true if x is a fixed-precision integer.",     arglists: [["x"]]) { args in if case .integer = args[0] { return .boolean(true) }; return .boolean(false) }
    evaluator.register(name: "float?",   arity: .fixed(1), doc: "Returns true if n is a floating point number",      arglists: [["n"]]) { args in if case .float   = args[0] { return .boolean(true) }; return .boolean(false) }
    evaluator.register(name: "ratio?",   arity: .fixed(1), doc: "Returns true if n is a Ratio",                      arglists: [["n"]]) { args in if case .ratio   = args[0] { return .boolean(true) }; return .boolean(false) }
    evaluator.register(name: "bigint?",  arity: .fixed(1), doc: "Returns true if n is an arbitrary-precision integer", arglists: [["n"]]) { args in if case .bigInteger = args[0] { return .boolean(true) }; return .boolean(false) }
    evaluator.register(name: "decimal?", arity: .fixed(1), doc: "Returns true if n is a BigDecimal",                 arglists: [["n"]]) { args in if case .bigDecimal = args[0] { return .boolean(true) }; return .boolean(false) }
    evaluator.register(name: "NaN?",     arity: .fixed(1), doc: "Returns true if num is NaN, else false.",           arglists: [["num"]]) { args in
        if case .float(let f) = args[0] { return .boolean(f.isNaN) }
        return .boolean(false)
    }
    evaluator.register(name: "int", arity: .fixed(1),
        doc: "Coerces x to a fixed-precision integer.",
        arglists: [["x"]],
        body: coreInt)
    evaluator.register(name: "rand", arity: .variadic,
        doc: "Returns a random floating point number between 0 (inclusive) and n (default 1) (exclusive).",
        arglists: [[], ["n"]]) { args in
        if args.isEmpty { return .float(Double.random(in: 0.0..<1.0)) }

        switch args[0] {
        case .integer(let n):
            return .float(Double.random(in: 0.0..<Double(n)))

        case .float(let n):
            return .float(Double.random(in: 0.0..<n))

        default:
            throw EvaluatorError.invalidArgument(function: "rand", message: "n must be a number")
        }
    }
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

        case .bigInteger(let x):
            return .bigInteger(-x)

        case .bigDecimal(let x):
            return .bigDecimal(-x)

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

        case .bigInteger(let x):
            if x == 0 { throw EvaluatorError.invalidArgument(function: "/", message: "division by zero") }
            return .bigDecimal(BigDecimal(integerLiteral: 1) / BigDecimal(integerValue: x, scale: 0))

        case .bigDecimal(let x):
            if x.isZero { throw EvaluatorError.invalidArgument(function: "/", message: "division by zero") }
            return .bigDecimal(BigDecimal(1) / x)

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
    case bigInts(BigInt, BigInt)
    case bigDecimals(BigDecimal, BigDecimal)
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

    // BigDecimal wins over all other types
    case (.bigDecimal(let x), .bigDecimal(let y)): return .bigDecimals(x, y)
    case (.bigDecimal(let x), .integer(let y)):    return .bigDecimals(x, BigDecimal(integerValue: BigInt(y), scale: 0))
    case (.integer(let x),    .bigDecimal(let y)): return .bigDecimals(BigDecimal(integerValue: BigInt(x), scale: 0), y)
    case (.bigDecimal(let x), .float(let y)):
        guard !y.isNaN && !y.isInfinite else { return .floats(Double(x.description) ?? 0.0, y) }
        return .bigDecimals(x, BigDecimal(floatLiteral: y))

    case (.float(let x), .bigDecimal(let y)):
        guard !x.isNaN && !x.isInfinite else { return .floats(x, Double(y.description) ?? 0.0) }
        return .bigDecimals(BigDecimal(floatLiteral: x), y)

    case (.bigDecimal(let x), .ratio(let y)):      return .bigDecimals(x, BigDecimal(integerValue: BigInt(y.numerator), scale: 0) / BigDecimal(integerValue: BigInt(y.denominator), scale: 0))

    case (.ratio(let x),      .bigDecimal(let y)): return .bigDecimals(BigDecimal(integerValue: BigInt(x.numerator), scale: 0) / BigDecimal(integerValue: BigInt(x.denominator), scale: 0), y)

    case (.bigDecimal(let x), .bigInteger(let y)): return .bigDecimals(x, BigDecimal(integerValue: y, scale: 0))
    case (.bigInteger(let x), .bigDecimal(let y)): return .bigDecimals(BigDecimal(integerValue: x, scale: 0), y)

    // BigInt wins over Int and Ratio; Double wins over BigInt
    case (.bigInteger(let x), .bigInteger(let y)): return .bigInts(x, y)
    case (.bigInteger(let x), .integer(let y)):    return .bigInts(x, BigInt(y))
    case (.integer(let x),    .bigInteger(let y)): return .bigInts(BigInt(x), y)
    case (.bigInteger(let x), .float(let y)):      return .floats(Double(x), y)
    case (.float(let x),      .bigInteger(let y)): return .floats(x, Double(y))
    case (.bigInteger(let x), .ratio(let y)):      return .floats(Double(x), Double(y.numerator) / Double(y.denominator))
    case (.ratio(let x),      .bigInteger(let y)): return .floats(Double(x.numerator) / Double(x.denominator), Double(y))

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
    case .integer, .float, .ratio, .bigInteger, .bigDecimal:
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

    case .bigInts(let x, let y):     return .bigInteger(x + y)
    case .bigDecimals(let x, let y): return .bigDecimal(x + y)
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

    case .bigInts(let x, let y):     return .bigInteger(x - y)
    case .bigDecimals(let x, let y): return .bigDecimal(x - y)
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

    case .bigInts(let x, let y):     return .bigInteger(x * y)
    case .bigDecimals(let x, let y): return .bigDecimal(x * y)
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

    case .bigInts(let x, let y):
        if y == 0 { throw EvaluatorError.invalidArgument(function: "/", message: "division by zero") }
        return .bigInteger(x / y)

    case .bigDecimals(let x, let y):
        if y.isZero { throw EvaluatorError.invalidArgument(function: "/", message: "division by zero") }
        return .bigDecimal(x / y)
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

private func coreInt(_ args: [Expr]) throws -> Expr {
    switch args[0] {
    case .integer:
        return args[0]

    case .bigInteger(let n):
        guard let i = Int(exactly: n) else {
            throw EvaluatorError.invalidArgument(function: "int", message: "value out of int range")
        }
        return .integer(i)

    case .float(let f):
        guard !f.isInfinite && !f.isNaN else {
            throw EvaluatorError.invalidArgument(function: "int", message: "cannot convert \(f) to integer")
        }
        return .integer(Int(f))

    case .bigDecimal(let d):
        let truncated = d.withScale(0)
        guard let i = Int(exactly: truncated.integerValue) else {
            throw EvaluatorError.invalidArgument(function: "int", message: "value out of int range")
        }
        return .integer(i)

    case .ratio(let r):
        return .integer(r.numerator / r.denominator)

    case .string(let s):
        guard let i = Int(s) else {
            throw EvaluatorError.invalidArgument(function: "int", message: "not a valid integer: \"\(s)\"")
        }
        return .integer(i)

    default:
        throw EvaluatorError.invalidArgument(
            function: "int", message: "cannot convert \(corePrinter.printString(args[0])) to integer")
    }
}


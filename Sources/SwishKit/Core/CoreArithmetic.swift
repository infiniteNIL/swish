import BigInt
import BigDecimal

private let divisionByZero = "division by zero"

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
    evaluator.register(name: "rem", arity: .fixed(2),
        doc: "remainder of dividing numerator by denominator.",
        arglists: [["num", "div"]],
        body: coreRem)
    evaluator.register(name: "quot", arity: .fixed(2),
        doc: "quot[ient] of dividing numerator by denominator.",
        arglists: [["num", "div"]],
        body: coreQuot)
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
    evaluator.register(name: "int", arity: .fixed(1),
        doc: "Coerces x to a fixed-precision integer.",
        arglists: [["x"]],
        body: coreInt)
    evaluator.register(name: "byte", arity: .fixed(1),
        doc: "Coerces x to a byte.",
        arglists: [["x"]],
        body: coreByte)
    evaluator.register(name: "num", arity: .fixed(1),
        doc: "Coerce to Number.",
        arglists: [["x"]],
        body: coreNum)
    evaluator.register(name: "long", arity: .fixed(1),
        doc: "Coerces x to a long.",
        arglists: [["x"]],
        body: coreLong)
    evaluator.register(name: "short", arity: .fixed(1),
        doc: "Coerces x to a short.",
        arglists: [["x"]],
        body: coreShort)
    evaluator.register(name: "char", arity: .fixed(1),
        doc: "Coerce to char. Accepts an integer Unicode code point or a character.",
        arglists: [["x"]],
        body: coreToChar)
    evaluator.register(name: "float", arity: .fixed(1),
        doc: "Coerces x to a 32-bit floating-point number.",
        arglists: [["x"]],
        body: coreToSingleFloat)
    evaluator.register(name: "double", arity: .fixed(1),
        doc: "Coerces x to a 64-bit floating-point number.",
        arglists: [["x"]],
        body: coreToFloat)
    evaluator.register(name: "bigint", arity: .fixed(1),
        doc: "Coerce to arbitrary-precision integer.",
        arglists: [["x"]],
        body: coreBigInt)
    evaluator.register(name: "bigdec", arity: .fixed(1),
        doc: "Coerce to BigDecimal.",
        arglists: [["x"]],
        body: coreBigDec)
    evaluator.register(name: "boolean", arity: .fixed(1),
        doc: "Coerce to boolean",
        arglists: [["x"]],
        body: coreBoolean)
    evaluator.register(name: "parse-boolean", arity: .fixed(1),
        doc: "Parse a string as a Boolean, returning true/false, or nil if not a valid Boolean.",
        arglists: [["s"]],
        body: coreParseBoolean)
    evaluator.register(name: "rand", arity: .variadic,
        doc: "Returns a random floating point number between 0 (inclusive) and n (default 1) (exclusive).",
        arglists: [[], ["n"]],
        body: coreRand)
    evaluator.register(name: "abs", arity: .fixed(1),
        doc: "Returns the absolute value of a. If a is Long/MIN_VALUE => Long/MIN_VALUE.",
        arglists: [["a"]],
        body: coreAbs)
    evaluator.register(name: "numerator", arity: .fixed(1),
        doc: "Returns the numerator part of a Ratio.",
        arglists: [["r"]],
        body: coreNumerator)
    evaluator.register(name: "denominator", arity: .fixed(1),
        doc: "Returns the denominator part of a Ratio.",
        arglists: [["r"]],
        body: coreDenominator)
    evaluator.register(name: "inc'", arity: .fixed(1),
        doc: "Returns a number one greater than x. Supports arbitrary precision. See also: inc",
        arglists: [["x"]],
        body: coreIncP)
    evaluator.register(name: "dec'", arity: .fixed(1),
        doc: "Returns a number one less than x. Supports arbitrary precision. See also: dec",
        arglists: [["x"]],
        body: coreDecP)
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

private func coreToChar(_ args: [Expr]) throws -> Expr {
    switch args[0] {
    case .character:
        return args[0]

    case .integer(let n):
        guard n >= 0, n <= 65535,
              let scalar = Unicode.Scalar(UInt32(n)) else {
            throw EvaluatorError.invalidArgument(function: "char",
                message: "Value out of range for char: \(n)")
        }
        return .character(Character(scalar))

    default:
        throw EvaluatorError.invalidArgument(function: "char",
            message: "Value out of range for char")
    }
}

private func coreRand(_ args: [Expr]) throws -> Expr {
    if args.isEmpty { return .double(Double.random(in: 0.0..<1.0)) }

    switch args[0] {
    case .integer(let n):
        return .double(Double.random(in: 0.0..<Double(n)))

    case .double(let n):
        return .double(Double.random(in: 0.0..<n))

    case .float(let n):
        return .double(Double.random(in: 0.0..<Double(n)))

    default:
        throw EvaluatorError.invalidArgument(function: "rand", message: "n must be a number")
    }
}

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

        case .double(let x):
            return .double(-x)

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
                throw EvaluatorError.invalidArgument(function: "/", message: divisionByZero)
            }
            return ratioExpr(Ratio(1, x))

        case .double(let x):
            return .double(1.0 / x)

        case .float(let x):
            return .float(1.0 / x)

        case .ratio(let x):
            if x.numerator == 0 {
                throw EvaluatorError.invalidArgument(function: "/", message: divisionByZero)
            }
            return ratioExpr(Ratio(x.denominator, x.numerator))

        case .bigInteger(let x):
            if x == 0 { throw EvaluatorError.invalidArgument(function: "/", message: divisionByZero) }
            return .bigDecimal(BigDecimal(integerLiteral: 1) / BigDecimal(integerValue: x, scale: 0))

        case .bigDecimal(let x):
            if x.isZero { throw EvaluatorError.invalidArgument(function: "/", message: divisionByZero) }
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
    // Normalize single-precision float to double before processing
    if case .float(let x) = a { return try coerceNumericPair(.double(Double(x)), b, function: function) }
    if case .float(let y) = b { return try coerceNumericPair(a, .double(Double(y)), function: function) }

    switch (a, b) {
    case (.integer(let x), .integer(let y)):
        return .ints(x, y)

    case (.double(let x), .double(let y)):
        return .floats(x, y)

    case (.double(let x), .integer(let y)):
        return .floats(x, Double(y))

    case (.integer(let x), .double(let y)):
        return .floats(Double(x), y)

    case (.double(let x), .ratio(let y)):
        return .floats(x, Double(y.numerator) / Double(y.denominator))

    case (.ratio(let x), .double(let y)):
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
    case (.bigDecimal(let x), .double(let y)):
        return .floats(Double(x.description) ?? 0.0, y)

    case (.double(let x), .bigDecimal(let y)):
        return .floats(x, Double(y.description) ?? 0.0)

    case (.bigDecimal(let x), .ratio(let y)):      return .bigDecimals(x, BigDecimal(integerValue: y.numerator, scale: 0) / BigDecimal(integerValue: y.denominator, scale: 0))

    case (.ratio(let x),      .bigDecimal(let y)): return .bigDecimals(BigDecimal(integerValue: x.numerator, scale: 0) / BigDecimal(integerValue: x.denominator, scale: 0), y)

    case (.bigDecimal(let x), .bigInteger(let y)): return .bigDecimals(x, BigDecimal(integerValue: y, scale: 0))
    case (.bigInteger(let x), .bigDecimal(let y)): return .bigDecimals(BigDecimal(integerValue: x, scale: 0), y)

    // BigInt wins over Int and Ratio; Double wins over BigInt
    case (.bigInteger(let x), .bigInteger(let y)): return .bigInts(x, y)
    case (.bigInteger(let x), .integer(let y)):    return .bigInts(x, BigInt(y))
    case (.integer(let x),    .bigInteger(let y)): return .bigInts(BigInt(x), y)
    case (.bigInteger(let x), .double(let y)):     return .floats(Double(x), y)
    case (.double(let x),     .bigInteger(let y)): return .floats(x, Double(y))
    case (.bigInteger(let x), .ratio(let y)):      return .ratios(Ratio(x, BigInt(1)), y)
    case (.ratio(let x),      .bigInteger(let y)): return .ratios(x, Ratio(y, BigInt(1)))

    default:
        throw EvaluatorError.invalidArgument(
            function: function,
            message: "expected numbers, got \(corePrinter.printString(a)) and \(corePrinter.printString(b))")
    }
}

// MARK: - Numeric helpers

private func ratioExpr(_ r: Ratio) -> Expr {
    guard r.denominator == 1 else { return .ratio(r) }
    if let i = Int(exactly: r.numerator) { return .integer(i) }
    return .bigInteger(r.numerator)
}

// Used for ratio+ratio arithmetic: when the result simplifies to a whole
// number, JVM Clojure returns BigInt (not Long) because the numerator/
// denominator are BigInteger objects throughout.
private func ratioExprBig(_ r: Ratio) -> Expr {
    guard r.denominator == 1 else { return .ratio(r) }
    return .bigInteger(r.numerator)
}

private func assertSingleNumeric(_ arg: Expr, function: String) throws -> Expr {
    switch arg {
    case .integer, .float, .double, .ratio, .bigInteger, .bigDecimal:
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
        return .double(x + y)

    case .ratios(let x, let y):
        return ratioExprBig(Ratio(x.numerator * y.denominator + y.numerator * x.denominator,
                                  x.denominator * y.denominator))

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
        return .double(x - y)

    case .ratios(let x, let y):
        return ratioExpr(Ratio(x.numerator * y.denominator - y.numerator * x.denominator,
                               x.denominator * y.denominator))

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
        return .double(x * y)

    case .ratios(let x, let y):
        return ratioExpr(Ratio(x.numerator * y.numerator, x.denominator * y.denominator))

    case .bigInts(let x, let y):     return .bigInteger(x * y)
    case .bigDecimals(let x, let y): return .bigDecimal(x * y)
    }
}

private func numericDivide(_ a: Expr, _ b: Expr) throws -> Expr {
    switch try coerceNumericPair(a, b, function: "/") {
    case .ints(let x, let y):
        if y == 0 {
            throw EvaluatorError.invalidArgument(function: "/", message: divisionByZero)
        }
        return ratioExpr(Ratio(x, y))

    case .floats(let x, let y):
        return .double(x / y)

    case .ratios(let x, let y):
        if y.numerator == 0 {
            throw EvaluatorError.invalidArgument(function: "/", message: divisionByZero)
        }
        return ratioExpr(Ratio(x.numerator * y.denominator, x.denominator * y.numerator))

    case .bigInts(let x, let y):
        if y == 0 { throw EvaluatorError.invalidArgument(function: "/", message: divisionByZero) }
        return .bigInteger(x / y)

    case .bigDecimals(let x, let y):
        if y.isZero { throw EvaluatorError.invalidArgument(function: "/", message: divisionByZero) }
        return .bigDecimal(x / y)
    }
}

private func extractIntLike(_ expr: Expr, function name: String) throws -> (BigInt, Bool) {
    switch expr {
    case .integer(let n):    return (BigInt(n), false)
    case .bigInteger(let n): return (n, true)
    default:
        throw EvaluatorError.invalidArgument(function: name, message: "arguments must be integers")
    }
}

private func coreRem(_ args: [Expr]) throws -> Expr {
    if case .float(let x) = args[0] { return try coreRem([.double(Double(x)), args[1]]) }
    if case .float(let y) = args[1] { return try coreRem([args[0], .double(Double(y))]) }
    if case .double(let a) = args[0], a.isInfinite || a.isNaN {
        throw EvaluatorError.invalidArgument(function: "rem",
            message: "No exact numeric value for Infinity or NaN")
    }
    if case .double(let b) = args[1] {
        if b.isNaN {
            throw EvaluatorError.invalidArgument(function: "rem",
                message: "No exact numeric value for NaN")
        }
        if b.isInfinite { return .double(.nan) }
    }
    switch (args[0], args[1]) {
    case (.double(let a), .double(let b)):
        guard b != 0 else { throw EvaluatorError.invalidArgument(function: "rem", message: divisionByZero) }
        return .double(a.truncatingRemainder(dividingBy: b))
    case (.double(let a), .integer(let b)):
        let fb = Double(b)
        guard fb != 0 else { throw EvaluatorError.invalidArgument(function: "rem", message: divisionByZero) }
        return .double(a.truncatingRemainder(dividingBy: fb))
    case (.integer(let a), .double(let b)):
        guard b != 0 else { throw EvaluatorError.invalidArgument(function: "rem", message: divisionByZero) }
        return .double(Double(a).truncatingRemainder(dividingBy: b))
    case (.bigDecimal(let a), .bigDecimal(let b)):
        guard !b.isZero else { throw EvaluatorError.invalidArgument(function: "rem", message: divisionByZero) }
        return .bigDecimal(a.remainder(dividingBy: b))
    case (.bigDecimal(let a), .integer(let b)):
        guard b != 0 else { throw EvaluatorError.invalidArgument(function: "rem", message: divisionByZero) }
        return .bigDecimal(a.remainder(dividingBy: BigDecimal(integerValue: BigInt(b), scale: 0)))
    case (.integer(let a), .bigDecimal(let b)):
        guard !b.isZero else { throw EvaluatorError.invalidArgument(function: "rem", message: divisionByZero) }
        return .bigDecimal(BigDecimal(integerValue: BigInt(a), scale: 0).remainder(dividingBy: b))
    case (.bigDecimal(let a), .double(let b)):
        guard b != 0 else { throw EvaluatorError.invalidArgument(function: "rem", message: divisionByZero) }
        return .double((Double(a.description) ?? 0.0).truncatingRemainder(dividingBy: b))
    case (.double(let a), .bigDecimal(let b)):
        let bd = Double(b.description) ?? 0.0
        guard bd != 0 else { throw EvaluatorError.invalidArgument(function: "rem", message: divisionByZero) }
        return .double(a.truncatingRemainder(dividingBy: bd))
    case (.ratio(let ra), .ratio(let rb)):
        return try ratioRem(ra, rb)
    case (.ratio(let ra), .integer(let b)):
        return try ratioRem(ra, Ratio(b, 1))
    case (.integer(let a), .ratio(let rb)):
        return try ratioRem(Ratio(a, 1), rb)
    case (.ratio(let ra), .bigInteger(let b)):
        return try ratioRem(ra, Ratio(b, BigInt(1)))
    case (.bigInteger(let a), .ratio(let rb)):
        return try ratioRem(Ratio(a, BigInt(1)), rb)
    default:
        break
    }
    let (a, aBig) = try extractIntLike(args[0], function: "rem")
    let (b, bBig) = try extractIntLike(args[1], function: "rem")
    guard b != 0 else { throw EvaluatorError.invalidArgument(function: "rem", message: divisionByZero) }
    return (aBig || bBig) ? .bigInteger(a % b) : .integer(Int(a % b))
}

private func ratioRem(_ ra: Ratio, _ rb: Ratio) throws -> Expr {
    guard rb.numerator != 0 else {
        throw EvaluatorError.invalidArgument(function: "rem", message: divisionByZero)
    }
    // q = truncate(ra / rb) via BigInt division (truncates toward zero)
    let q = (ra.numerator * rb.denominator) / (ra.denominator * rb.numerator)
    let rNum = ra.numerator * rb.denominator - q * rb.numerator * ra.denominator
    let rDen = ra.denominator * rb.denominator
    if rNum == 0 { return .bigInteger(BigInt(0)) }
    let r = Ratio(rNum, rDen)
    return r.denominator == 1 ? .bigInteger(r.numerator) : .ratio(r)
}

private func coreQuot(_ args: [Expr]) throws -> Expr {
    if case .float(let x) = args[0] { return try coreQuot([.double(Double(x)), args[1]]) }
    if case .float(let y) = args[1] { return try coreQuot([args[0], .double(Double(y))]) }
    if case .double(let a) = args[0], a.isInfinite || a.isNaN {
        throw EvaluatorError.invalidArgument(function: "quot",
            message: "No exact numeric value for Infinity or NaN")
    }
    if case .double(let b) = args[1], b.isNaN {
        throw EvaluatorError.invalidArgument(function: "quot",
            message: "No exact numeric value for NaN")
    }
    switch (args[0], args[1]) {
    // Double wins over all — (a/b) truncated toward zero
    case (.double(let a), .double(let b)):
        guard b != 0 else { throw EvaluatorError.invalidArgument(function: "quot", message: divisionByZero) }
        return .double((a / b).rounded(.towardZero))
    case (.double(let a), .integer(let b)):
        guard b != 0 else { throw EvaluatorError.invalidArgument(function: "quot", message: divisionByZero) }
        return .double((a / Double(b)).rounded(.towardZero))
    case (.integer(let a), .double(let b)):
        guard b != 0 else { throw EvaluatorError.invalidArgument(function: "quot", message: divisionByZero) }
        return .double((Double(a) / b).rounded(.towardZero))
    case (.double(let a), .bigDecimal(let b)):
        guard !b.isZero else { throw EvaluatorError.invalidArgument(function: "quot", message: divisionByZero) }
        return .double((a / (Double(b.description) ?? 0)).rounded(.towardZero))
    case (.bigDecimal(let a), .double(let b)):
        guard b != 0 else { throw EvaluatorError.invalidArgument(function: "quot", message: divisionByZero) }
        return .double(((Double(a.description) ?? 0) / b).rounded(.towardZero))
    // BigDecimal — (a - rem(a,b)) / b gives exact integral quotient
    case (.bigDecimal(let a), .bigDecimal(let b)):
        guard !b.isZero else { throw EvaluatorError.invalidArgument(function: "quot", message: divisionByZero) }
        return .bigDecimal((a - a.remainder(dividingBy: b)) / b)
    case (.bigDecimal(let a), .integer(let b)):
        guard b != 0 else { throw EvaluatorError.invalidArgument(function: "quot", message: divisionByZero) }
        let bd = BigDecimal(integerValue: BigInt(b), scale: 0)
        return .bigDecimal((a - a.remainder(dividingBy: bd)) / bd)
    case (.integer(let a), .bigDecimal(let b)):
        guard !b.isZero else { throw EvaluatorError.invalidArgument(function: "quot", message: divisionByZero) }
        let ad = BigDecimal(integerValue: BigInt(a), scale: 0)
        return .bigDecimal((ad - ad.remainder(dividingBy: b)) / b)
    // Ratio — truncate(ra/rb) via BigInt division → bigInteger
    case (.ratio(let ra), .ratio(let rb)):
        return try ratioQuot(ra, rb)
    case (.ratio(let ra), .integer(let b)):
        return try ratioQuot(ra, Ratio(b, 1))
    case (.integer(let a), .ratio(let rb)):
        return try ratioQuot(Ratio(a, 1), rb)
    case (.ratio(let ra), .bigInteger(let b)):
        return try ratioQuot(ra, Ratio(b, BigInt(1)))
    case (.bigInteger(let a), .ratio(let rb)):
        return try ratioQuot(Ratio(a, BigInt(1)), rb)
    default:
        break
    }
    let (a, aBig) = try extractIntLike(args[0], function: "quot")
    let (b, bBig) = try extractIntLike(args[1], function: "quot")
    guard b != 0 else { throw EvaluatorError.invalidArgument(function: "quot", message: divisionByZero) }
    return (aBig || bBig) ? .bigInteger(a / b) : .integer(Int(a / b))
}

private func ratioQuot(_ ra: Ratio, _ rb: Ratio) throws -> Expr {
    guard rb.numerator != 0 else {
        throw EvaluatorError.invalidArgument(function: "quot", message: divisionByZero)
    }
    let q = (ra.numerator * rb.denominator) / (ra.denominator * rb.numerator)
    return .bigInteger(q)
}

private func coreToFloat(_ args: [Expr]) throws -> Expr {
    switch args[0] {
    case .double:
        return args[0]

    case .float(let f):
        return .double(Double(f))

    case .integer(let n):
        return .double(Double(n))

    case .bigInteger(let n):
        return .double(Double(n))

    case .bigDecimal(let d):
        return .double(Double(d.description) ?? Double.nan)

    case .ratio(let r):
        return .double(Double(r.numerator) / Double(r.denominator))

    default:
        throw EvaluatorError.invalidArgument(
            function: "double",
            message: "cannot convert \(corePrinter.printString(args[0])) to double")
    }
}

private func coreToSingleFloat(_ args: [Expr]) throws -> Expr {
    switch args[0] {
    case .float:
        return args[0]

    case .double(let d):
        let f = Float(d)
        if f.isInfinite {
            throw EvaluatorError.invalidArgument(
                function: "float",
                message: "Value out of range for float: \(corePrinter.printString(args[0]))")
        }
        return .float(f)

    case .integer(let n):
        return .float(Float(n))

    case .bigInteger(let n):
        return .float(Float(Double(n)))

    case .bigDecimal(let d):
        return .float(Float(Double(d.description) ?? Double.nan))

    case .ratio(let r):
        return .float(Float(Double(r.numerator) / Double(r.denominator)))

    default:
        throw EvaluatorError.invalidArgument(
            function: "float",
            message: "cannot convert \(corePrinter.printString(args[0])) to float")
    }
}

private func coreInt(_ args: [Expr]) throws -> Expr {
    switch args[0] {
    case .integer(let n):
        guard n >= Int(Int32.min) && n <= Int(Int32.max) else {
            throw EvaluatorError.invalidArgument(function: "int", message: "value out of int range")
        }
        return args[0]

    case .bigInteger(let n):
        guard let i = Int(exactly: n), i >= Int(Int32.min) && i <= Int(Int32.max) else {
            throw EvaluatorError.invalidArgument(function: "int", message: "value out of int range")
        }
        return .integer(i)

    case .double(let f):
        guard !f.isInfinite && !f.isNaN else {
            throw EvaluatorError.invalidArgument(function: "int", message: "cannot convert \(f) to integer")
        }
        guard f >= Double(Int32.min) && f <= Double(Int32.max) else {
            throw EvaluatorError.invalidArgument(function: "int", message: "value out of int range")
        }
        return .integer(Int(Int32(f)))

    case .float(let f):
        guard !f.isInfinite && !f.isNaN else {
            throw EvaluatorError.invalidArgument(function: "int", message: "cannot convert \(f) to integer")
        }
        let d = Double(f)
        guard d >= Double(Int32.min) && d <= Double(Int32.max) else {
            throw EvaluatorError.invalidArgument(function: "int", message: "value out of int range")
        }
        return .integer(Int(Int32(f)))

    case .bigDecimal(let d):
        let truncated = d.withScale(0)
        guard let i = Int(exactly: truncated.integerValue), i >= Int(Int32.min) && i <= Int(Int32.max) else {
            throw EvaluatorError.invalidArgument(function: "int", message: "value out of int range")
        }
        return .integer(i)

    case .ratio(let r):
        let truncated = r.numerator / r.denominator
        guard let i = Int(exactly: truncated), i >= Int(Int32.min) && i <= Int(Int32.max) else {
            throw EvaluatorError.invalidArgument(function: "int", message: "value out of int range")
        }
        return .integer(i)

    default:
        throw EvaluatorError.invalidArgument(
            function: "int", message: "cannot convert \(corePrinter.printString(args[0])) to integer")
    }
}

private func coreByte(_ args: [Expr]) throws -> Expr {
    switch args[0] {
    case .integer(let n):
        guard n >= -128 && n <= 127 else {
            throw EvaluatorError.invalidArgument(function: "byte", message: "value out of byte range")
        }
        return args[0]

    case .bigInteger(let n):
        guard let i = Int(exactly: n), i >= -128 && i <= 127 else {
            throw EvaluatorError.invalidArgument(function: "byte", message: "value out of byte range")
        }
        return .integer(i)

    case .double(let f):
        guard !f.isInfinite && !f.isNaN else {
            throw EvaluatorError.invalidArgument(function: "byte", message: "cannot convert \(f) to byte")
        }
        guard f >= -128.0 && f <= 127.0 else {
            throw EvaluatorError.invalidArgument(function: "byte", message: "value out of byte range")
        }
        return .integer(Int(Int8(f)))

    case .float(let f):
        guard !f.isInfinite && !f.isNaN else {
            throw EvaluatorError.invalidArgument(function: "byte", message: "cannot convert \(f) to byte")
        }
        let d = Double(f)
        guard d >= -128.0 && d <= 127.0 else {
            throw EvaluatorError.invalidArgument(function: "byte", message: "value out of byte range")
        }
        return .integer(Int(Int8(f)))

    case .bigDecimal(let d):
        let truncated = d.withScale(0)
        guard let i = Int(exactly: truncated.integerValue), i >= -128 && i <= 127 else {
            throw EvaluatorError.invalidArgument(function: "byte", message: "value out of byte range")
        }
        return .integer(i)

    case .ratio(let r):
        let truncated = r.numerator / r.denominator
        guard let i = Int(exactly: truncated), i >= -128 && i <= 127 else {
            throw EvaluatorError.invalidArgument(function: "byte", message: "value out of byte range")
        }
        return .integer(i)

    default:
        throw EvaluatorError.invalidArgument(
            function: "byte", message: "cannot convert \(corePrinter.printString(args[0])) to byte")
    }
}

private func coreNum(_ args: [Expr]) throws -> Expr {
    switch args[0] {
    case .integer, .bigInteger, .double, .float, .bigDecimal, .ratio, .nil:
        return args[0]

    default:
        throw EvaluatorError.invalidArgument(
            function: "num", message: "cannot convert \(corePrinter.printString(args[0])) to Number")
    }
}

private func coreLong(_ args: [Expr]) throws -> Expr {
    switch args[0] {
    case .integer:
        return args[0]

    case .bigInteger(let n):
        guard let i = Int(exactly: n) else {
            throw EvaluatorError.invalidArgument(function: "long", message: "value out of long range")
        }
        return .integer(i)

    case .double(let f):
        guard !f.isInfinite && !f.isNaN else {
            throw EvaluatorError.invalidArgument(function: "long", message: "cannot convert \(f) to long")
        }
        guard let i = Int(exactly: f.rounded(.towardZero)) else {
            throw EvaluatorError.invalidArgument(function: "long", message: "value out of long range")
        }
        return .integer(i)

    case .float(let f):
        guard !f.isInfinite && !f.isNaN else {
            throw EvaluatorError.invalidArgument(function: "long", message: "cannot convert \(f) to long")
        }
        guard let i = Int(exactly: Double(f).rounded(.towardZero)) else {
            throw EvaluatorError.invalidArgument(function: "long", message: "value out of long range")
        }
        return .integer(i)

    case .bigDecimal(let d):
        let truncated = d.withScale(0)
        guard let i = Int(exactly: truncated.integerValue) else {
            throw EvaluatorError.invalidArgument(function: "long", message: "value out of long range")
        }
        return .integer(i)

    case .ratio(let r):
        let truncated = r.numerator / r.denominator
        guard let i = Int(exactly: truncated) else {
            throw EvaluatorError.invalidArgument(function: "long", message: "value out of long range")
        }
        return .integer(i)

    default:
        throw EvaluatorError.invalidArgument(
            function: "long", message: "cannot convert \(corePrinter.printString(args[0])) to long")
    }
}

private func coreShort(_ args: [Expr]) throws -> Expr {
    switch args[0] {
    case .integer(let n):
        guard n >= Int(Int16.min) && n <= Int(Int16.max) else {
            throw EvaluatorError.invalidArgument(function: "short", message: "value out of short range")
        }
        return args[0]

    case .bigInteger(let n):
        guard let i = Int(exactly: n), i >= Int(Int16.min) && i <= Int(Int16.max) else {
            throw EvaluatorError.invalidArgument(function: "short", message: "value out of short range")
        }
        return .integer(i)

    case .double(let f):
        guard !f.isInfinite && !f.isNaN else {
            throw EvaluatorError.invalidArgument(function: "short", message: "cannot convert \(f) to short")
        }
        guard f >= Double(Int16.min) && f <= Double(Int16.max) else {
            throw EvaluatorError.invalidArgument(function: "short", message: "value out of short range")
        }
        return .integer(Int(Int16(f)))

    case .float(let f):
        guard !f.isInfinite && !f.isNaN else {
            throw EvaluatorError.invalidArgument(function: "short", message: "cannot convert \(f) to short")
        }
        let d = Double(f)
        guard d >= Double(Int16.min) && d <= Double(Int16.max) else {
            throw EvaluatorError.invalidArgument(function: "short", message: "value out of short range")
        }
        return .integer(Int(Int16(f)))

    case .bigDecimal(let d):
        let truncated = d.withScale(0)
        guard let i = Int(exactly: truncated.integerValue), i >= Int(Int16.min) && i <= Int(Int16.max) else {
            throw EvaluatorError.invalidArgument(function: "short", message: "value out of short range")
        }
        return .integer(i)

    case .ratio(let r):
        let truncated = r.numerator / r.denominator
        guard let i = Int(exactly: truncated), i >= Int(Int16.min) && i <= Int(Int16.max) else {
            throw EvaluatorError.invalidArgument(function: "short", message: "value out of short range")
        }
        return .integer(i)

    default:
        throw EvaluatorError.invalidArgument(
            function: "short", message: "cannot convert \(corePrinter.printString(args[0])) to short")
    }
}

private func coreAbs(_ args: [Expr]) throws -> Expr {
    switch args[0] {
    case .integer(let x):
        // Per Clojure spec: abs(Long/MIN_VALUE) == Long/MIN_VALUE (2's complement)
        if x == Int.min { return .integer(Int.min) }
        return .integer(x < 0 ? -x : x)

    case .double(let x):
        // Swift abs handles -0.0 → +0.0, ±Inf → +Inf, NaN → NaN correctly
        return .double(Swift.abs(x))

    case .float(let x):
        return .float(Swift.abs(x))

    case .ratio(let r):
        // Ratio always has a positive denominator; just abs the numerator
        return .ratio(Ratio(r.numerator < 0 ? -r.numerator : r.numerator, r.denominator))

    case .bigInteger(let x):
        return .bigInteger(x < 0 ? -x : x)

    case .bigDecimal(let x):
        return .bigDecimal(x < 0 ? -x : x)

    default:
        throw EvaluatorError.invalidArgument(
            function: "abs",
            message: "expected a number, got \(corePrinter.printString(args[0]))")
    }
}

private func coreNumerator(_ args: [Expr]) throws -> Expr {
    switch args[0] {
    case .ratio(let r):
        if let i = Int(exactly: r.numerator) { return .integer(i) }
        return .bigInteger(r.numerator)

    default:
        throw EvaluatorError.invalidArgument(
            function: "numerator",
            message: "not a ratio, got \(corePrinter.printString(args[0]))")
    }
}

private func coreDenominator(_ args: [Expr]) throws -> Expr {
    switch args[0] {
    case .ratio(let r):
        if let i = Int(exactly: r.denominator) { return .integer(i) }
        return .bigInteger(r.denominator)

    default:
        throw EvaluatorError.invalidArgument(
            function: "denominator",
            message: "not a ratio, got \(corePrinter.printString(args[0]))")
    }
}

private func coreBigInt(_ args: [Expr]) throws -> Expr {
    switch args[0] {
    case .bigInteger:
        return args[0]

    case .integer(let n):
        return .bigInteger(BigInt(n))

    case .double(let d):
        guard !d.isNaN, !d.isInfinite, let bd = BigDecimal(d) else {
            throw EvaluatorError.invalidArgument(function: "bigint", message: "cannot convert \(d) to bigint")
        }
        return .bigInteger(bd.withScale(0).integerValue)

    case .float(let f):
        return try coreBigInt([.double(Double(f))])

    case .bigDecimal(let d):
        return .bigInteger(d.withScale(0).integerValue)

    case .ratio(let r):
        return .bigInteger(r.numerator / r.denominator)

    case .string(let s):
        guard let v = BigInt(s) else {
            throw EvaluatorError.invalidArgument(function: "bigint", message: "invalid number: \(s)")
        }
        return .bigInteger(v)

    default:
        throw EvaluatorError.invalidArgument(
            function: "bigint", message: "cannot convert \(corePrinter.printString(args[0])) to bigint")
    }
}

private func coreBigDec(_ args: [Expr]) throws -> Expr {
    switch args[0] {
    case .bigDecimal:
        return args[0]

    case .integer(let n):
        return .bigDecimal(BigDecimal(integerValue: BigInt(n), scale: 0))

    case .bigInteger(let n):
        return .bigDecimal(BigDecimal(integerValue: n, scale: 0))

    case .double(let d):
        guard let v = BigDecimal(d) else {
            throw EvaluatorError.invalidArgument(function: "bigdec", message: "cannot convert \(d) to bigdec")
        }
        return .bigDecimal(v)

    case .float(let f):
        return try coreBigDec([.double(Double(f))])

    case .ratio(let r):
        return .bigDecimal(BigDecimal(integerValue: r.numerator, scale: 0) / BigDecimal(integerValue: r.denominator, scale: 0))

    case .string(let s):
        guard let v = BigDecimal(s) else {
            throw EvaluatorError.invalidArgument(function: "bigdec", message: "invalid number: \(s)")
        }
        return .bigDecimal(v)

    default:
        throw EvaluatorError.invalidArgument(
            function: "bigdec", message: "cannot convert \(corePrinter.printString(args[0])) to bigdec")
    }
}

private func coreBoolean(_ args: [Expr]) throws -> Expr {
    switch args[0] {
    case .nil, .boolean(false):
        return .boolean(false)

    default:
        return .boolean(true)
    }
}

private func coreParseBoolean(_ args: [Expr]) throws -> Expr {
    guard case .string(let s) = args[0] else {
        throw EvaluatorError.invalidArgument(function: "parse-boolean",
            message: "expected a string, got \(corePrinter.printString(args[0]))")
    }
    switch s {
    case "true":
        return .boolean(true)

    case "false":
        return .boolean(false)

    default:
        return .nil
    }
}

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


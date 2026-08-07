import BigInt
import BigDecimal

private let divisionByZero = "division by zero"

// MARK: - Registration

func registerArithmeticBasic(into evaluator: Evaluator) {
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
}

// MARK: - Implementations

/// Fast path for the common case where every argument is already `.integer` —
/// skips `coerceNumericPair`'s full numeric-tower dispatch per pairwise step.
/// Returns `nil` the moment any argument isn't `.integer`, so the caller falls
/// back to the general numeric-tower reduce unchanged (same overflow-error shape
/// either way). Not used by `/`, which isn't closed over `Int` (`(/ 10 3)` is a
/// `Ratio`), so a mid-reduce step can leave `Int` territory in a way `+`/`-`/`*` never do.
private func fastAllIntegerReduce(
    _ args: [Expr], operation: String,
    combine: (Int, Int) -> (partialValue: Int, overflow: Bool)
) throws -> Expr? {
    guard case .integer(let first) = args[0] else { return nil }
    var acc = first
    for arg in args.dropFirst() {
        guard case .integer(let x) = arg else { return nil }
        let (result, overflow) = combine(acc, x)
        if overflow { throw EvaluatorError.integerOverflow(operation: operation, lhs: acc, rhs: x) }
        acc = result
    }
    return .integer(acc)
}

func coreAdd(_ args: [Expr]) throws -> Expr {
    if args.isEmpty {
        return .integer(0)
    }

    if args.count == 1 {
        return try coreNum([args[0]])
    }

    if let fast = try fastAllIntegerReduce(args, operation: "+", combine: { $0.addingReportingOverflow($1) }) {
        return fast
    }

    return try args.dropFirst().reduce(args[0]) { try numericAdd($0, $1) }
}

func coreSubtract(_ args: [Expr]) throws -> Expr {
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

    if let fast = try fastAllIntegerReduce(args, operation: "-", combine: { $0.subtractingReportingOverflow($1) }) {
        return fast
    }

    return try args.dropFirst().reduce(args[0]) { try numericSubtract($0, $1) }
}

private func coreMultiply(_ args: [Expr]) throws -> Expr {
    if args.isEmpty {
        return .integer(1)
    }
    if args.count == 1 {
        return try coreNum([args[0]])
    }
    if let fast = try fastAllIntegerReduce(args, operation: "*", combine: { $0.multipliedReportingOverflow(by: $1) }) {
        return fast
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

/// Shared dispatch backing `+`/`+'` — identical except how an `Int` overflow on the
/// `.ints` branch is handled (plain `+` throws; `+'` auto-promotes to `BigInt`).
func numericAddImpl(_ a: Expr, _ b: Expr, function: String, onIntOverflow: (Int, Int) throws -> Expr) throws -> Expr {
    switch try coerceNumericPair(a, b, function: function) {
    case .ints(let x, let y):
        let (result, overflow) = x.addingReportingOverflow(y)
        if overflow { return try onIntOverflow(x, y) }
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

private func numericAdd(_ a: Expr, _ b: Expr) throws -> Expr {
    try numericAddImpl(a, b, function: "+") { x, y in
        throw EvaluatorError.integerOverflow(operation: "+", lhs: x, rhs: y)
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

/// Shared dispatch backing `*`/`*'` — identical except how an `Int` overflow on the
/// `.ints` branch is handled (plain `*` throws; `*'` auto-promotes to `BigInt`).
func numericMultiplyImpl(_ a: Expr, _ b: Expr, function: String, onIntOverflow: (Int, Int) throws -> Expr) throws -> Expr {
    switch try coerceNumericPair(a, b, function: function) {
    case .ints(let x, let y):
        let (result, overflow) = x.multipliedReportingOverflow(by: y)
        if overflow { return try onIntOverflow(x, y) }
        return .integer(result)

    case .floats(let x, let y):
        return .double(x * y)

    case .ratios(let x, let y):
        return ratioExpr(Ratio(x.numerator * y.numerator, x.denominator * y.denominator))

    case .bigInts(let x, let y):     return .bigInteger(x * y)
    case .bigDecimals(let x, let y): return .bigDecimal(x * y)
    }
}

private func numericMultiply(_ a: Expr, _ b: Expr) throws -> Expr {
    try numericMultiplyImpl(a, b, function: "*") { x, y in
        throw EvaluatorError.integerOverflow(operation: "*", lhs: x, rhs: y)
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

private func requireNonZeroDivisor(_ divisorIsZero: Bool, function: String) throws {
    guard !divisorIsZero else {
        throw EvaluatorError.invalidArgument(function: function, message: divisionByZero)
    }
}

/// The shared `rem`/`quot` operand prologue: normalize `.float` to `.double` (so the
/// numeric tower sees one float type), then reject the operands neither has an exact
/// answer for — a non-finite dividend, or a NaN divisor.
///
/// An *infinite divisor* is deliberately left to the caller: `rem` answers NaN, while
/// `quot` answers 0.0 through the ordinary float path, so they genuinely disagree.
private func remQuotOperands(_ args: [Expr], function: String) throws -> (Expr, Expr) {
    var a = args[0]
    var b = args[1]
    if case .float(let f) = a {
        a = .double(Double(f))
    }
    if case .float(let f) = b {
        b = .double(Double(f))
    }
    if case .double(let x) = a, x.isInfinite || x.isNaN {
        throw EvaluatorError.invalidArgument(function: function,
            message: "No exact numeric value for Infinity or NaN")
    }
    if case .double(let y) = b, y.isNaN {
        throw EvaluatorError.invalidArgument(function: function,
            message: "No exact numeric value for NaN")
    }
    return (a, b)
}

/// `rem` over the shared numeric tower. This used to hand-roll its own ~15-case pairwise
/// `switch (args[0], args[1])`, duplicating `coerceNumericPair` and spelling the
/// division-by-zero guard out once per branch. Routing through the tower also closed a
/// gap: the pairs it had no explicit case for — bigInteger×double and
/// bigInteger×bigDecimal — used to fall through to an integers-only extractor and throw
/// "arguments must be integers", where Clojure returns a value (`(rem 10N 3.0)` => 1.0).
private func coreRem(_ args: [Expr]) throws -> Expr {
    let (a, b) = try remQuotOperands(args, function: "rem")
    if case .double(let divisor) = b, divisor.isInfinite {
        return .double(.nan)
    }
    switch try coerceNumericPair(a, b, function: "rem") {
    case .ints(let x, let y):
        try requireNonZeroDivisor(y == 0, function: "rem")
        return .integer(x % y)

    case .floats(let x, let y):
        try requireNonZeroDivisor(y == 0, function: "rem")
        return .double(x.truncatingRemainder(dividingBy: y))

    case .ratios(let x, let y):
        return try ratioRem(x, y)

    case .bigInts(let x, let y):
        try requireNonZeroDivisor(y == 0, function: "rem")
        return .bigInteger(x % y)

    case .bigDecimals(let x, let y):
        try requireNonZeroDivisor(y.isZero, function: "rem")
        return .bigDecimal(x.remainder(dividingBy: y))
    }
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

/// `quot` over the shared numeric tower — the `rem` rewrite's twin (see there for the
/// duplication removed and the bigInteger×double / bigInteger×bigDecimal gap closed).
/// Unlike `rem`, an infinite divisor needs no special case: it falls through the
/// ordinary float path to 0.0, which is what Clojure returns.
private func coreQuot(_ args: [Expr]) throws -> Expr {
    let (a, b) = try remQuotOperands(args, function: "quot")
    switch try coerceNumericPair(a, b, function: "quot") {
    case .ints(let x, let y):
        try requireNonZeroDivisor(y == 0, function: "quot")
        return .integer(x / y)

    case .floats(let x, let y):
        try requireNonZeroDivisor(y == 0, function: "quot")
        return .double((x / y).rounded(.towardZero))

    case .ratios(let x, let y):
        return try ratioQuot(x, y)

    case .bigInts(let x, let y):
        try requireNonZeroDivisor(y == 0, function: "quot")
        return .bigInteger(x / y)

    case .bigDecimals(let x, let y):
        // (a - rem(a,b)) / b gives the exact integral quotient without rounding.
        try requireNonZeroDivisor(y.isZero, function: "quot")
        return .bigDecimal((x - x.remainder(dividingBy: y)) / y)
    }
}

private func ratioQuot(_ ra: Ratio, _ rb: Ratio) throws -> Expr {
    guard rb.numerator != 0 else {
        throw EvaluatorError.invalidArgument(function: "quot", message: divisionByZero)
    }
    let q = (ra.numerator * rb.denominator) / (ra.denominator * rb.numerator)
    return .bigInteger(q)
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

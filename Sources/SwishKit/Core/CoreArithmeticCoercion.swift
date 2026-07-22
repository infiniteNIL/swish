import BigInt
import BigDecimal

// MARK: - Registration

func registerArithmeticCoercion(into evaluator: Evaluator) {
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
    evaluator.register(name: "rationalize", arity: .fixed(1),
        doc: "returns the rational value of num",
        arglists: [["num"]],
        body: coreRationalize)
    evaluator.register(name: "boolean", arity: .fixed(1),
        doc: "Coerce to boolean",
        arglists: [["x"]],
        body: coreBoolean)
}

// MARK: - Implementations

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

/// Guards a floating-point argument is finite before a native numeric-coercion
/// function truncates it. Generic over `BinaryFloatingPoint` so the error message
/// interpolates the original `Float`/`Double` value with its own type's formatting
/// (promoting to `Double` first would print extra artifact digits for some `Float`s).
private func requireFinite<T: BinaryFloatingPoint>(_ f: T, function: String, typeLabel: String) throws -> T {
    guard !f.isInfinite && !f.isNaN else {
        throw EvaluatorError.invalidArgument(function: function, message: "cannot convert \(f) to \(typeLabel)")
    }
    return f
}

/// Shared implementation backing `int`/`byte`/`short` — coerces to an `Int`-backed
/// integer within `[min, max]`, mirroring real Clojure's fixed-width truncation
/// (`long` is deliberately not routed through this: it has no range to check,
/// only overflow, and uses `Int(exactly:)` rounding rather than a bounds guard).
private func coerceToRangedInteger(_ args: [Expr], function: String, typeLabel: String, min: Int, max: Int) throws -> Expr {
    switch args[0] {
    case .integer(let n):
        guard n >= min && n <= max else {
            throw EvaluatorError.invalidArgument(function: function, message: "value out of \(typeLabel) range")
        }
        return args[0]

    case .bigInteger(let n):
        guard let i = Int(exactly: n), i >= min && i <= max else {
            throw EvaluatorError.invalidArgument(function: function, message: "value out of \(typeLabel) range")
        }
        return .integer(i)

    case .double(let f):
        let f = try requireFinite(f, function: function, typeLabel: typeLabel)
        guard f >= Double(min) && f <= Double(max) else {
            throw EvaluatorError.invalidArgument(function: function, message: "value out of \(typeLabel) range")
        }
        return .integer(Int(f))

    case .float(let f):
        let f = try requireFinite(f, function: function, typeLabel: typeLabel)
        guard Double(f) >= Double(min) && Double(f) <= Double(max) else {
            throw EvaluatorError.invalidArgument(function: function, message: "value out of \(typeLabel) range")
        }
        return .integer(Int(f))

    case .bigDecimal(let d):
        let truncated = d.withScale(0)
        guard let i = Int(exactly: truncated.integerValue), i >= min && i <= max else {
            throw EvaluatorError.invalidArgument(function: function, message: "value out of \(typeLabel) range")
        }
        return .integer(i)

    case .ratio(let r):
        let truncated = r.numerator / r.denominator
        guard let i = Int(exactly: truncated), i >= min && i <= max else {
            throw EvaluatorError.invalidArgument(function: function, message: "value out of \(typeLabel) range")
        }
        return .integer(i)

    default:
        throw EvaluatorError.invalidArgument(
            function: function, message: "cannot convert \(corePrinter.printString(args[0])) to \(typeLabel)")
    }
}

private func coreInt(_ args: [Expr]) throws -> Expr {
    // `int` uniquely also accepts characters (their Unicode scalar value) — byte/short don't.
    if case .character(let c) = args[0] {
        guard c.unicodeScalars.count == 1, let scalar = c.unicodeScalars.first else {
            throw EvaluatorError.invalidArgument(
                function: "int", message: "cannot convert \(corePrinter.printString(args[0])) to integer")
        }
        return .integer(Int(scalar.value))
    }
    return try coerceToRangedInteger(args, function: "int", typeLabel: "integer", min: Int(Int32.min), max: Int(Int32.max))
}

private func coreByte(_ args: [Expr]) throws -> Expr {
    try coerceToRangedInteger(args, function: "byte", typeLabel: "byte", min: -128, max: 127)
}

func coreNum(_ args: [Expr]) throws -> Expr {
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
        let f = try requireFinite(f, function: "long", typeLabel: "long")
        guard let i = Int(exactly: f.rounded(.towardZero)) else {
            throw EvaluatorError.invalidArgument(function: "long", message: "value out of long range")
        }
        return .integer(i)

    case .float(let f):
        let f = try requireFinite(f, function: "long", typeLabel: "long")
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
    try coerceToRangedInteger(args, function: "short", typeLabel: "short", min: Int(Int16.min), max: Int(Int16.max))
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

private func coreRationalize(_ args: [Expr]) throws -> Expr {
    switch args[0] {
    case .integer, .bigInteger, .ratio:
        return args[0]

    case .double(let d):
        guard let bd = BigDecimal(d) else {
            throw EvaluatorError.invalidArgument(function: "rationalize",
                message: "cannot convert \(d) to a rational")
        }
        return rationalizeBigDecimal(bd)

    case .float(let f):
        return try coreRationalize([.double(Double(f))])

    case .bigDecimal(let bd):
        return rationalizeBigDecimal(bd)

    default:
        throw EvaluatorError.invalidArgument(function: "rationalize",
            message: "expected a number, got \(corePrinter.printString(args[0]))")
    }
}

// Mirrors clojure.lang.Numbers.rationalize's BigDecimal branch: unscaledValue
// over 10^scale, GCD-reduced. When the reduced denominator is 1, the JVM
// always returns a BigInt (never demotes to a plain Long), so this always
// produces .bigInteger rather than .integer in that case too.
private func rationalizeBigDecimal(_ bd: BigDecimal) -> Expr {
    let bv = bd.integerValue
    let scale = bd.scale
    if scale < 0 {
        return .bigInteger(bv * BigInt(10).power(-scale))
    }
    let ratio = Ratio(bv, BigInt(10).power(scale))
    return ratio.denominator == 1 ? .bigInteger(ratio.numerator) : .ratio(ratio)
}

private func coreBoolean(_ args: [Expr]) throws -> Expr {
    switch args[0] {
    case .nil, .boolean(false):
        return .boolean(false)

    default:
        return .boolean(true)
    }
}

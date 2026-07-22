import Foundation

// MARK: - Registration

func registerArithmeticParsing(into evaluator: Evaluator) {
    evaluator.register(name: "parse-boolean", arity: .fixed(1),
        doc: "Parse a string as a Boolean, returning true/false, or nil if not a valid Boolean.",
        arglists: [["s"]],
        body: coreParseBoolean)
    evaluator.register(name: "parse-long", arity: .fixed(1),
        doc: "Parse string of decimal digits with optional leading -/+ and return a Long value, or nil if parse fails.",
        arglists: [["s"]],
        body: coreParseLong)
    evaluator.register(name: "parse-double", arity: .fixed(1),
        doc: "Parse string with floating point components and return a Double value, or nil if parse fails.",
        arglists: [["s"]],
        body: coreParseDouble)
    evaluator.register(name: "parse-uuid", arity: .fixed(1),
        doc: "Parse a string representing a UUID and return a UUID instance, or nil if parse fails.",
        arglists: [["s"]],
        body: coreParseUUID)
    evaluator.register(name: "random-uuid", arity: .fixed(0),
        doc: "Returns a pseudo-randomly generated java.util.UUID instance (i.e. type 4).",
        arglists: [[]]) { _ in
        .uuid(UUID())
    }
    evaluator.register(name: "rand", arity: .variadic,
        doc: "Returns a random floating point number between 0 (inclusive) and n (default 1) (exclusive).",
        arglists: [[], ["n"]],
        body: coreRand)
}

// MARK: - Implementations

private func coreRand(_ args: [Expr]) throws -> Expr {
    // Matches real Clojure's (* n (rand)) — n * Math.random(), not Double.random(in: 0..<n),
    // since the latter traps on an empty/inverted range when n is 0 or negative.
    let unit = Double.random(in: 0.0..<1.0)
    if args.isEmpty { return .double(unit) }

    switch args[0] {
    case .integer(let n):
        return .double(Double(n) * unit)

    case .double(let n):
        return .double(n * unit)

    case .float(let n):
        return .double(Double(n) * unit)

    default:
        throw EvaluatorError.invalidArgument(function: "rand", message: "n must be a number")
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

private func coreParseLong(_ args: [Expr]) throws -> Expr {
    guard case .string(let s) = args[0] else {
        throw EvaluatorError.invalidArgument(function: "parse-long",
            message: "expected a string, got \(corePrinter.printString(args[0]))")
    }
    guard let i = Int(s) else { return .nil }
    return .integer(i)
}

private func coreParseDouble(_ args: [Expr]) throws -> Expr {
    guard case .string(let s) = args[0] else {
        throw EvaluatorError.invalidArgument(function: "parse-double",
            message: "expected a string, got \(corePrinter.printString(args[0]))")
    }
    guard let d = Double(s) else { return .nil }
    return .double(d)
}

private func coreParseUUID(_ args: [Expr]) throws -> Expr {
    guard case .string(let s) = args[0] else {
        throw EvaluatorError.invalidArgument(function: "parse-uuid",
            message: "expected a string, got \(corePrinter.printString(args[0]))")
    }
    guard let uuid = UUID(uuidString: s) else { return .nil }
    return .uuid(uuid)
}

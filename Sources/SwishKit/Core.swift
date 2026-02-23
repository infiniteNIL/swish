/// Registers all built-in functions into the evaluator's core environment.
func registerCoreFunctions(into evaluator: Evaluator) {
    // MARK: - Arithmetic

    evaluator.register(name: "+", arity: .variadic) { args in
        if args.isEmpty { return .integer(0) }
        if args.count == 1 {
            switch args[0] {
            case .integer, .float, .ratio:
                return args[0]
            default:
                throw EvaluatorError.invalidArgument(
                    function: "+", message: "expected a number, got \(Printer().printString(args[0]))")
            }
        }
        return try args.dropFirst().reduce(args[0]) { try numericAdd($0, $1) }
    }
}

// MARK: - Numeric helpers

private func numericAdd(_ a: Expr, _ b: Expr) throws -> Expr {
    switch (a, b) {
    case (.integer(let x), .integer(let y)):
        return .integer(x + y)

    case (.float(let x), .float(let y)):
        return .float(x + y)

    case (.float(let x), .integer(let y)):
        return .float(x + Double(y))

    case (.integer(let x), .float(let y)):
        return .float(Double(x) + y)

    case (.float(let x), .ratio(let y)):
        return .float(x + Double(y.numerator) / Double(y.denominator))

    case (.ratio(let x), .float(let y)):
        return .float(Double(x.numerator) / Double(x.denominator) + y)

    case (.ratio(let x), .ratio(let y)):
        let r = Ratio(x.numerator * y.denominator + y.numerator * x.denominator,
                      x.denominator * y.denominator)
        return r.denominator == 1 ? .integer(r.numerator) : .ratio(r)

    case (.ratio(let x), .integer(let y)):
        let r = Ratio(x.numerator + y * x.denominator, x.denominator)
        return r.denominator == 1 ? .integer(r.numerator) : .ratio(r)

    case (.integer(let x), .ratio(let y)):
        let r = Ratio(x * y.denominator + y.numerator, y.denominator)
        return r.denominator == 1 ? .integer(r.numerator) : .ratio(r)

    default:
        let p = Printer()
        throw EvaluatorError.invalidArgument(
            function: "+", message: "expected numbers, got \(p.printString(a)) and \(p.printString(b))")
    }
}

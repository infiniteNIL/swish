private let printer = Printer()

/// Registers all built-in functions into the evaluator's core environment.
func registerCoreFunctions(into evaluator: Evaluator) {
    registerArithmetic(into: evaluator)
    registerComparison(into: evaluator)
    registerMacros(into: evaluator)
    registerIO(into: evaluator)
}

// MARK: - Arithmetic

private func registerArithmetic(into evaluator: Evaluator) {
    evaluator.register(name: "+", arity: .variadic, body: coreAdd)
    evaluator.register(name: "-", arity: .variadic, body: coreSubtract)
    evaluator.register(name: "*", arity: .variadic, body: coreMultiply)
    evaluator.register(name: "/", arity: .variadic, body: coreDivide)
}

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

// MARK: - Comparison

private func registerComparison(into evaluator: Evaluator) {
    evaluator.register(name: "<",    arity: .atLeastOne, body: coreLessThan)
    evaluator.register(name: ">",    arity: .atLeastOne, body: coreGreaterThan)
    evaluator.register(name: "<=",   arity: .atLeastOne, body: coreLessOrEqual)
    evaluator.register(name: ">=",   arity: .atLeastOne, body: coreGreaterOrEqual)
    evaluator.register(name: "=",    arity: .atLeastOne, body: coreEqual)
    evaluator.register(name: "not=", arity: .atLeastOne, body: coreNotEqual)
}

private func coreLessThan(_ args: [Expr]) throws -> Expr {
    if args.count == 1 { return .boolean(true) }
    return try .boolean(zip(args, args.dropFirst()).allSatisfy { try numericLessThan($0, $1, function: "<") })
}

private func coreGreaterThan(_ args: [Expr]) throws -> Expr {
    if args.count == 1 { return .boolean(true) }
    return try .boolean(zip(args, args.dropFirst()).allSatisfy { try numericLessThan($1, $0, function: ">") })
}

private func coreLessOrEqual(_ args: [Expr]) throws -> Expr {
    if args.count == 1 { return .boolean(true) }
    return try .boolean(zip(args, args.dropFirst()).allSatisfy { try !numericLessThan($1, $0, function: "<=") })
}

private func coreGreaterOrEqual(_ args: [Expr]) throws -> Expr {
    if args.count == 1 { return .boolean(true) }
    return try .boolean(zip(args, args.dropFirst()).allSatisfy { try !numericLessThan($0, $1, function: ">=") })
}

private func coreEqual(_ args: [Expr]) throws -> Expr {
    if args.count == 1 { return .boolean(true) }
    return .boolean(zip(args, args.dropFirst()).allSatisfy { $0 == $1 })
}

private func coreNotEqual(_ args: [Expr]) throws -> Expr {
    if args.count == 1 { return .boolean(false) }
    return .boolean(!zip(args, args.dropFirst()).allSatisfy { $0 == $1 })
}

// MARK: - Macros

private func registerMacros(into evaluator: Evaluator) {
    evaluator.register(name: "gensym",        arity: .variadic) { [evaluator] args in try coreGensym(evaluator, args) }
    evaluator.register(name: "macroexpand-1", arity: .fixed(1)) { [evaluator] args in try coreMacroexpand1(evaluator, args) }
    evaluator.register(name: "macroexpand",   arity: .fixed(1)) { [evaluator] args in try coreMacroexpand(evaluator, args) }
}

private func coreGensym(_ evaluator: Evaluator, _ args: [Expr]) throws -> Expr {
    let prefix: String
    if let first = args.first, case .string(let p) = first {
        prefix = p
    } else {
        prefix = "G__"
    }
    return .symbol(evaluator.gensym(prefix: prefix))
}

private func coreMacroexpand1(_ evaluator: Evaluator, _ args: [Expr]) throws -> Expr {
    try evaluator.macroexpand1(args[0]) ?? args[0]
}

private func coreMacroexpand(_ evaluator: Evaluator, _ args: [Expr]) throws -> Expr {
    var form = args[0]
    while let expanded = try evaluator.macroexpand1(form) {
        form = expanded
    }
    return form
}

// MARK: - I/O

private func registerIO(into evaluator: Evaluator) {
    evaluator.register(name: "print",   arity: .variadic, body: corePrint)
    evaluator.register(name: "println", arity: .variadic, body: corePrintln)
}

private func corePrint(_ args: [Expr]) throws -> Expr {
    Swift.print(args.map { printer.strString($0) }.joined(separator: " "), terminator: "")
    return .nil
}

private func corePrintln(_ args: [Expr]) throws -> Expr {
    Swift.print(args.map { printer.strString($0) }.joined(separator: " "))
    return .nil
}

// MARK: - Numeric coercion

private enum NumericPair {
    case ints(Int, Int)
    case floats(Double, Double)
    case ratios(Ratio, Ratio)
}

private func coerceNumericPair(_ a: Expr, _ b: Expr, function: String) throws -> NumericPair {
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

private func ratioExpr(_ r: Ratio) -> Expr {
    r.denominator == 1 ? .integer(r.numerator) : .ratio(r)
}

// MARK: - Validation helpers

private func assertSingleNumeric(_ arg: Expr, function: String) throws -> Expr {
    switch arg {
    case .integer, .float, .ratio: return arg
    default:
        throw EvaluatorError.invalidArgument(
            function: function, message: "expected a number, got \(printer.printString(arg))")
    }
}

// MARK: - Comparison helpers

private func numericLessThan(_ a: Expr, _ b: Expr, function: String) throws -> Bool {
    switch try coerceNumericPair(a, b, function: function) {
    case .ints(let x, let y):     return x < y
    case .floats(let x, let y):   return x < y
    case .ratios(let x, let y):   return x.numerator * y.denominator < y.numerator * x.denominator
    }
}

// MARK: - Numeric helpers

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

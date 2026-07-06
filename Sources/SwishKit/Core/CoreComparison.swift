import BigInt
import BigDecimal

// MARK: - Registration

func registerComparison(into evaluator: Evaluator) {
    evaluator.register(name: "<", arity: .atLeastOne,
        doc: "Returns non-nil if nums are in monotonically increasing order, otherwise false.",
        arglists: [["x"], ["x", "y"], ["x", "y", "&", "more"]],
        body: coreLessThan)
    evaluator.register(name: ">", arity: .atLeastOne,
        doc: "Returns non-nil if nums are in monotonically decreasing order, otherwise false.",
        arglists: [["x"], ["x", "y"], ["x", "y", "&", "more"]],
        body: coreGreaterThan)
    evaluator.register(name: "<=", arity: .atLeastOne,
        doc: "Returns non-nil if nums are in monotonically non-decreasing order, otherwise false.",
        arglists: [["x"], ["x", "y"], ["x", "y", "&", "more"]],
        body: coreLessOrEqual)
    evaluator.register(name: ">=", arity: .atLeastOne,
        doc: "Returns non-nil if nums are in monotonically non-increasing order, otherwise false.",
        arglists: [["x"], ["x", "y"], ["x", "y", "&", "more"]],
        body: coreGreaterOrEqual)
    evaluator.register(name: "=", arity: .atLeastOne,
        doc: "Equality. Returns true if x equals y, false if not. Same as Java x.equals(y) except it also works for nil, and compares numbers and collections in a type-independent manner. Clojure's immutable data structures define equals() (and thus =) as a value, not an identity, comparison.",
        arglists: [["x"], ["x", "y"], ["x", "y", "&", "more"]],
        body: coreEqual)
    evaluator.register(name: "compare", arity: .fixed(2),
        doc: "Comparator. Returns a negative number, zero, or a positive number when x is logically 'less than', 'equal to', or 'greater than' y.",
        arglists: [["x", "y"]],
        body: coreCompare)
    evaluator.register(name: "identical?", arity: .fixed(2),
        doc: "Tests if 2 arguments are the same object.",
        arglists: [["x", "y"]]) { args in
        if case .atom(let a) = args[0], case .atom(let b) = args[1] {
            return .boolean(a === b)
        }
        return .boolean(args[0] == args[1])
    }
}

// MARK: - Implementations

private func coreLessThan(_ args: [Expr]) throws -> Expr {
    try compareConsecutivePairs(args, singleArgResult: true) { try numericLessThan($0, $1, function: "<") }
}

private func coreGreaterThan(_ args: [Expr]) throws -> Expr {
    try compareConsecutivePairs(args, singleArgResult: true) { try numericLessThan($1, $0, function: ">") }
}

private func coreLessOrEqual(_ args: [Expr]) throws -> Expr {
    try compareConsecutivePairs(args, singleArgResult: true) { try !numericLessThan($1, $0, function: "<=") }
}

private func coreGreaterOrEqual(_ args: [Expr]) throws -> Expr {
    try compareConsecutivePairs(args, singleArgResult: true) { try !numericLessThan($0, $1, function: ">=") }
}

private func coreEqual(_ args: [Expr]) throws -> Expr {
    try compareConsecutivePairs(args, singleArgResult: true) { $0 == $1 }
}

private func coreCompare(_ args: [Expr]) throws -> Expr {
    .integer(try compareExprValue(args[0], args[1]))
}

// MARK: - Numeric helper

private func numericLessThan(_ a: Expr, _ b: Expr, function: String) throws -> Bool {
    switch try coerceNumericPair(a, b, function: function) {
    case .ints(let x, let y):
        return x < y

    case .floats(let x, let y):
        return x < y

    case .ratios(let x, let y):
        return x.numerator * y.denominator < y.numerator * x.denominator

    case .bigInts(let x, let y):
        return x < y

    case .bigDecimals(let x, let y):
        return x < y
    }
}

private func splitNamed(_ s: String) -> (ns: String?, name: String) {
    guard let slash = s.firstIndex(of: "/") else { return (nil, s) }
    return (String(s[..<slash]), String(s[s.index(after: slash)...]))
}

private func compareNamed(_ a: String, _ b: String) -> Int {
    let (aNs, aName) = splitNamed(a)
    let (bNs, bName) = splitNamed(b)
    if let aNs, let bNs {
        let nsCmp = aNs < bNs ? -1 : aNs > bNs ? 1 : 0
        if nsCmp != 0 { return nsCmp }
    } else if aNs == nil, bNs != nil {
        return -1
    } else if aNs != nil, bNs == nil {
        return 1
    }
    return aName < bName ? -1 : aName > bName ? 1 : 0
}

func compareExprValue(_ x: Expr, _ y: Expr) throws -> Int {
    switch (x, y) {
    case (.nil, .nil):
        return 0

    case (.nil, _):
        return -1

    case (_, .nil):
        return 1

    case (.boolean(let a), .boolean(let b)):
        if a == b { return 0 }
        return a ? 1 : -1

    case (.integer, .integer), (.float, .float),
         (.integer, .float), (.float, .integer),
         (.ratio, _), (_, .ratio),
         (.bigInteger, _), (_, .bigInteger),
         (.bigDecimal, _), (_, .bigDecimal):
        if try numericLessThan(x, y, function: "compare") { return -1 }
        if try numericLessThan(y, x, function: "compare") { return 1 }
        return 0

    case (.string(let a), .string(let b)):
        return a < b ? -1 : a > b ? 1 : 0

    case (.keyword(let a), .keyword(let b)):
        return compareNamed(a, b)

    case (.character(let a), .character(let b)):
        return a < b ? -1 : a > b ? 1 : 0

    case (.symbol(let a, _), .symbol(let b, _)):
        return compareNamed(a, b)

    case (.vector(let a, _), .vector(let b, _)):
        for i in 0..<min(a.count, b.count) {
            let cmp = try compareExprValue(a[i], b[i])
            if cmp != 0 { return cmp }
        }
        return a.count < b.count ? -1 : a.count > b.count ? 1 : 0

    case (.list(let a, _), .list(let b, _)):
        let aArr = Array(a)
        let bArr = Array(b)
        for i in 0..<min(aArr.count, bArr.count) {
            let cmp = try compareExprValue(aArr[i], bArr[i])
            if cmp != 0 { return cmp }
        }
        return aArr.count < bArr.count ? -1 : aArr.count > bArr.count ? 1 : 0

    default:
        throw EvaluatorError.invalidArgument(function: "compare",
            message: "cannot compare \(corePrinter.printString(x)) and \(corePrinter.printString(y))")
    }
}

private func compareConsecutivePairs(
    _ args: [Expr],
    singleArgResult: Bool,
    by compare: (Expr, Expr) throws -> Bool
) throws -> Expr {
    if args.count == 1 { return .boolean(singleArgResult) }
    return try .boolean(zip(args, args.dropFirst()).allSatisfy { try compare($0, $1) })
}

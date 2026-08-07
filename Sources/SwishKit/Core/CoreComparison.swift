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
    evaluator.register(name: "==", arity: .atLeastOne,
        doc: "Returns non-nil if nums all have the equivalent value (type-independent), otherwise false.",
        arglists: [["x"], ["x", "y"], ["x", "y", "&", "more"]],
        body: coreNumericEqual)
    evaluator.register(name: "compare", arity: .fixed(2),
        doc: "Comparator. Returns a negative number, zero, or a positive number when x is logically 'less than', 'equal to', or 'greater than' y.",
        arglists: [["x", "y"]],
        body: coreCompare)
    
    evaluator.register(name: "identical?", arity: .fixed(2),
        doc: "Tests if 2 arguments are the same object.",
        arglists: [["x", "y"]],
        body: coreIdentical)
}

// MARK: - Implementations

private func coreLessThan(_ args: [Expr]) throws -> Expr {
    try compareConsecutivePairs(args, singleArgResult: true) { try numericLessThan($0, $1, function: "<") }
}

private func coreGreaterThan(_ args: [Expr]) throws -> Expr {
    try compareConsecutivePairs(args, singleArgResult: true) { try numericLessThan($1, $0, function: ">") }
}

private func coreLessOrEqual(_ args: [Expr]) throws -> Expr {
    try compareConsecutivePairs(args, singleArgResult: true) { a, b in
        guard !isNumericNaN(a) && !isNumericNaN(b) else { return false }
        return try !numericLessThan(b, a, function: "<=")
    }
}

private func coreGreaterOrEqual(_ args: [Expr]) throws -> Expr {
    try compareConsecutivePairs(args, singleArgResult: true) { a, b in
        guard !isNumericNaN(a) && !isNumericNaN(b) else { return false }
        return try !numericLessThan(a, b, function: ">=")
    }
}

private func isNumericNaN(_ expr: Expr) -> Bool {
    switch expr {
    case .double(let d): return d.isNaN
    case .float(let f):  return f.isNaN
    default:             return false
    }
}

private func coreEqual(_ args: [Expr]) throws -> Expr {
    try compareConsecutivePairs(args, singleArgResult: true) { $0 == $1 }
}

private func coreIdentical(_ args: [Expr]) throws -> Expr {
    if case .atom(let a) = args[0], case .atom(let b) = args[1] {
        return .boolean(a === b)
    }

    switch (args[0], args[1]) {
    case (.set(let a), .set(let b)):
        return .boolean(a === b)

    case (.map(let a), .map(let b)):
        return .boolean(a === b)

    case (.sortedMap(let a), .sortedMap(let b)):
        return .boolean(a === b)

    default:
        return .boolean(args[0] == args[1])
    }
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

/// A single -/0/+ comparison over the numeric tower. Backs `compare`'s numeric branch,
/// which previously called `numericLessThan` twice (once reversed) and so paid two full
/// `coerceNumericPair` dispatches per comparison — on the path taken by every sorted-map/
/// sorted-set insert and lookup, `sort`, and `asSequence`'s map-key ordering.
private func numericCompare(_ a: Expr, _ b: Expr, function: String) throws -> Int {
    switch try coerceNumericPair(a, b, function: function) {
    case .ints(let x, let y):
        return x < y ? -1 : x > y ? 1 : 0

    case .floats(let x, let y):
        return x < y ? -1 : x > y ? 1 : 0

    case .ratios(let x, let y):
        let lhs = x.numerator * y.denominator
        let rhs = y.numerator * x.denominator
        return lhs < rhs ? -1 : lhs > rhs ? 1 : 0

    case .bigInts(let x, let y):
        return x < y ? -1 : x > y ? 1 : 0

    case .bigDecimals(let x, let y):
        return x < y ? -1 : x > y ? 1 : 0
    }
}

private func numericEqual(_ a: Expr, _ b: Expr, function: String) throws -> Bool {
    switch try coerceNumericPair(a, b, function: function) {
    case .ints(let x, let y):        return x == y
    case .floats(let x, let y):      return x == y
    case .ratios(let x, let y):      return x == y
    case .bigInts(let x, let y):     return x == y
    case .bigDecimals(let x, let y): return x == y
    }
}

private func coreNumericEqual(_ args: [Expr]) throws -> Expr {
    try compareConsecutivePairs(args, singleArgResult: true) { try numericEqual($0, $1, function: "==") }
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

    case (.integer, .integer), (.double, .double),
         (.integer, .double), (.double, .integer),
         (.float, _), (_, .float),
         (.ratio, _), (_, .ratio),
         (.bigInteger, _), (_, .bigInteger),
         (.bigDecimal, _), (_, .bigDecimal):
        return try numericCompare(x, y, function: "compare")

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

    case (.mapEntry(let k1, let v1), .mapEntry(let k2, let v2)):
        let cmp = try compareExprValue(k1, k2)
        if cmp != 0 { return cmp }
        return try compareExprValue(v1, v2)

    case (.mapEntry(let k, let v), .vector(let b, _)):
        return try compareExprValue(.vector([k, v], metadata: nil), .vector(b, metadata: nil))

    case (.vector(let a, _), .mapEntry(let k, let v)):
        return try compareExprValue(.vector(a, metadata: nil), .vector([k, v], metadata: nil))

    case (.list(let a, _), .list(let b, _)):
        var ai = a.makeIterator()
        var bi = b.makeIterator()
        while true {
            switch (ai.next(), bi.next()) {
            case (.some(let x), .some(let y)):
                let cmp = try compareExprValue(x, y)
                if cmp != 0 { return cmp }
            case (.some, .none): return 1
            case (.none, .some): return -1
            case (.none, .none): return 0
            }
        }

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

extension Evaluator {
    /// Builds a -/0/+ comparison closure from an optional Swish comparator value.
    /// `nil` → the default `compareExprValue`. A user comparator may return an
    /// integer (-/0/+) or a boolean (`true` ⇒ a<b); a boolean comparator needs a
    /// second, reversed call to distinguish "greater" from "equal" — matching
    /// Clojure's boolean→3-way promotion. Used by the sorted collections
    /// (`SwishSortedSet`/`SwishSortedMap`) to honor `sorted-*-by` comparators.
    func makeComparator(_ comparator: Expr?) -> (Expr, Expr) throws -> Int {
        guard let comp = comparator else {
            return { try compareExprValue($0, $1) }
        }
        return { [self] a, b in
            let r = try call(comp, args: [a, b])
            switch r {
            case .integer(let n):
                return n

            case .boolean(let lessThan):
                if lessThan { return -1 }
                // Not (a < b): call reversed to distinguish (a > b) from (a == b).
                let reversed = try call(comp, args: [b, a])
                switch reversed {
                case .boolean(let greaterThan):
                    return greaterThan ? 1 : 0

                case .integer(let n2):
                    return n2 != 0 ? 1 : 0

                default:
                    throw EvaluatorError.invalidArgument(function: "comparator",
                        message: "comparator must return an integer or boolean")
                }

            default:
                throw EvaluatorError.invalidArgument(function: "comparator",
                    message: "comparator must return an integer or boolean")
            }
        }
    }
}

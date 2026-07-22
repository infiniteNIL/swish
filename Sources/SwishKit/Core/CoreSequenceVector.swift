import BigInt

// MARK: - Registration

func registerSequenceVector(into evaluator: Evaluator) {
    evaluator.register(name: "peek", arity: .fixed(1),
        doc: "For a vector, returns the last element. For a list, returns the first element. Returns nil for empty or nil.",
        arglists: [["coll"]]) { args in
        if let elems = vectorElements(args[0]) {
            return elems.last ?? .nil
        }
        switch args[0] {
        case .list(let elems, _):
            return elems.first ?? .nil

        case .nil:
            return .nil

        default:
            throw EvaluatorError.invalidArgument(function: "peek", message: "not a vector or list")
        }
    }
    evaluator.register(name: "pop", arity: .fixed(1),
        doc: "For a vector, returns a new vector without the last element. For a list, returns a new list without the first element.",
        arglists: [["coll"]]) { args in
        if let elems = vectorElements(args[0]) {
            guard !elems.isEmpty
            else {
                throw EvaluatorError.invalidArgument(function: "pop", message: "Can't pop empty vector")
            }
            return .vector(Array(elems.dropLast()), metadata: nil)
        }
        switch args[0] {
        case .list(let elems, _):
            guard !elems.isEmpty
            else {
                throw EvaluatorError.invalidArgument(function: "pop", message: "Can't pop empty list")
            }
            return .list(elems.dropFirst(1), metadata: nil)

        case .nil:
            return .nil

        default:
            throw EvaluatorError.invalidArgument(function: "pop", message: "not a vector or list")
        }
    }
    evaluator.register(name: "rseq", arity: .fixed(1),
        doc: "Returns, in constant time, a seq of the items in rev (supports vector, sorted-map, and sorted-set), in reverse order. If coll is empty returns nil.",
        arglists: [["coll"]]) { args in
        switch args[0] {
        case .vector(let elems, _):
            if elems.isEmpty { return .nil }
            return .list(SwishPersistentList(elems.reversed()), metadata: nil)

        case .sharedVector(let sa, _):
            if sa.elements.isEmpty { return .nil }
            return .list(SwishPersistentList(sa.elements.reversed()), metadata: nil)

        case .sortedMap(let m, _):
            if m.isEmpty { return .nil }
            let sortedKeys = m.keys.sorted { (try? compareExprValue($0, $1)).map { $0 < 0 } ?? false }
            let entries = sortedKeys.reversed().map { k -> Expr in
                .vector([k, m[k]!], metadata: nil)
            }
            return .list(SwishPersistentList(entries), metadata: nil)

        case .sortedSet(let elements, _):
            if elements.isEmpty { return .nil }
            return .list(SwishPersistentList(elements.reversed()), metadata: nil)

        default:
            throw EvaluatorError.invalidArgument(
                function: "rseq",
                message: "\(corePrinter.printString(args[0])) doesn't support rseq")
        }
    }
    evaluator.register(name: "vec", arity: .fixed(1),
        doc: "Creates a new vector containing the contents of coll.",
        arglists: [["coll"]]) { args in
        if case .array(let sa) = args[0] {
            return .sharedVector(sa, metadata: nil)
        }
        return .vector(try seqOf(args[0], function: "vec"), metadata: nil)
    }
    evaluator.register(name: "shuffle", arity: .fixed(1),
        doc: "Return a random permutation of coll",
        arglists: [["coll"]]) { args in
        // Matches real Clojure's ^java.util.Collection type hint: vectors,
        // lists, sets, and seqs implement it; String and java.util.Map
        // (unlike Collection) don't, so they're rejected here too even
        // though Swish's own seq works on both.
        let elems: [Expr]?
        switch args[0] {
        case .vector, .sharedVector, .list, .set, .sortedSet, .lazySeq, .seq:
            elems = asSequence(args[0])
        default:
            elems = nil
        }
        guard let elems else {
            throw EvaluatorError.invalidArgument(function: "shuffle",
                message: "cannot shuffle \(corePrinter.printString(args[0]))")
        }
        return .vector(elems.shuffled(), metadata: nil)
    }
    evaluator.register(name: "subvec", arity: .variadic,
        doc: "Returns a persistent vector of the items in vector from start (inclusive) to end (exclusive). If end is not supplied, defaults to (count vector).",
        arglists: [["v", "start"], ["v", "start", "end"]]) { args in
        guard args.count == 2 || args.count == 3 else {
            throw EvaluatorError.invalidArgument(function: "subvec",
                message: "requires 2 or 3 arguments, got \(args.count)")
        }
        guard let elements = vectorElements(args[0]) else {
            throw EvaluatorError.invalidArgument(function: "subvec",
                message: "\(corePrinter.printString(args[0])) is not a vector")
        }
        guard let start = javaIntValue(args[1]) else {
            throw EvaluatorError.invalidArgument(function: "subvec", message: "start cannot be cast to a number")
        }
        let end: Int
        if args.count == 3 {
            guard let e = javaIntValue(args[2]) else {
                throw EvaluatorError.invalidArgument(function: "subvec", message: "end cannot be cast to a number")
            }
            end = e
        }
        else {
            end = elements.count
        }
        guard end >= start, start >= 0, end <= elements.count else {
            throw EvaluatorError.invalidArgument(function: "subvec", message: "index out of bounds")
        }
        // Swish copies the slice rather than sharing structure — real Clojure's
        // O(1)/structure-sharing SubVector is a JVM-specific optimization, not
        // something reimplemented here (consistent with other places this
        // codebase doesn't chase JVM performance characteristics, e.g. case's
        // O(n) dispatch — see CLAUDE.md).
        return .vector(Array(elements[start..<end]), metadata: nil)
    }
}

// MARK: - Implementations

/// Extracts the backing `[Expr]` from either vector representation, discarding
/// metadata — shared by every native function that needs "give me the elements,
/// whichever vector case this is" without caring which one it got.
func vectorElements(_ expr: Expr) -> [Expr]? {
    switch expr {
    case .vector(let elems, _): return elems
    case .sharedVector(let sa, _): return sa.elements
    default: return nil
    }
}

// Mirrors Java's Number.intValue() narrowing-conversion semantics, used by
// Clojure's interop layer when calling RT.subvec(IPersistentVector, int, int):
// never throws by itself (returns nil only for genuinely non-numeric input);
// out-of-range results (e.g. from ±Infinity) are caught by subvec's own
// subsequent bounds check instead, matching how the JVM path actually fails.
private func javaIntValue(_ expr: Expr) -> Int? {
    switch expr {
    case .integer(let n):
        return n

    case .bigInteger(let n):
        return Int(exactly: n) ?? (n < 0 ? Int.min : Int.max)

    case .double(let d):
        if d.isNaN { return 0 }
        if d.isInfinite { return d > 0 ? Int.max : Int.min }
        if d >= Double(Int.max) { return Int.max }
        if d <= Double(Int.min) { return Int.min }
        return Int(d.rounded(.towardZero))

    case .float(let f):
        return javaIntValue(.double(Double(f)))

    case .ratio(let r):
        let truncated = r.numerator / r.denominator
        return Int(exactly: truncated) ?? (truncated < 0 ? Int.min : Int.max)

    case .bigDecimal(let bd):
        let truncated = bd.scale <= 0
            ? bd.integerValue * BigInt(10).power(-bd.scale)
            : bd.integerValue / BigInt(10).power(bd.scale)
        return Int(exactly: truncated) ?? (truncated < 0 ? Int.min : Int.max)

    default:
        return nil
    }
}

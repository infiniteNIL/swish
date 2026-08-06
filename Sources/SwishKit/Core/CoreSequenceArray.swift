// MARK: - Registration

func registerSequenceArray(into evaluator: Evaluator) {
    evaluator.register(name: "aset", arity: .fixed(3),
        doc: "Sets the value at index i in array a. Returns val.",
        arglists: [["array", "i", "val"]]) { args in
        guard case .array(let sa) = args[0] else {
            throw EvaluatorError.invalidArgument(function: "aset",
                message: "first argument must be an array")
        }
        guard case .integer(let idx) = args[1], idx >= 0, idx < sa.elements.count else {
            throw EvaluatorError.invalidArgument(function: "aset",
                message: "index out of bounds")
        }
        sa.set(at: idx, to: args[2])
        return args[2]
    }
    evaluator.register(name: "aget", arity: .fixed(2),
        doc: "Returns the value at index i in array.",
        arglists: [["array", "i"]]) { args in
        guard case .array(let sa) = args[0] else {
            throw EvaluatorError.invalidArgument(function: "aget",
                message: "first argument must be an array")
        }
        guard case .integer(let idx) = args[1], idx >= 0, idx < sa.elements.count else {
            throw EvaluatorError.invalidArgument(function: "aget",
                message: "index out of bounds")
        }
        return sa.elements[idx]
    }
    evaluator.register(name: "alength", arity: .fixed(1),
        doc: "Returns the length of the Java array.",
        arglists: [["array"]]) { args in
        guard case .array(let sa) = args[0] else {
            throw EvaluatorError.invalidArgument(function: "alength",
                message: "argument must be an array")
        }
        return .integer(sa.elements.count)
    }
    evaluator.register(name: "aclone", arity: .fixed(1),
        doc: "Returns a clone of the Java array. Works on arrays of known types.",
        arglists: [["array"]]) { args in
        guard case .array(let sa) = args[0] else {
            throw EvaluatorError.invalidArgument(function: "aclone",
                message: "argument must be an array")
        }
        return .array(SwishArray(sa.elements))
    }
    evaluator.register(name: "int-array", arity: .variadic,
        doc: "Creates an array of ints. Single arg: size (fills 0) or seq. Two args: size + init val.",
        arglists: [["size-or-seq"], ["size", "init"]]) { args in
        try makeArray(args, function: "int-array", defaultFill: .integer(0))
    }
    evaluator.register(name: "object-array", arity: .variadic,
        doc: "Creates an array of objects. Single arg: size (fills nil) or seq. Two args: size + init val.",
        arglists: [["size-or-seq"], ["size", "init"]]) { args in
        try makeArray(args, function: "object-array", defaultFill: .nil)
    }
    // Typed array constructors. Swish's `SwishArray` is untyped (a plain `[Expr]`
    // wrapper), so these differ only in the default fill value; no element-type
    // validation, matching `int-array`/`object-array` and the documented
    // `into-array` simplification. `(char-array "abc")` coerces the string to chars
    // via `asSequence`.
    evaluator.register(name: "char-array", arity: .variadic,
        doc: "Creates an array of chars. Single arg: size (fills \\u0000) or seq/string. Two args: size + init val.",
        arglists: [["size-or-seq"], ["size", "init"]]) { args in
        try makeArray(args, function: "char-array", defaultFill: .character(Character(UnicodeScalar(0))))
    }
    evaluator.register(name: "double-array", arity: .variadic,
        doc: "Creates an array of doubles. Single arg: size (fills 0.0) or seq. Two args: size + init val.",
        arglists: [["size-or-seq"], ["size", "init"]]) { args in
        try makeArray(args, function: "double-array", defaultFill: .double(0.0))
    }
    evaluator.register(name: "float-array", arity: .variadic,
        doc: "Creates an array of floats. Single arg: size (fills 0.0) or seq. Two args: size + init val.",
        arglists: [["size-or-seq"], ["size", "init"]]) { args in
        try makeArray(args, function: "float-array", defaultFill: .float(0.0))
    }
    evaluator.register(name: "long-array", arity: .variadic,
        doc: "Creates an array of longs. Single arg: size (fills 0) or seq. Two args: size + init val.",
        arglists: [["size-or-seq"], ["size", "init"]]) { args in
        try makeArray(args, function: "long-array", defaultFill: .integer(0))
    }
    evaluator.register(name: "short-array", arity: .variadic,
        doc: "Creates an array of shorts. Single arg: size (fills 0) or seq. Two args: size + init val.",
        arglists: [["size-or-seq"], ["size", "init"]]) { args in
        try makeArray(args, function: "short-array", defaultFill: .integer(0))
    }
    evaluator.register(name: "byte-array", arity: .variadic,
        doc: "Creates an array of bytes. Single arg: size (fills 0) or seq. Two args: size + init val.",
        arglists: [["size-or-seq"], ["size", "init"]]) { args in
        try makeArray(args, function: "byte-array", defaultFill: .integer(0))
    }
    evaluator.register(name: "boolean-array", arity: .variadic,
        doc: "Creates an array of booleans. Single arg: size (fills false) or seq. Two args: size + init val.",
        arglists: [["size-or-seq"], ["size", "init"]]) { args in
        try makeArray(args, function: "boolean-array", defaultFill: .boolean(false))
    }
}

// MARK: - Implementations

/// Shared implementation backing `int-array`/`object-array` — a single arg is either
/// a size (fills with `defaultFill`) or a seq to coerce; two args are size plus an
/// init that is either a scalar fill or a seq of initial elements.
///
/// The scalar-vs-seq split mirrors `RT.intArray`/`RT.charArray`/…, which fill every
/// slot when the init is the array's element scalar (`init instanceof Number`) and
/// otherwise walk `RT.seq(init)` positionally, leaving any slot past the seq's end at
/// the default. `SwishArray` is untyped, so seqability stands in for the element-type
/// test: a number isn't seqable, so `(int-array 3 7)` still fills; a collection is, so
/// `(int-array 3 [7 8])` gives `[7 8 0]`.
private func makeArray(_ args: [Expr], function: String, defaultFill: Expr) throws -> Expr {
    switch args[0] {
    case .integer(let n):
        guard n >= 0 else {
            throw EvaluatorError.invalidArgument(function: function,
                message: "size must be non-negative")
        }
        guard args.count > 1 else {
            return .array(SwishArray(Array(repeating: defaultFill, count: n)))
        }
        guard let initSeq = try asSequence(args[1]) else {
            return .array(SwishArray(Array(repeating: args[1], count: n)))
        }
        var elements = Array(initSeq.prefix(n))
        elements.append(contentsOf: Array(repeating: defaultFill, count: n - elements.count))
        return .array(SwishArray(elements))

    default:
        return .array(SwishArray(try asSequence(args[0]) ?? []))
    }
}

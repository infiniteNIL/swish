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
}

// MARK: - Implementations

/// Shared implementation backing `int-array`/`object-array` — a single arg is either
/// a size (fills with `defaultFill`) or a seq to coerce; two args are size + init val.
private func makeArray(_ args: [Expr], function: String, defaultFill: Expr) throws -> Expr {
    switch args[0] {
    case .integer(let n):
        guard n >= 0 else {
            throw EvaluatorError.invalidArgument(function: function,
                message: "size must be non-negative")
        }
        let fill: Expr = args.count > 1 ? args[1] : defaultFill
        return .array(SwishArray(Array(repeating: fill, count: n)))
    default:
        return .array(SwishArray(asSequence(args[0]) ?? []))
    }
}

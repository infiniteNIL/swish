// MARK: - Registration

func registerBitwise(into evaluator: Evaluator) {
    evaluator.register(name: "bit-and", arity: .variadic,
        doc: "Bitwise and",
        arglists: [["x", "y"], ["x", "y", "&", "more"]],
        body: coreBitAnd)
    evaluator.register(name: "bit-or", arity: .variadic,
        doc: "Bitwise or",
        arglists: [["x", "y"], ["x", "y", "&", "more"]],
        body: coreBitOr)
    evaluator.register(name: "bit-xor", arity: .variadic,
        doc: "Bitwise exclusive or",
        arglists: [["x", "y"], ["x", "y", "&", "more"]],
        body: coreBitXor)
    evaluator.register(name: "bit-and-not", arity: .variadic,
        doc: "Bitwise and with complement",
        arglists: [["x", "y"], ["x", "y", "&", "more"]],
        body: coreBitAndNot)
    evaluator.register(name: "bit-not", arity: .fixed(1),
        doc: "Bitwise complement",
        arglists: [["x"]],
        body: coreBitNot)
    evaluator.register(name: "bit-shift-left", arity: .fixed(2),
        doc: "Bitwise shift left",
        arglists: [["x", "n"]],
        body: coreBitShiftLeft)
    evaluator.register(name: "bit-shift-right", arity: .fixed(2),
        doc: "Bitwise shift right",
        arglists: [["x", "n"]],
        body: coreBitShiftRight)
    evaluator.register(name: "bit-set", arity: .fixed(2),
        doc: "Set bit at index n",
        arglists: [["x", "n"]],
        body: coreBitSet)
    evaluator.register(name: "bit-clear", arity: .fixed(2),
        doc: "Clear bit at index n",
        arglists: [["x", "n"]],
        body: coreBitClear)
    evaluator.register(name: "bit-flip", arity: .fixed(2),
        doc: "Flip bit at index n",
        arglists: [["x", "n"]],
        body: coreBitFlip)
    evaluator.register(name: "bit-test", arity: .fixed(2),
        doc: "Test bit at index n",
        arglists: [["x", "n"]],
        body: coreBitTest)
    evaluator.register(name: "unsigned-bit-shift-right", arity: .fixed(2),
        doc: "Bitwise shift right, without sign-extension.",
        arglists: [["x", "n"]],
        body: coreUnsignedBitShiftRight)
}

// MARK: - Helpers

private func bitwiseInt(_ expr: Expr, function: String) throws -> Int {
    guard case .integer(let n) = expr else {
        throw EvaluatorError.invalidArgument(function: function,
            message: "value must be an integer, got \(corePrinter.printString(expr))")
    }
    return n
}

// MARK: - Implementations

private func coreBitAnd(_ args: [Expr]) throws -> Expr {
    guard args.count >= 2 else {
        throw EvaluatorError.arityMismatch(name: "bit-and", expected: .variadic, got: args.count)
    }
    var result = try bitwiseInt(args[0], function: "bit-and")
    for arg in args.dropFirst() {
        result &= try bitwiseInt(arg, function: "bit-and")
    }
    return .integer(result)
}

private func coreBitOr(_ args: [Expr]) throws -> Expr {
    guard args.count >= 2 else {
        throw EvaluatorError.arityMismatch(name: "bit-or", expected: .variadic, got: args.count)
    }
    var result = try bitwiseInt(args[0], function: "bit-or")
    for arg in args.dropFirst() {
        result |= try bitwiseInt(arg, function: "bit-or")
    }
    return .integer(result)
}

private func coreBitXor(_ args: [Expr]) throws -> Expr {
    guard args.count >= 2 else {
        throw EvaluatorError.arityMismatch(name: "bit-xor", expected: .variadic, got: args.count)
    }
    var result = try bitwiseInt(args[0], function: "bit-xor")
    for arg in args.dropFirst() {
        result ^= try bitwiseInt(arg, function: "bit-xor")
    }
    return .integer(result)
}

private func coreBitAndNot(_ args: [Expr]) throws -> Expr {
    guard args.count >= 2 else {
        throw EvaluatorError.arityMismatch(name: "bit-and-not", expected: .variadic, got: args.count)
    }
    var result = try bitwiseInt(args[0], function: "bit-and-not")
    for arg in args.dropFirst() {
        result &= ~(try bitwiseInt(arg, function: "bit-and-not"))
    }
    return .integer(result)
}

private func coreBitNot(_ args: [Expr]) throws -> Expr {
    .integer(~(try bitwiseInt(args[0], function: "bit-not")))
}

private func coreBitShiftLeft(_ args: [Expr]) throws -> Expr {
    let x = try bitwiseInt(args[0], function: "bit-shift-left")
    let n = try bitwiseInt(args[1], function: "bit-shift-left")
    return .integer(x << n)
}

private func coreBitShiftRight(_ args: [Expr]) throws -> Expr {
    let x = try bitwiseInt(args[0], function: "bit-shift-right")
    let n = try bitwiseInt(args[1], function: "bit-shift-right")
    return .integer(x >> n)
}

private func coreBitSet(_ args: [Expr]) throws -> Expr {
    let x = try bitwiseInt(args[0], function: "bit-set")
    let n = try bitwiseInt(args[1], function: "bit-set")
    return .integer(x | (1 << n))
}

private func coreBitClear(_ args: [Expr]) throws -> Expr {
    let x = try bitwiseInt(args[0], function: "bit-clear")
    let n = try bitwiseInt(args[1], function: "bit-clear")
    return .integer(x & ~(1 << n))
}

private func coreBitFlip(_ args: [Expr]) throws -> Expr {
    let x = try bitwiseInt(args[0], function: "bit-flip")
    let n = try bitwiseInt(args[1], function: "bit-flip")
    return .integer(x ^ (1 << n))
}

private func coreBitTest(_ args: [Expr]) throws -> Expr {
    let x = try bitwiseInt(args[0], function: "bit-test")
    let n = try bitwiseInt(args[1], function: "bit-test")
    return .boolean((x & (1 << n)) != 0)
}

private func coreUnsignedBitShiftRight(_ args: [Expr]) throws -> Expr {
    let x = try bitwiseInt(args[0], function: "unsigned-bit-shift-right")
    let n = try bitwiseInt(args[1], function: "unsigned-bit-shift-right")
    return .integer(Int(bitPattern: UInt(bitPattern: x) >> n))
}

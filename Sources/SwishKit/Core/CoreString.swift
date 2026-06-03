// MARK: - Registration

func registerString(into evaluator: Evaluator) {
    evaluator.register(name: "str", arity: .variadic,
        doc: "With no args, returns the empty string. With one arg x, returns x.toString(). (str nil) returns the empty string. With more than one arg, returns the concatenation of the str values of the args.",
        arglists: [[], ["x"], ["x", "&", "ys"]],
        body: coreStr)
    evaluator.register(name: "subs", arity: .variadic,
        doc: "Returns the substring of s beginning at start inclusive, and ending at end (defaults to length of string), exclusive.",
        arglists: [["s", "start"], ["s", "start", "end"]],
        body: coreSubs)
}

// MARK: - Implementations

private func coreStr(_ args: [Expr]) throws -> Expr {
    .string(args.map { corePrinter.strString($0) }.joined())
}

private func coreSubs(_ args: [Expr]) throws -> Expr {
    guard args.count == 2 || args.count == 3 else {
        throw EvaluatorError.invalidArgument(
            function: "subs",
            message: "requires 2 or 3 arguments, got \(args.count)")
    }
    guard case .string(let s) = args[0] else {
        throw EvaluatorError.invalidArgument(
            function: "subs",
            message: "first argument must be a string")
    }
    guard case .integer(let start) = args[1] else {
        throw EvaluatorError.invalidArgument(
            function: "subs",
            message: "start must be an integer")
    }
    let chars = Array(s)
    let len = chars.count
    let end: Int
    if args.count == 3 {
        guard case .integer(let e) = args[2] else {
            throw EvaluatorError.invalidArgument(
                function: "subs",
                message: "end must be an integer")
        }
        end = e
    }
    else {
        end = len
    }
    guard start >= 0, end >= start, end <= len else {
        throw EvaluatorError.invalidArgument(
            function: "subs",
            message: "index out of range (start=\(start), end=\(end), length=\(len))")
    }
    return .string(String(chars[start..<end]))
}

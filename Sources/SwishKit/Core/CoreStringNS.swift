extension Evaluator {
    func registerClojureStringNatives() {
        let ns = findOrCreateNs("clojure.string")
        let v = ns.intern(name: "split", value: coreSplit)
        v.metadata = [
            .keyword("doc"): .string(
                "Splits string on a regular expression. Optional argument limit is " +
                "the maximum number of splits. Not lazy. Returns vector of the splits."),
            .keyword("arglists"): .list([
                .vector([.symbol("s", metadata: nil), .symbol("re", metadata: nil)],
                        metadata: nil),
                .vector([.symbol("s", metadata: nil), .symbol("re", metadata: nil),
                         .symbol("limit", metadata: nil)], metadata: nil),
            ], metadata: nil),
        ]
    }
}

private let coreSplit = Expr.nativeFunction(name: "split", arity: .variadic) { args in
    guard args.count == 2 || args.count == 3 else {
        throw EvaluatorError.invalidArgument(
            function: "split",
            message: "requires 2 or 3 arguments, got \(args.count)")
    }

    guard case .string(let s) = args[0] else {
        throw EvaluatorError.invalidArgument(
            function: "split",
            message: "first argument must be a string")
    }

    guard case .regex(let re) = args[1] else {
        throw EvaluatorError.invalidArgument(
            function: "split",
            message: "second argument must be a regex")
    }

    let limit: Int
    if args.count == 3 {
        guard case .integer(let n) = args[2] else {
            throw EvaluatorError.invalidArgument(
                function: "split",
                message: "limit must be an integer")
        }
        limit = n
    }
    else {
        limit = 0
    }

    let parts = splitImpl(s, regex: re, limit: limit)
    return .vector(parts.map { .string(String($0)) }, metadata: nil)
}

private func splitImpl(_ s: String, regex: SwishRegex, limit: Int) -> [Substring] {
    guard !s.isEmpty else {
        return []
    }

    if limit > 0 {
        return s.split(separator: regex.regex,
                       maxSplits: limit - 1,
                       omittingEmptySubsequences: false)
    }
    else if limit < 0 {
        return s.split(separator: regex.regex,
                       maxSplits: Int.max,
                       omittingEmptySubsequences: false)
    }
    else {
        var parts = s.split(separator: regex.regex,
                            maxSplits: Int.max,
                            omittingEmptySubsequences: false)
        while parts.last?.isEmpty == true {
            parts.removeLast()
        }
        return parts
    }
}

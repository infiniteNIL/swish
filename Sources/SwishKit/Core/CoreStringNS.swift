extension Evaluator {
    func registerClojureStringNatives() {
        let ns = findOrCreateNs("clojure.string")

        let splitVar = ns.intern(name: "split", value: coreSplit)
        splitVar.metadata = [
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

        let trimVar = ns.intern(name: "trim", value: coreTrim)
        trimVar.metadata = [
            .keyword("doc"): .string(
                "Removes whitespace from both ends of string."),
            .keyword("arglists"): .list([
                .vector([.symbol("s", metadata: nil)], metadata: nil),
            ], metadata: nil),
        ]

        let trimlVar = ns.intern(name: "triml", value: coreTriml)
        trimlVar.metadata = [
            .keyword("doc"): .string(
                "Removes whitespace from the left side of string."),
            .keyword("arglists"): .list([
                .vector([.symbol("s", metadata: nil)], metadata: nil),
            ], metadata: nil),
        ]

        let trimrVar = ns.intern(name: "trimr", value: coreTrimr)
        trimrVar.metadata = [
            .keyword("doc"): .string(
                "Removes whitespace from the right side of string."),
            .keyword("arglists"): .list([
                .vector([.symbol("s", metadata: nil)], metadata: nil),
            ], metadata: nil),
        ]

        let trimNewlineVar = ns.intern(name: "trim-newline", value: coreTrimNewline)
        trimNewlineVar.metadata = [
            .keyword("doc"): .string(
                "Removes all trailing newline \\n or return \\r characters from " +
                "string. Similar to Perl's chomp."),
            .keyword("arglists"): .list([
                .vector([.symbol("s", metadata: nil)], metadata: nil),
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

private func trimWhitespace(_ s: String, left: Bool, right: Bool) -> String {
    var start = s.startIndex
    var end = s.endIndex
    if left {
        while start < end && s[start].isWhitespace {
            start = s.index(after: start)
        }
    }
    if right {
        while end > start {
            let prev = s.index(before: end)
            if s[prev].isWhitespace {
                end = prev
            }
            else {
                break
            }
        }
    }
    return String(s[start..<end])
}

private let coreTrim = Expr.nativeFunction(name: "trim", arity: .fixed(1)) { args in
    guard case .string(let s) = args[0] else {
        throw EvaluatorError.invalidArgument(function: "trim", message: "argument must be a string")
    }
    return .string(trimWhitespace(s, left: true, right: true))
}

private let coreTriml = Expr.nativeFunction(name: "triml", arity: .fixed(1)) { args in
    guard case .string(let s) = args[0] else {
        throw EvaluatorError.invalidArgument(function: "triml", message: "argument must be a string")
    }
    return .string(trimWhitespace(s, left: true, right: false))
}

private let coreTrimr = Expr.nativeFunction(name: "trimr", arity: .fixed(1)) { args in
    guard case .string(let s) = args[0] else {
        throw EvaluatorError.invalidArgument(function: "trimr", message: "argument must be a string")
    }
    return .string(trimWhitespace(s, left: false, right: true))
}

private let coreTrimNewline = Expr.nativeFunction(name: "trim-newline", arity: .fixed(1)) { args in
    guard case .string(let s) = args[0] else {
        throw EvaluatorError.invalidArgument(function: "trim-newline", message: "argument must be a string")
    }
    var result = s
    while let last = result.last,
          last.unicodeScalars.allSatisfy({ $0.value == 0x000A || $0.value == 0x000D }) {
        result.removeLast()
    }
    return .string(result)
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

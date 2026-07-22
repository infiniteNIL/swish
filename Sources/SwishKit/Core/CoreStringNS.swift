// MARK: - Registration

func registerClojureStringNatives(into evaluator: Evaluator) {
    let ns = evaluator.findOrCreateNs("clojure.string")

        ns.register(name: "split", value: coreSplit,
            doc: "Splits string on a regular expression. Optional argument limit is " +
                 "the maximum number of splits. Not lazy. Returns vector of the splits.",
            arglists: [["s", "re"], ["s", "re", "limit"]])

        ns.register(name: "trim", value: coreTrim,
            doc: "Removes whitespace from both ends of string.",
            arglists: [["s"]])

        ns.register(name: "triml", value: coreTriml,
            doc: "Removes whitespace from the left side of string.",
            arglists: [["s"]])

        ns.register(name: "trimr", value: coreTrimr,
            doc: "Removes whitespace from the right side of string.",
            arglists: [["s"]])

        ns.register(name: "trim-newline", value: coreTrimNewline,
            doc: "Removes all trailing newline \\n or return \\r characters from " +
                 "string. Similar to Perl's chomp.",
            arglists: [["s"]])

        ns.register(name: "upper-case", value: coreUpperCase,
            doc: "Converts string to all upper-case.",
            arglists: [["s"]])

        ns.register(name: "lower-case", value: coreLowerCase,
            doc: "Converts string to all lower-case.",
            arglists: [["s"]])

        ns.register(name: "capitalize", value: coreCapitalize,
            doc: "Converts first character of the string to upper-case, all other characters to lower-case.",
            arglists: [["s"]])

        ns.register(name: "starts-with?", value: coreStartsWith,
            doc: "True if s starts with substr.",
            arglists: [["s", "substr"]])

        ns.register(name: "ends-with?", value: coreEndsWith,
            doc: "True if s ends with substr.",
            arglists: [["s", "substr"]])

        ns.register(name: "includes?", value: coreIncludes,
            doc: "True if s includes substr.",
            arglists: [["s", "substr"]])

        ns.register(name: "blank?", value: coreBlank,
            doc: "True if s is nil, empty, or contains only whitespace.",
            arglists: [["s"]])

        ns.register(name: "reverse", value: coreStringReverse,
            doc: "Returns s with its characters reversed.",
            arglists: [["s"]])

        ns.register(name: "replace", value: makeReplaceFunction(evaluator: evaluator),
            doc: "Replaces all instances of match with replacement in s. " +
                 "match/replacement can be: string/string, char/char, " +
                 "pattern/string, or pattern/function.",
            arglists: [["s", "match", "replacement"]])

        ns.register(name: "escape", value: makeEscapeFunction(evaluator: evaluator),
            doc: "Return a new string, using cmap to escape each character ch from s: " +
                 "if (cmap ch) is nil, append ch unchanged, else append (str (cmap ch)).",
            arglists: [["s", "cmap"]])

        ns.register(name: "join", value: coreJoin,
            doc: "Returns a string of all elements in coll, as returned by (seq coll), " +
                 "separated by an optional separator.",
            arglists: [["coll"], ["sep", "coll"]])
}

private func makeEscapeFunction(evaluator: Evaluator) -> Expr {
    return Expr.nativeFunction(name: "escape", arity: .fixed(2)) { [evaluator] args in
        let s = try requireString(args[0], function: "escape")
        let cmap = args[1]
        var result = ""
        for ch in s {
            let replacement = try evaluator.call(cmap, args: [.character(ch)])
            if case .nil = replacement {
                result.append(ch)
            }
            else {
                result += corePrinter.strString(replacement)
            }
        }
        return .string(result)
    }
}

// MARK: - Shared argument helpers

private func requireNonNilStr(_ arg: Expr, function: String) throws -> String {
    if case .nil = arg {
        throw EvaluatorError.invalidArgument(function: function,
            message: "argument must not be nil")
    }
    return corePrinter.strString(arg)
}

private func requireString(_ arg: Expr, function: String) throws -> String {
    guard case .string(let s) = arg else {
        throw EvaluatorError.invalidArgument(function: function,
            message: "argument must be a string")
    }
    return s
}

// MARK: - replace (needs evaluator capture)

private func makeReplaceFunction(evaluator: Evaluator) -> Expr {
    return Expr.nativeFunction(name: "replace", arity: .fixed(3)) { [evaluator] args in
        let s = try requireString(args[0], function: "replace")
        switch args[1] {
        case .string(let match):
            guard case .string(let repl) = args[2] else {
                throw EvaluatorError.invalidArgument(function: "replace",
                    message: "string match requires string replacement")
            }
            return .string(s.replacingOccurrences(of: match, with: repl))

        case .character(let match):
            guard case .character(let repl) = args[2] else {
                throw EvaluatorError.invalidArgument(function: "replace",
                    message: "char match requires char replacement")
            }
            return .string(s.replacingOccurrences(of: String(match), with: String(repl)))

        case .regex(let re):
            switch args[2] {
            case .string(let repl):
                return .string(s.replacing(re.regex, with: repl))

            default:
                let f = args[2]
                var result = ""
                var lastEnd = s.startIndex
                for match in s.matches(of: re.regex) {
                    result += s[lastEnd..<match.range.lowerBound]
                    let matchStr = String(s[match.range])
                    guard case .string(let repl) = try evaluator.call(f, args: [.string(matchStr)]) else {
                        throw EvaluatorError.invalidArgument(function: "replace",
                            message: "replacement function must return a string")
                    }
                    result += repl
                    lastEnd = match.range.upperBound
                }
                result += s[lastEnd...]
                return .string(result)
            }

        default:
            throw EvaluatorError.invalidArgument(function: "replace",
                message: "match must be a string, character, or regex")
        }
    }
}

// MARK: - Implementations

private let coreSplit = Expr.nativeFunction(name: "split", arity: .variadic) { args in
    guard args.count == 2 || args.count == 3 else {
        throw EvaluatorError.invalidArgument(
            function: "split",
            message: "requires 2 or 3 arguments, got \(args.count)")
    }
    let s = try requireString(args[0], function: "split")
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
    let s = try requireString(args[0], function: "trim")
    return .string(trimWhitespace(s, left: true, right: true))
}

private let coreTriml = Expr.nativeFunction(name: "triml", arity: .fixed(1)) { args in
    let s = try requireString(args[0], function: "triml")
    return .string(trimWhitespace(s, left: true, right: false))
}

private let coreTrimr = Expr.nativeFunction(name: "trimr", arity: .fixed(1)) { args in
    let s = try requireString(args[0], function: "trimr")
    return .string(trimWhitespace(s, left: false, right: true))
}

private let coreTrimNewline = Expr.nativeFunction(name: "trim-newline", arity: .fixed(1)) { args in
    var result = try requireString(args[0], function: "trim-newline")
    while let last = result.last,
          last.unicodeScalars.allSatisfy({ $0.value == 0x000A || $0.value == 0x000D }) {
        result.removeLast()
    }
    return .string(result)
}

private let coreUpperCase = Expr.nativeFunction(name: "upper-case", arity: .fixed(1)) { args in
    return try .string(requireNonNilStr(args[0], function: "upper-case").uppercased())
}

private let coreLowerCase = Expr.nativeFunction(name: "lower-case", arity: .fixed(1)) { args in
    return try .string(requireNonNilStr(args[0], function: "lower-case").lowercased())
}

private let coreCapitalize = Expr.nativeFunction(name: "capitalize", arity: .fixed(1)) { args in
    let s = try requireNonNilStr(args[0], function: "capitalize")
    if s.count < 2 {
        return .string(s.uppercased())
    }
    return .string(s.prefix(1).uppercased() + s.dropFirst().lowercased())
}

private let coreStartsWith = Expr.nativeFunction(name: "starts-with?", arity: .fixed(2)) { args in
    let s = try requireNonNilStr(args[0], function: "starts-with?")
    guard case .string(let substr) = args[1] else {
        throw EvaluatorError.invalidArgument(function: "starts-with?", message: "second argument must be a string")
    }
    return .boolean(s.hasPrefix(substr))
}

private let coreEndsWith = Expr.nativeFunction(name: "ends-with?", arity: .fixed(2)) { args in
    let s = try requireNonNilStr(args[0], function: "ends-with?")
    guard case .string(let substr) = args[1] else {
        throw EvaluatorError.invalidArgument(function: "ends-with?", message: "second argument must be a string")
    }
    return .boolean(s.hasSuffix(substr))
}

private let coreIncludes = Expr.nativeFunction(name: "includes?", arity: .fixed(2)) { args in
    let s = try requireString(args[0], function: "includes?")
    guard case .string(let substr) = args[1] else {
        throw EvaluatorError.invalidArgument(function: "includes?", message: "second argument must be a string")
    }
    return .boolean(substr.isEmpty || s.contains(substr))
}

private let coreBlank = Expr.nativeFunction(name: "blank?", arity: .fixed(1)) { args in
    switch args[0] {
    case .nil:
        return .boolean(true)

    case .string(let s):
        return .boolean(s.allSatisfy(\.isWhitespace))

    default:
        throw EvaluatorError.invalidArgument(function: "blank?", message: "argument must be a string or nil")
    }
}

private let coreStringReverse = Expr.nativeFunction(name: "reverse", arity: .fixed(1)) { args in
    guard case .string(let s) = args[0] else {
        throw EvaluatorError.invalidArgument(function: "reverse", message: "argument must be a string")
    }
    return .string(String(s.reversed()))
}

private let coreJoin = Expr.nativeFunction(name: "join", arity: .variadic) { args in
    guard args.count == 1 || args.count == 2 else {
        throw EvaluatorError.invalidArgument(function: "join",
            message: "requires 1 or 2 arguments, got \(args.count)")
    }
    let sep = args.count == 2 ? corePrinter.strString(args[0]) : ""
    let collArg = args.count == 2 ? args[1] : args[0]
    guard let elements = asSequence(collArg) else {
        throw EvaluatorError.invalidArgument(function: "join",
            message: "don't know how to create seq from \(corePrinter.printString(collArg))")
    }
    return .string(elements.map { corePrinter.strString($0) }.joined(separator: sep))
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

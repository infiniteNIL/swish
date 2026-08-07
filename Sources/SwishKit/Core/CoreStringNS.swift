// Shared verbatim by the two-string predicates (starts-with?/ends-with?/includes?).
private let secondMustBeAString = "second argument must be a string"

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

        ns.register(name: "index-of", value: coreIndexOf,
            doc: "Return index of value (string or char) in s, optionally searching " +
                 "forward from from-index. Return nil if value not found.",
            arglists: [["s", "value"], ["s", "value", "from-index"]])

        ns.register(name: "last-index-of", value: coreLastIndexOf,
            doc: "Return last index of value (string or char) in s, optionally " +
                 "searching backward from from-index. Return nil if value not found.",
            arglists: [["s", "value"], ["s", "value", "from-index"]])

        ns.register(name: "blank?", value: coreBlank,
            doc: "True if s is nil, empty, or contains only whitespace.",
            arglists: [["s"]])

        ns.register(name: "reverse", value: coreStringReverse,
            doc: "Returns s with its characters reversed.",
            arglists: [["s"]])

        ns.register(name: "replace", value: makeReplaceFunction(evaluator: evaluator, name: "replace", firstOnly: false),
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

        ns.register(name: "split-lines", value: coreSplitLines,
            doc: "Splits s on \\n or \\r\\n. Trailing empty lines are not returned.",
            arglists: [["s"]])

        ns.register(name: "replace-first", value: makeReplaceFunction(evaluator: evaluator, name: "replace-first", firstOnly: true),
            doc: "Replaces the first instance of match with replacement in s. " +
                 "match/replacement can be: string/string, char/char, " +
                 "pattern/string, or pattern/function.",
            arglists: [["s", "match", "replacement"]])

        ns.register(name: "re-quote-replacement", value: coreReQuoteReplacement,
            doc: "Given a replacement string that you wish to be a literal replacement " +
                 "for a pattern match in replace or replace-first, do the necessary " +
                 "escaping of special characters in the replacement.",
            arglists: [["replacement"]])
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

// `requireString`/`requireNonNilStr` used to live here as file-private helpers; they
// are now the shared versions in `CoreArgs.swift` (same signatures, same default
// messages), so every call below is unchanged.

// MARK: - replace / replace-first (need evaluator capture)

/// Builds `replace` or `replace-first`. The two accept exactly the same match/replacement
/// type combinations (string/string, char/char, regex/string-template, regex/fn) and
/// report the same errors; `firstOnly` is the whole difference between them.
private func makeReplaceFunction(evaluator: Evaluator, name: String, firstOnly: Bool) -> Expr {
    Expr.nativeFunction(name: name, arity: .fixed(3)) { [evaluator] args in
        let s = try requireNonNilStr(args[0], function: name)
        switch args[1] {
        case .string(let match):
            let repl = try requireString(args[2], function: name,
                message: "string match requires string replacement")
            return .string(replacingLiteral(match, with: repl, in: s, firstOnly: firstOnly))

        case .character(let match):
            let repl = try requireCharacter(args[2], function: name,
                message: "char match requires char replacement")
            return .string(replacingLiteral(String(match), with: String(repl), in: s, firstOnly: firstOnly))

        case .regex(let re):
            // `replace-first` is the same accumulate-prefix/append-tail walk over at most
            // one match: with zero matches the loop body never runs and the tail append
            // reproduces `s` unchanged, exactly as the separate implementation did.
            let matches = firstOnly ? Array(s.matches(of: re.regex).prefix(1)) : Array(s.matches(of: re.regex))
            var result = ""
            var lastEnd = s.startIndex
            for match in matches {
                result += s[lastEnd..<match.range.lowerBound]
                if case .string(let replTemplate) = args[2] {
                    result += expandReplacementTemplate(replTemplate, output: match.output)
                }
                else {
                    let matchStr = String(s[match.range])
                    let replacement = try evaluator.call(args[2], args: [.string(matchStr)])
                    result += try requireString(replacement, function: name,
                        message: "replacement function must return a string")
                }
                lastEnd = match.range.upperBound
            }
            result += s[lastEnd...]
            return .string(result)

        default:
            throw EvaluatorError.invalidArgument(function: name,
                message: "match must be a string, character, or regex")
        }
    }
}

/// Literal (non-regex) substitution shared by the string- and char-match branches.
/// An empty `match` is Clojure's special case: `replace` interleaves the replacement
/// around every character, `replace-first` just prepends it.
private func replacingLiteral(_ match: String, with repl: String, in s: String, firstOnly: Bool) -> String {
    guard !match.isEmpty else {
        if firstOnly {
            return repl + s
        }
        var result = repl
        for ch in s {
            result.append(ch)
            result += repl
        }
        return result
    }
    guard firstOnly else {
        return s.replacingOccurrences(of: match, with: repl)
    }
    guard let range = s.range(of: match) else { return s }
    return s.replacingCharacters(in: range, with: repl)
}

/// `re-quote-replacement`: escapes `\` and `$` in a replacement string so it's treated
/// literally by `replace`/`replace-first`'s regex-template dialect (mirrors Java
/// `Matcher.quoteReplacement`). Pairs with `expandReplacementTemplate`, where `\x` is a
/// literal `x` — so `\$`/`\\` here become a literal `$`/`\` there.
private let coreReQuoteReplacement = Expr.nativeFunction(name: "re-quote-replacement", arity: .fixed(1)) { args in
    let s = try requireString(args[0], function: "re-quote-replacement")
    var result = ""
    for ch in s {
        if ch == "\\" || ch == "$" {
            result.append("\\")
        }
        result.append(ch)
    }
    return .string(result)
}

/// `split-lines`: splits on `\n` or `\r\n` (matching Clojure's `#"\r?\n"`), with
/// trailing empty lines dropped. Implemented directly rather than via the regex
/// `splitImpl` because Swift treats `\r\n` as a single grapheme cluster that a
/// `\r?\n` regex won't match — so we normalize `\r\n` → `\n` (a lone `\r` is left
/// intact, i.e. not a line boundary, exactly as `\r?\n` requires) then split on `\n`.
///
/// The two trailing-empty rules are separate, and conflating them was a bug. Java's
/// `split` (which Clojure's `split-lines` delegates to) discards *every* trailing empty
/// — possibly leaving nothing, so `"\n"` is `[]` — but returns `[""]` for empty input,
/// because a pattern that never matches yields the original string. Trimming with a
/// `count > 1` floor approximated the second rule at the cost of the first, so an
/// all-newline string wrongly came back as `[""]`.
private let coreSplitLines = Expr.nativeFunction(name: "split-lines", arity: .fixed(1)) { args in
    let s = try requireString(args[0], function: "split-lines")
    guard !s.isEmpty else {
        return .vector(SwishPersistentVector([.string("")]), metadata: nil)
    }
    let normalized = s.replacingOccurrences(of: "\r\n", with: "\n")
    var parts = normalized.split(separator: "\n", omittingEmptySubsequences: false).map { String($0) }
    while parts.last == "" {
        parts.removeLast()
    }
    return .vector(SwishPersistentVector(parts.map { .string($0) }), metadata: nil)
}

/// Expands `$N` capture-group backreferences (`$0` = whole match, `$1`... = groups
/// in order) in a regex replacement template, matching Java `Matcher.appendReplacement`'s
/// template dialect (which real Clojure's own `replace` docstring references). `\`
/// escapes the following character to a literal. A `$` not followed by digits that
/// resolve to a valid group number, or digits resolving out of range, is left literal.
private func expandReplacementTemplate(_ template: String, output: AnyRegexOutput) -> String {
    var result = ""
    var chars = Substring(template)
    while let ch = chars.first {
        if ch == "\\", let next = chars.dropFirst().first {
            result.append(next)
            chars = chars.dropFirst(2)
        }
        else if ch == "$" {
            var digits = ""
            var rest = chars.dropFirst()
            while let d = rest.first, d.isNumber {
                digits.append(d)
                rest = rest.dropFirst()
            }
            if let groupNum = Int(digits), groupNum < output.count {
                result += output[groupNum].substring.map(String.init) ?? ""
                chars = rest
            }
            else {
                result.append(ch)
                chars = chars.dropFirst()
            }
        }
        else {
            result.append(ch)
            chars = chars.dropFirst()
        }
    }
    return result
}

// MARK: - Implementations

private let coreSplit = Expr.nativeFunction(name: "split", arity: .variadic) { args in
    try requireArgCount(args, in: 2...3, function: "split")
    let s = try requireString(args[0], function: "split")
    let re = try requireRegex(args[1], function: "split", message: "second argument must be a regex")
    let limit = args.count == 3
        ? try requireInteger(args[2], function: "split", message: "limit must be an integer")
        : 0
    let parts = splitImpl(s, regex: re, limit: limit)
    return .vector(SwishPersistentVector(parts.map { .string(String($0)) }), metadata: nil)
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
    let substr = try requireString(args[1], function: "starts-with?", message: secondMustBeAString)
    return .boolean(s.hasPrefix(substr))
}

private let coreEndsWith = Expr.nativeFunction(name: "ends-with?", arity: .fixed(2)) { args in
    let s = try requireNonNilStr(args[0], function: "ends-with?")
    let substr = try requireString(args[1], function: "ends-with?", message: secondMustBeAString)
    return .boolean(s.hasSuffix(substr))
}

private let coreIncludes = Expr.nativeFunction(name: "includes?", arity: .fixed(2)) { args in
    let s = try requireString(args[0], function: "includes?")
    let substr = try requireString(args[1], function: "includes?", message: secondMustBeAString)
    return .boolean(substr.isEmpty || s.contains(substr))
}

/// Coerces an index-of/last-index-of "value" argument (a string or a single
/// character) to the string to search for.
private func stringSearchValue(_ arg: Expr, function: String) throws -> String {
    switch arg {
    case .string(let sub):
        return sub

    case .character(let c):
        return String(c)

    default:
        throw EvaluatorError.invalidArgument(function: function,
            message: "value must be a string or character")
    }
}

private func stringSearchFromIndex(_ arg: Expr, function: String) throws -> Int {
    try requireInteger(arg, function: function, message: "from-index must be an integer")
}

private let coreIndexOf = Expr.nativeFunction(name: "index-of", arity: .variadic) { args in
    try requireArgCount(args, in: 2...3, function: "index-of")
    let s = try requireString(args[0], function: "index-of")
    let needle = try stringSearchValue(args[1], function: "index-of")
    let count = s.count
    let startOffset = args.count == 3
        ? max(0, min(try stringSearchFromIndex(args[2], function: "index-of"), count))
        : 0

    if needle.isEmpty {
        return .integer(startOffset)
    }

    let startIdx = s.index(s.startIndex, offsetBy: startOffset)
    guard let range = s.range(of: needle, range: startIdx..<s.endIndex) else {
        return .nil
    }
    return .integer(s.distance(from: s.startIndex, to: range.lowerBound))
}

private let coreLastIndexOf = Expr.nativeFunction(name: "last-index-of", arity: .variadic) { args in
    try requireArgCount(args, in: 2...3, function: "last-index-of")
    let s = try requireString(args[0], function: "last-index-of")
    let needle = try stringSearchValue(args[1], function: "last-index-of")
    let count = s.count

    // Upper bound (exclusive character offset) on where a match may END. For the
    // 3-arg form the match must START at or before from-index, so it may end no
    // later than from-index + needle.count; a negative from-index means no match
    // (Java lastIndexOf semantics).
    var endOffset = count
    if args.count == 3 {
        let from = try stringSearchFromIndex(args[2], function: "last-index-of")
        if from < 0 {
            return .nil
        }
        endOffset = min(from + needle.count, count)
    }

    if needle.isEmpty {
        return .integer(endOffset)
    }

    let endIdx = s.index(s.startIndex, offsetBy: endOffset)
    guard let range = s.range(of: needle, options: .backwards, range: s.startIndex..<endIdx) else {
        return .nil
    }
    return .integer(s.distance(from: s.startIndex, to: range.lowerBound))
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
    let s = try requireString(args[0], function: "reverse")
    return .string(String(s.reversed()))
}

private let coreJoin = Expr.nativeFunction(name: "join", arity: .variadic) { args in
    try requireArgCount(args, in: 1...2, function: "join")
    let sep = args.count == 2 ? corePrinter.strString(args[0]) : ""
    let collArg = args.count == 2 ? args[1] : args[0]
    guard let elements = try asSequence(collArg) else {
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

// MARK: - Registration

func registerRegex(into evaluator: Evaluator) {
    evaluator.register(name: "re-pattern", arity: .fixed(1),
        doc: "Returns a compiled regex pattern for s. If s is already a compiled " +
             "pattern, returns it unchanged.",
        arglists: [["s"]], body: coreRePattern)

    evaluator.register(name: "re-matches", arity: .fixed(2),
        doc: "Returns the match, if any, of s to re, anchored at both the start and " +
             "end of s. Returns nil if no match, the matched string if re has no " +
             "capture groups, or a vector [match group1 group2 ...] if it does " +
             "(a non-participating group is nil in its slot).",
        arglists: [["re", "s"]], body: coreReMatches)

    evaluator.register(name: "re-find", arity: .fixed(2),
        doc: "Returns the first regex match, if any, of re anywhere in s (not " +
             "anchored). Same nil/bare-string/vector result shape as re-matches. " +
             "Only the 2-arg form is implemented — Swish has no re-matcher, so the " +
             "1-arg (re-find matcher) form does not exist.",
        arglists: [["re", "s"]], body: coreReFind)

    evaluator.register(name: "re-seq", arity: .fixed(2),
        doc: "Returns a sequence of successive matches of re in s, each shaped per " +
             "the same rule as re-matches/re-find. Unlike real Clojure, this is " +
             "computed eagerly rather than as an incrementally-realized lazy " +
             "sequence (see CLAUDE.md).",
        arglists: [["re", "s"]], body: coreReSeq)
}

// MARK: - re-pattern

private func coreRePattern(_ args: [Expr]) throws -> Expr {
    if case .regex = args[0] { return args[0] }
    guard case .string(let s) = args[0] else {
        throw EvaluatorError.invalidArgument(function: "re-pattern",
            message: "argument must be a string")
    }
    do {
        return .regex(try SwishRegex(pattern: s))
    }
    catch {
        throw EvaluatorError.invalidArgument(function: "re-pattern",
            message: "invalid regex pattern: \(error)")
    }
}

// MARK: - Shared result-shape helper

/// Converts a single regex match into Clojure's re-matches/re-find/re-seq result
/// shape: the bare matched substring if `re` has no capture groups, or a vector
/// `[whole g1 g2 ...]` if it does — a non-participating (unmatched optional) group
/// becomes `nil` in its slot.
private func regexMatchResult(_ match: Regex<AnyRegexOutput>.Match, in s: String) -> Expr {
    let whole = String(s[match.range])
    let output = match.output
    guard output.count > 1 else { return .string(whole) }

    var elements: [Expr] = [.string(whole)]

    for i in 1..<output.count {
        elements.append(output[i].substring.map { .string(String($0)) } ?? .nil)
    }

    return .vector(elements, metadata: nil)
}

// MARK: - re-matches / re-find

private func coreReMatches(_ args: [Expr]) throws -> Expr {
    guard case .regex(let re) = args[0] else {
        throw EvaluatorError.invalidArgument(function: "re-matches",
            message: "first argument must be a regex")
    }
    guard case .string(let s) = args[1] else {
        throw EvaluatorError.invalidArgument(function: "re-matches",
            message: "second argument must be a string")
    }

    guard let match = s.wholeMatch(of: re.regex) else { return .nil }
    return regexMatchResult(match, in: s)
}

private func coreReFind(_ args: [Expr]) throws -> Expr {
    guard case .regex(let re) = args[0] else {
        throw EvaluatorError.invalidArgument(function: "re-find",
            message: "first argument must be a regex")
    }
    guard case .string(let s) = args[1] else {
        throw EvaluatorError.invalidArgument(function: "re-find",
            message: "second argument must be a string")
    }

    guard let match = s.firstMatch(of: re.regex) else { return .nil }
    return regexMatchResult(match, in: s)
}

// MARK: - re-seq
//
// [Swish] Computed eagerly via `s.matches(of:)` rather than as an incrementally
// realized lazy sequence — see CLAUDE.md for why (substring-chopping to get real
// incremental laziness was tried and empirically found to break `^` anchoring).

private func coreReSeq(_ args: [Expr]) throws -> Expr {
    guard case .regex(let re) = args[0] else {
        throw EvaluatorError.invalidArgument(function: "re-seq",
            message: "first argument must be a regex")
    }
    guard case .string(let s) = args[1] else {
        throw EvaluatorError.invalidArgument(function: "re-seq",
            message: "second argument must be a string")
    }

    let results = s.matches(of: re.regex).map { regexMatchResult($0, in: s) }
    return results.isEmpty ? .nil : .seq(results)
}

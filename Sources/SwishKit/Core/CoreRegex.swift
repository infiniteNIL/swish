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

    evaluator.register(name: "re-find", arity: .atLeastOne,
        doc: "With [re s], returns the first regex match, if any, of re anywhere " +
             "in s (not anchored). With [m], returns the next match of the matcher " +
             "m (from re-matcher), advancing it, or nil once exhausted. Same " +
             "nil/bare-string/vector result shape as re-matches.",
        arglists: [["m"], ["re", "s"]], body: coreReFind)

    evaluator.register(name: "re-matcher", arity: .fixed(2),
        doc: "Returns a stateful matcher over s for re, to be used with the 1-arg " +
             "re-find and with re-groups. All matches are precomputed eagerly (see " +
             "CLAUDE.md), so the matcher walks a fixed list left-to-right.",
        arglists: [["re", "s"]], body: coreReMatcher)

    evaluator.register(name: "re-groups", arity: .fixed(1),
        doc: "Returns the groups of the most recent match of the matcher m (from a " +
             "prior re-find on m): the matched string if re has no capture groups, " +
             "or a vector [match group1 group2 ...] if it does. Throws if no match " +
             "is current (no re-find yet, or its matches are exhausted).",
        arglists: [["m"]], body: coreReGroups)

    evaluator.register(name: "re-seq", arity: .fixed(2),
        doc: "Returns a sequence of successive matches of re in s, each shaped per " +
             "the same rule as re-matches/re-find. Unlike real Clojure, this is " +
             "computed eagerly rather than as an incrementally-realized lazy " +
             "sequence (see CLAUDE.md).",
        arglists: [["re", "s"]], body: coreReSeq)
}

/// The `(re s)` argument pair shared verbatim by `re-matches`/`re-find`/`re-matcher`/
/// `re-seq` — every one of them takes a compiled pattern and a subject string in that
/// order, and reported the same two messages.
private func requireRegexAndString(_ args: [Expr], function: String) throws -> (SwishRegex, String) {
    let re = try requireRegex(args[0], function: function, message: "first argument must be a regex")
    let s = try requireString(args[1], function: function, message: "second argument must be a string")
    return (re, s)
}

// MARK: - re-pattern

private func coreRePattern(_ args: [Expr]) throws -> Expr {
    if case .regex = args[0] { return args[0] }
    let s = try requireString(args[0], function: "re-pattern")
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

    return .vector(SwishPersistentVector(elements), metadata: nil)
}

// MARK: - re-matches / re-find

private func coreReMatches(_ args: [Expr]) throws -> Expr {
    let (re, s) = try requireRegexAndString(args, function: "re-matches")

    guard let match = s.wholeMatch(of: re.regex) else { return .nil }
    return regexMatchResult(match, in: s)
}

private func coreReFind(_ args: [Expr]) throws -> Expr {
    // 1-arg matcher form: (re-find m) advances the matcher to its next match.
    if args.count == 1 {
        let m = try requireMatcher(args[0], function: "re-find",
            message: "single-argument form requires a matcher (from re-matcher)")
        return m.findNext()
    }
    guard args.count == 2 else {
        throw EvaluatorError.invalidArgument(function: "re-find",
            message: "expects [m] or [re s], got \(args.count) arguments")
    }
    let (re, s) = try requireRegexAndString(args, function: "re-find")

    guard let match = s.firstMatch(of: re.regex) else { return .nil }
    return regexMatchResult(match, in: s)
}

// MARK: - re-matcher / re-groups

private func coreReMatcher(_ args: [Expr]) throws -> Expr {
    let (re, s) = try requireRegexAndString(args, function: "re-matcher")

    let results = s.matches(of: re.regex).map { regexMatchResult($0, in: s) }
    return .matcher(SwishMatcher(results: results))
}

private func coreReGroups(_ args: [Expr]) throws -> Expr {
    let m = try requireMatcher(args[0], function: "re-groups",
        message: "argument must be a matcher (from re-matcher)")
    guard let last = m.last else {
        throw EvaluatorError.invalidArgument(function: "re-groups",
            message: "No match found — call re-find on the matcher first")
    }
    return last
}

// MARK: - re-seq
//
// [Swish] Computed eagerly via `s.matches(of:)` rather than as an incrementally
// realized lazy sequence — see CLAUDE.md for why (substring-chopping to get real
// incremental laziness was tried and empirically found to break `^` anchoring).

private func coreReSeq(_ args: [Expr]) throws -> Expr {
    let (re, s) = try requireRegexAndString(args, function: "re-seq")

    let results = s.matches(of: re.regex).map { regexMatchResult($0, in: s) }
    return results.isEmpty ? .nil : .seq(results)
}

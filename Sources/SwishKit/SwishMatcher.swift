import Synchronization

/// Swish's analogue of `java.util.regex.Matcher`: the stateful cursor produced by
/// `re-matcher`, advanced by the 1-arg `(re-find m)`, and read by `(re-groups m)`.
/// Matches are precomputed eagerly at creation (`s.matches(of:)`, the same
/// whole-string-scoped API `re-seq` uses to avoid Swift `Regex.firstMatch(of:)`'s
/// `^`-reanchoring on substrings — see CLAUDE.md), so the cursor just walks a
/// fixed, already-formatted result list. Not thread-safe by nature (Java's
/// `Matcher` isn't either); the `Mutex` here only guards against memory
/// corruption, matching the codebase's other reference cells.
public final class SwishMatcher: @unchecked Sendable {
    private struct State {
        let results: [Expr]
        var index: Int
        var last: Expr?
    }

    private let state: Mutex<State>

    init(results: [Expr]) {
        state = Mutex(State(results: results, index: 0, last: nil))
    }

    /// Advances to the next match: returns its result and records it as `last`,
    /// or returns `nil` (and clears `last`) once the precomputed matches are
    /// exhausted — mirroring `java.util.regex.Matcher.find()`.
    func findNext() -> Expr {
        state.withLock { s in
            guard s.index < s.results.count
            else {
                s.last = nil
                return .nil
            }
            let result = s.results[s.index]
            s.index += 1
            s.last = result
            return result
        }
    }

    /// The most recent successful match's result, or `nil` if none is current
    /// (no `re-find` yet on this matcher, or its matches are exhausted).
    var last: Expr? {
        state.withLock { $0.last }
    }
}

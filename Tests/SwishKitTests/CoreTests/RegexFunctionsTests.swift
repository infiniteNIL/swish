import Testing
@testable import SwishKit

@Suite("re-pattern/re-matches/re-find/re-seq Tests", .serialized)
struct RegexFunctionsTests {
    static let _shared = Swish()
    var swish: Swish { Self._shared }

    // MARK: - re-pattern

    @Test("re-pattern compiles a string")
    func rePatternCompilesString() throws {
        #expect(try swish.eval(#"(re-find (re-pattern "[0-9]+") "abc123")"#) == .string("123"))
    }

    @Test("re-pattern is idempotent on an already-compiled regex")
    func rePatternIdempotentOnRegex() throws {
        #expect(try swish.eval(#"(let [r #"\d+"] (= r (re-pattern r)))"#) == .boolean(true))
    }

    @Test("re-pattern rejects an invalid pattern string")
    func rePatternRejectsInvalidPatternString() throws {
        #expect(throws: (any Error).self) { try swish.eval(#"(re-pattern "[invalid")"#) }
    }

    @Test("re-pattern rejects a non-string, non-regex argument")
    func rePatternRejectsWrongType() throws {
        #expect(throws: (any Error).self) { try swish.eval("(re-pattern 42)") }
    }

    // MARK: - re-matches

    @Test("re-matches with no capture groups returns the bare matched string")
    func reMatchesNoGroupsReturnsBareString() throws {
        #expect(try swish.eval(#"(re-matches #"\d+" "123")"#) == .string("123"))
    }

    @Test("re-matches with capture groups returns a vector")
    func reMatchesWithGroupsReturnsVector() throws {
        #expect(
            try swish.eval(#"(re-matches #"(\d+)-(\d+)" "12-34")"#)
                == .vector([.string("12-34"), .string("12"), .string("34")], metadata: nil))
    }

    @Test("re-matches requires a whole-string match, partial match returns nil")
    func reMatchesPartialMatchReturnsNil() throws {
        #expect(try swish.eval(#"(re-matches #"\d+" "abc123")"#) == .nil)
    }

    @Test("re-matches leaves a non-participating optional group as nil")
    func reMatchesNonParticipatingGroupIsNil() throws {
        #expect(
            try swish.eval(#"(re-matches #"(a)|(b)" "a")"#)
                == .vector([.string("a"), .string("a"), .nil], metadata: nil))
    }

    @Test("re-matches rejects a non-regex first argument")
    func reMatchesRejectsNonRegexFirstArg() throws {
        #expect(throws: (any Error).self) { try swish.eval(#"(re-matches "not-a-regex" "x")"#) }
    }

    // MARK: - re-find

    @Test("re-find matches anywhere in the string, not just the whole string")
    func reFindMatchesAnywhere() throws {
        #expect(try swish.eval(#"(re-find #"\d+" "abc123def456")"#) == .string("123"))
    }

    @Test("re-find with capture groups returns a vector")
    func reFindWithGroups() throws {
        #expect(
            try swish.eval(#"(re-find #"(\d+)-(\d+)" "x 12-34 y")"#)
                == .vector([.string("12-34"), .string("12"), .string("34")], metadata: nil))
    }

    @Test("re-find with no match anywhere returns nil")
    func reFindNoMatchReturnsNil() throws {
        #expect(try swish.eval(#"(re-find #"\d+" "abc")"#) == .nil)
    }

    // MARK: - re-seq

    @Test("re-seq returns all successive matches")
    func reSeqReturnsAllMatches() throws {
        #expect(
            try swish.eval(#"(re-seq #"\d+" "1 22 333")"#)
                == .list([.string("1"), .string("22"), .string("333")], metadata: nil))
    }

    @Test("re-seq shapes each match with its own capture-group vector")
    func reSeqWithGroupsPerMatch() throws {
        #expect(
            try swish.eval(#"(re-seq #"(\w)(\d)" "a1 b2")"#)
                == .list(
                    [
                        .vector([.string("a1"), .string("a"), .string("1")], metadata: nil),
                        .vector([.string("b2"), .string("b"), .string("2")], metadata: nil),
                    ], metadata: nil))
    }

    @Test("re-seq with no matches returns nil")
    func reSeqNoMatchReturnsNil() throws {
        #expect(try swish.eval(#"(re-seq #"\d+" "abc")"#) == .nil)
    }

    @Test("re-seq unanchored control case matches every character")
    func reSeqUnanchoredControlCase() throws {
        #expect(
            try swish.eval(#"(re-seq #"." "abc")"#)
                == .list([.string("a"), .string("b"), .string("c")], metadata: nil))
    }

    @Test("re-seq with a leading-caret pattern matches only once, not once per chopped remainder")
    func reSeqAnchoredCaretMatchesOnceOnly() throws {
        #expect(try swish.eval(#"(re-seq #"^\d+" "1 2 3")"#) == .list([.string("1")], metadata: nil))
        #expect(try swish.eval(#"(count (re-seq #"^a" "aaa"))"#) == .integer(1))
    }

    @Test("re-seq's result is a seq but not a list or lazy-seq")
    func reSeqResultIsSeqNotListNotLazySeq() throws {
        #expect(try swish.eval(#"(seq? (re-seq #"\d" "1"))"#) == .boolean(true))
        #expect(try swish.eval(#"(list? (re-seq #"\d" "1"))"#) == .boolean(false))
        #expect(try swish.eval(#"(lazy-seq? (re-seq #"\d" "1"))"#) == .boolean(false))
    }

    // MARK: - re-matcher / re-find (1-arg) / re-groups

    @Test("re-matcher + repeated re-find walks successive matches, then nil")
    func reMatcherReFindWalksMatches() throws {
        #expect(
            try swish.eval(#"(let [m (re-matcher #"\d+" "a1b22c333")] [(re-find m) (re-find m) (re-find m) (re-find m)])"#)
                == .vector([.string("1"), .string("22"), .string("333"), .nil], metadata: nil))
    }

    @Test("re-find on a matcher returns capture-group vectors")
    func reMatcherReFindCaptureGroups() throws {
        #expect(
            try swish.eval(#"(let [m (re-matcher #"(\w)(\w)" "ab cd")] [(re-find m) (re-find m) (re-find m)])"#)
                == .vector([
                    .vector([.string("ab"), .string("a"), .string("b")], metadata: nil),
                    .vector([.string("cd"), .string("c"), .string("d")], metadata: nil),
                    .nil,
                ], metadata: nil))
    }

    @Test("re-groups returns the most recent match after a successful re-find")
    func reGroupsAfterReFind() throws {
        #expect(
            try swish.eval(#"(let [m (re-matcher #"(\d)(\d)" "12 34")] (re-find m) (re-groups m))"#)
                == .vector([.string("12"), .string("1"), .string("2")], metadata: nil))
    }

    @Test("re-groups with no capture groups returns the bare matched string")
    func reGroupsBareString() throws {
        #expect(
            try swish.eval(#"(let [m (re-matcher #"\d+" "abc42")] (re-find m) (re-groups m))"#)
                == .string("42"))
    }

    @Test("re-groups before any re-find throws")
    func reGroupsBeforeReFindThrows() throws {
        #expect(throws: (any Error).self) {
            try swish.eval(#"(re-groups (re-matcher #"\d+" "abc123"))"#)
        }
    }

    @Test("re-groups after the matcher is exhausted throws")
    func reGroupsAfterExhaustionThrows() throws {
        #expect(throws: (any Error).self) {
            try swish.eval(#"(let [m (re-matcher #"\d+" "a1")] (re-find m) (re-find m) (re-groups m))"#)
        }
    }

    @Test("2-arg re-find still works after the arity change")
    func reFindTwoArgStillWorks() throws {
        #expect(try swish.eval(#"(re-find #"\d+" "abc123")"#) == .string("123"))
    }

    @Test("1-arg re-find on a non-matcher throws")
    func reFindOneArgNonMatcherThrows() throws {
        #expect(throws: (any Error).self) { try swish.eval(#"(re-find "not-a-matcher")"#) }
    }

    @Test("re-groups on a non-matcher throws")
    func reGroupsNonMatcherThrows() throws {
        #expect(throws: (any Error).self) { try swish.eval("(re-groups 42)") }
    }

    @Test("a non-participating optional group is nil in its slot via a matcher")
    func reMatcherNonParticipatingGroupIsNil() throws {
        #expect(
            try swish.eval(#"(let [m (re-matcher #"(a)(b)?" "a")] (re-find m))"#)
                == .vector([.string("a"), .string("a"), .nil], metadata: nil))
    }

    @Test("a matcher is a distinct type, not an atom")
    func matcherIsDistinctType() throws {
        #expect(try swish.eval(#"(type (re-matcher #"x" "x"))"#) == .keyword("matcher"))
        #expect(try swish.eval(#"(atom? (re-matcher #"x" "x"))"#) == .boolean(false))
    }
}

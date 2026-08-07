import Testing
@testable import SwishKit

/// `clojure.string/split-lines`, including the two trailing-empty rules that conflating
/// them got wrong.
///
/// Java's `split` (which Clojure's `split-lines` delegates to) discards *every* trailing
/// empty — possibly leaving nothing, so `"\n"` is `[]` — but returns `[""]` for empty
/// input, because a pattern that never matches yields the original string. Swish trimmed
/// with a `count > 1` floor, which approximated the second rule at the cost of the first,
/// so any all-newline string wrongly came back as `[""]`.
@Suite("clojure.string split-lines Tests", .serialized)
struct ClojureStringSplitLinesTests {
    static let _shared: Swish = {
        let swish = Swish()
        _ = try? swish.eval("(require '[clojure.string :as str])")
        return swish
    }()
    var swish: Swish { Self._shared }

    private func vec(_ strings: [String]) -> Expr {
        .vector(SwishPersistentVector(strings.map { .string($0) }), metadata: nil)
    }

    // MARK: - The two trailing-empty rules

    @Test("Empty input is the one case that yields a single empty line")
    func emptyInput() throws {
        #expect(try swish.eval(#"(str/split-lines "")"#) == vec([""]))
    }

    @Test("A string of only line terminators yields no lines at all")
    func onlyTerminators() throws {
        #expect(try swish.eval(#"(str/split-lines "\n")"#) == vec([]))
        #expect(try swish.eval(#"(str/split-lines "\n\n")"#) == vec([]))
        #expect(try swish.eval(#"(str/split-lines "\n\n\n")"#) == vec([]))
        #expect(try swish.eval("(str/split-lines \"\r\n\")") == vec([]))
        #expect(try swish.eval("(str/split-lines \"\r\n\r\n\")") == vec([]))
    }

    @Test("Trailing terminators are dropped; leading and interior blanks are kept")
    func trailingVersusLeadingBlanks() throws {
        #expect(try swish.eval(#"(str/split-lines "foo\n")"#) == vec(["foo"]))
        #expect(try swish.eval(#"(str/split-lines "foo\n\n")"#) == vec(["foo"]))
        #expect(try swish.eval(#"(str/split-lines "\nbar")"#) == vec(["", "bar"]))
        #expect(try swish.eval(#"(str/split-lines "\n\nbar")"#) == vec(["", "", "bar"]))
        #expect(try swish.eval(#"(str/split-lines "foo\n\nbar")"#) == vec(["foo", "", "bar"]))
    }

    // MARK: - Ordinary splitting

    @Test("Splits on \\n, preserving surrounding whitespace within a line")
    func ordinarySplits() throws {
        #expect(try swish.eval(#"(str/split-lines "foo")"#) == vec(["foo"]))
        #expect(try swish.eval(#"(str/split-lines "foo\nbar")"#) == vec(["foo", "bar"]))
        #expect(try swish.eval(#"(str/split-lines "foo \n bar")"#) == vec(["foo ", " bar"]))
    }

    /// Swift treats `\r\n` as a single grapheme cluster that a `\r?\n` regex won't match,
    /// which is why this is implemented directly rather than via the regex `split`. A lone
    /// `\r` is *not* a line boundary, exactly as `\r?\n` requires.
    @Test("\\r\\n is a line boundary; a lone \\r is not")
    func carriageReturns() throws {
        #expect(try swish.eval("(str/split-lines \"foo\r\nbar\")") == vec(["foo", "bar"]))
        #expect(try swish.eval("(str/split-lines \"foo\nbar\r\nspam\")") == vec(["foo", "bar", "spam"]))
        #expect(try swish.eval("(str/split-lines \"foo\rbar\")") == vec(["foo\rbar"]))
    }

    @Test("Multi-scalar graphemes survive the split intact")
    func emoji() throws {
        #expect(try swish.eval(#"(str/split-lines "🫸\n🫷")"#) == vec(["🫸", "🫷"]))
    }

    // MARK: - Non-string input

    @Test("Anything that is not a string throws, including nil")
    func nonStringInput() throws {
        for form in ["(str/split-lines nil)", #"(str/split-lines \A)"#,
                     "(str/split-lines 0)", "(str/split-lines 0.0)",
                     "(str/split-lines :foo)", "(str/split-lines 'foo)",
                     "(str/split-lines [])"] {
            #expect(throws: (any Error).self, "\(form) should throw") { try swish.eval(form) }
        }
    }
}

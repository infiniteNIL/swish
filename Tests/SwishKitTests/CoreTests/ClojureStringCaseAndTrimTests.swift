import Testing
@testable import SwishKit

@Suite("clojure.string case/trim Tests", .serialized)
struct ClojureStringCaseAndTrimTests {
    static let _shared: Swish = {
        let swish = Swish()
        _ = try? swish.eval("(require '[clojure.string :as str])")
        return swish
    }()
    var swish: Swish { Self._shared }

    @Test("trim removes spaces from both ends")
    func trimBothEnds() throws {
        #expect(try swish.eval(#"(str/trim "  hello  ")"#) == .string("hello"))
    }

    @Test("trim removes tabs and newlines")
    func trimTabsNewlines() throws {
        #expect(try swish.eval("(str/trim \"\t\nhello\n\t\")") == .string("hello"))
    }

    @Test("trim on already-trimmed string is a no-op")
    func trimNoOp() throws {
        #expect(try swish.eval(#"(str/trim "hello")"#) == .string("hello"))
    }

    @Test("trim on empty string returns empty string")
    func trimEmpty() throws {
        #expect(try swish.eval(#"(str/trim "")"#) == .string(""))
    }

    @Test("trim on all-whitespace returns empty string")
    func trimAllWhitespace() throws {
        #expect(try swish.eval(#"(str/trim "   ")"#) == .string(""))
    }

    @Test("triml removes whitespace from left only")
    func trimlLeft() throws {
        #expect(try swish.eval(#"(str/triml "  hello  ")"#) == .string("hello  "))
    }

    @Test("triml on no leading whitespace is a no-op")
    func trimlNoOp() throws {
        #expect(try swish.eval(#"(str/triml "hello  ")"#) == .string("hello  "))
    }

    @Test("trimr removes whitespace from right only")
    func trimrRight() throws {
        #expect(try swish.eval(#"(str/trimr "  hello  ")"#) == .string("  hello"))
    }

    @Test("trimr on no trailing whitespace is a no-op")
    func trimrNoOp() throws {
        #expect(try swish.eval(#"(str/trimr "  hello")"#) == .string("  hello"))
    }

    @Test("trim-newline removes trailing newlines")
    func trimNewlineTrailingNewlines() throws {
        #expect(try swish.eval("(str/trim-newline \"hello\\n\\n\")") == .string("hello"))
    }

    @Test("trim-newline removes trailing carriage returns")
    func trimNewlineTrailingCR() throws {
        #expect(try swish.eval("(str/trim-newline \"hello\\r\\n\")") == .string("hello"))
    }

    @Test("trim-newline stops at non-newline character")
    func trimNewlineStopsAtNonNewline() throws {
        #expect(try swish.eval("(str/trim-newline \"hello world\\n\")") == .string("hello world"))
    }

    @Test("trim-newline on string with no trailing newlines is a no-op")
    func trimNewlineNoOp() throws {
        #expect(try swish.eval(#"(str/trim-newline "hello")"#) == .string("hello"))
    }

    @Test("trim-newline on empty string returns empty string")
    func trimNewlineEmpty() throws {
        #expect(try swish.eval(#"(str/trim-newline "")"#) == .string(""))
    }

    @Test("upper-case converts to all uppercase")
    func upperCaseBasic() throws {
        #expect(try swish.eval(#"(str/upper-case "hello")"#) == .string("HELLO"))
    }

    @Test("upper-case on already-uppercase string is a no-op")
    func upperCaseNoOp() throws {
        #expect(try swish.eval(#"(str/upper-case "HELLO")"#) == .string("HELLO"))
    }

    @Test("upper-case on empty string returns empty string")
    func upperCaseEmpty() throws {
        #expect(try swish.eval(#"(str/upper-case "")"#) == .string(""))
    }

    @Test("upper-case coerces symbol")
    func upperCaseSymbol() throws {
        #expect(try swish.eval(#"(str/upper-case 'asdf)"#) == .string("ASDF"))
        #expect(try swish.eval(#"(str/upper-case 'asdf/asdf)"#) == .string("ASDF/ASDF"))
    }

    @Test("upper-case coerces keyword")
    func upperCaseKeyword() throws {
        #expect(try swish.eval(#"(str/upper-case :asdf)"#) == .string(":ASDF"))
        #expect(try swish.eval(#"(str/upper-case :asdf/asdf)"#) == .string(":ASDF/ASDF"))
    }

    @Test("lower-case converts to all lowercase")
    func lowerCaseBasic() throws {
        #expect(try swish.eval(#"(str/lower-case "HELLO")"#) == .string("hello"))
    }

    @Test("lower-case on already-lowercase string is a no-op")
    func lowerCaseNoOp() throws {
        #expect(try swish.eval(#"(str/lower-case "hello")"#) == .string("hello"))
    }

    @Test("lower-case on empty string returns empty string")
    func lowerCaseEmpty() throws {
        #expect(try swish.eval(#"(str/lower-case "")"#) == .string(""))
    }

    @Test("lower-case coerces symbol to its name lowercased")
    func lowerCaseSymbol() throws {
        #expect(try swish.eval(#"(str/lower-case 'ASDF)"#) == .string("asdf"))
        #expect(try swish.eval(#"(str/lower-case 'ASDF/ASDF)"#) == .string("asdf/asdf"))
    }

    @Test("lower-case coerces keyword to colon+name lowercased")
    func lowerCaseKeyword() throws {
        #expect(try swish.eval(#"(str/lower-case :ASDF)"#) == .string(":asdf"))
        #expect(try swish.eval(#"(str/lower-case :ASDF/ASDF)"#) == .string(":asdf/asdf"))
    }

    @Test("capitalize on empty string returns empty string")
    func capitalizeEmpty() throws {
        #expect(try swish.eval(#"(str/capitalize "")"#) == .string(""))
    }

    @Test("capitalize on a single character upper-cases it")
    func capitalizeSingleChar() throws {
        #expect(try swish.eval(#"(str/capitalize "a")"#) == .string("A"))
    }

    @Test("capitalize upper-cases the first character and lower-cases the rest")
    func capitalizeMultiChar() throws {
        #expect(try swish.eval(#"(str/capitalize "a Thing")"#) == .string("A thing"))
        #expect(try swish.eval(#"(str/capitalize "A THING")"#) == .string("A thing"))
        #expect(try swish.eval(#"(str/capitalize "A thing")"#) == .string("A thing"))
    }

    @Test("capitalize coerces non-string arguments via str semantics")
    func capitalizeCoercion() throws {
        #expect(try swish.eval(#"(str/capitalize 1)"#) == .string("1"))
        #expect(try swish.eval(#"(str/capitalize 'Asdf)"#) == .string("Asdf"))
        #expect(try swish.eval(#"(str/capitalize 'asDf/aSdf)"#) == .string("Asdf/asdf"))
        #expect(try swish.eval(#"(str/capitalize :asDf/aSdf)"#) == .string(":asdf/asdf"))
    }

    @Test("capitalize throws for nil")
    func capitalizeNilThrows() throws {
        #expect(throws: (any Error).self) { try swish.eval("(str/capitalize nil)") }
    }

}

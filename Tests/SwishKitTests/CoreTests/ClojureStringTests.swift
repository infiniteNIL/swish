import Testing
@testable import SwishKit

@Suite("clojure.string Tests", .serialized)
struct ClojureStringTests {
    static let _shared: Swish = {
        let swish = Swish()
        _ = try? swish.eval("(require '[clojure.string :as str])")
        return swish
    }()
    var swish: Swish { Self._shared }

    @Test("join empty collection returns empty string")
    func joinEmpty() throws {
        #expect(try swish.eval("(str/join [])") == .string(""))
    }

    @Test("join single element returns that element as string")
    func joinSingle() throws {
        #expect(try swish.eval("(str/join [\"a\"])") == .string("a"))
    }

    @Test("join multiple elements concatenates without separator")
    func joinMultiple() throws {
        #expect(try swish.eval("(str/join [\"a\" \"b\" \"c\"])") == .string("abc"))
    }

    @Test("join with separator on empty collection returns empty string")
    func joinSepEmpty() throws {
        #expect(try swish.eval("(str/join \",\" [])") == .string(""))
    }

    @Test("join with separator on nil collection returns empty string")
    func joinSepNil() throws {
        #expect(try swish.eval("(str/join \",\" nil)") == .string(""))
    }

    @Test("join with separator on single element returns that element")
    func joinSepSingle() throws {
        #expect(try swish.eval("(str/join \",\" [\"a\"])") == .string("a"))
    }

    @Test("join with separator inserts separator between elements")
    func joinSepMultiple() throws {
        #expect(try swish.eval("(str/join \",\" [\"a\" \"b\" \"c\"])") == .string("a,b,c"))
    }

    @Test("join with multi-char separator")
    func joinMultiCharSep() throws {
        #expect(try swish.eval("(str/join \", \" [\"a\" \"b\" \"c\"])") == .string("a, b, c"))
    }

    @Test("join stringifies non-string elements")
    func joinNonStrings() throws {
        #expect(try swish.eval("(str/join \", \" [1 2 3])") == .string("1, 2, 3"))
    }

    @Test("join stringifies mixed types")
    func joinMixedTypes() throws {
        #expect(try swish.eval("(str/join \"-\" [1 \"b\" :c])") == .string("1-b-:c"))
    }

    @Test("join is accessible via fully qualified name")
    func joinQualified() throws {
        #expect(try swish.eval("(clojure.string/join \",\" [\"x\" \"y\"])") == .string("x,y"))
    }

    @Test("join a string treats it as a sequence of characters")
    func joinString() throws {
        #expect(try swish.eval("(str/join \"hello\")") == .string("hello"))
    }

    @Test("join with separator on a string treats it as a sequence of characters")
    func joinSepString() throws {
        #expect(try swish.eval("(str/join \"-\" \"abc\")") == .string("a-b-c"))
    }

    @Test("split basic")
    func splitBasic() throws {
        #expect(try swish.eval(#"(str/split "a,b,c" #",")"#) == .vector([.string("a"), .string("b"), .string("c")], metadata: nil))
    }

    @Test("split with positive limit caps the number of substrings")
    func splitWithLimit() throws {
        #expect(try swish.eval(#"(str/split "a,b,c" #"," 2)"#) == .vector([.string("a"), .string("b,c")], metadata: nil))
    }

    @Test("split empty string returns empty vector")
    func splitEmptyString() throws {
        #expect(try swish.eval(#"(str/split "" #",")"#) == .vector([], metadata: nil))
    }

    @Test("split keeps interior empty strings")
    func splitInteriorEmpties() throws {
        #expect(try swish.eval(#"(str/split "a,,b" #",")"#) == .vector([.string("a"), .string(""), .string("b")], metadata: nil))
    }

    @Test("split strips trailing empty strings by default")
    func splitStripsTrailingEmpties() throws {
        #expect(try swish.eval(#"(str/split "a,b," #",")"#) == .vector([.string("a"), .string("b")], metadata: nil))
    }

    @Test("split keeps leading empty string")
    func splitKeepsLeadingEmpty() throws {
        #expect(try swish.eval(#"(str/split ",a,b" #",")"#) == .vector([.string(""), .string("a"), .string("b")], metadata: nil))
    }

    @Test("split with negative limit keeps trailing empty strings")
    func splitNegativeLimit() throws {
        #expect(try swish.eval(#"(str/split "a,b," #"," -1)"#) == .vector([.string("a"), .string("b"), .string("")], metadata: nil))
    }

    @Test("split with regex separator")
    func splitRegexSeparator() throws {
        #expect(try swish.eval(#"(str/split "hello   world" #"\s+")"#) == .vector([.string("hello"), .string("world")], metadata: nil))
    }

    @Test("split no match returns single-element vector")
    func splitNoMatch() throws {
        #expect(try swish.eval(#"(str/split "foo" #",")"#) == .vector([.string("foo")], metadata: nil))
    }

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

    @Test("starts-with? returns true when string starts with substr")
    func startsWithMatch() throws {
        #expect(try swish.eval(#"(str/starts-with? "hello" "hel")"#) == .boolean(true))
    }

    @Test("starts-with? returns false when string does not start with substr")
    func startsWithNoMatch() throws {
        #expect(try swish.eval(#"(str/starts-with? "hello" "ell")"#) == .boolean(false))
    }

    @Test("starts-with? with empty substr always returns true")
    func startsWithEmptySubstr() throws {
        #expect(try swish.eval(#"(str/starts-with? "hello" "")"#) == .boolean(true))
    }

    @Test("starts-with? on empty string with empty substr returns true")
    func startsWithBothEmpty() throws {
        #expect(try swish.eval(#"(str/starts-with? "" "")"#) == .boolean(true))
    }

    @Test("starts-with? coerces symbol as first argument")
    func startsWithSymbol() throws {
        #expect(try swish.eval(#"(str/starts-with? 'ab "a")"#) == .boolean(true))
        #expect(try swish.eval(#"(str/starts-with? 'ab "b")"#) == .boolean(false))
        #expect(try swish.eval(#"(str/starts-with? 'a/b "a")"#) == .boolean(true))
    }

    @Test("starts-with? coerces keyword as first argument")
    func startsWithKeyword() throws {
        #expect(try swish.eval(#"(str/starts-with? :ab ":a")"#) == .boolean(true))
        #expect(try swish.eval(#"(str/starts-with? :ab "a")"#) == .boolean(false))
        #expect(try swish.eval(#"(str/starts-with? :a/b ":a")"#) == .boolean(true))
    }

    @Test("ends-with? returns true when string ends with substr")
    func endsWithMatch() throws {
        #expect(try swish.eval(#"(str/ends-with? "hello" "llo")"#) == .boolean(true))
    }

    @Test("ends-with? returns false when string does not end with substr")
    func endsWithNoMatch() throws {
        #expect(try swish.eval(#"(str/ends-with? "hello" "hel")"#) == .boolean(false))
    }

    @Test("ends-with? with empty substr always returns true")
    func endsWithEmptySubstr() throws {
        #expect(try swish.eval(#"(str/ends-with? "hello" "")"#) == .boolean(true))
    }

    @Test("ends-with? on empty string with empty substr returns true")
    func endsWithBothEmpty() throws {
        #expect(try swish.eval(#"(str/ends-with? "" "")"#) == .boolean(true))
    }

    @Test("ends-with? accepts symbol as first argument")
    func endsWithSymbol() throws {
        #expect(try swish.eval(#"(str/ends-with? 'ab "b")"#) == .boolean(true))
        #expect(try swish.eval(#"(str/ends-with? 'ab "a")"#) == .boolean(false))
    }

    @Test("ends-with? accepts keyword as first argument")
    func endsWithKeyword() throws {
        #expect(try swish.eval(#"(str/ends-with? :ab "b")"#) == .boolean(true))
        #expect(try swish.eval(#"(str/ends-with? :ab "a")"#) == .boolean(false))
    }

    @Test("includes? returns true when substr is in the middle")
    func includesMatch() throws {
        #expect(try swish.eval(#"(str/includes? "hello" "ell")"#) == .boolean(true))
    }

    @Test("includes? returns false when substr is not present")
    func includesNoMatch() throws {
        #expect(try swish.eval(#"(str/includes? "hello" "xyz")"#) == .boolean(false))
    }

    @Test("includes? with empty substr always returns true")
    func includesEmptySubstr() throws {
        #expect(try swish.eval(#"(str/includes? "hello" "")"#) == .boolean(true))
    }

    @Test("includes? returns true when substr equals the full string")
    func includesFullMatch() throws {
        #expect(try swish.eval(#"(str/includes? "hello" "hello")"#) == .boolean(true))
    }

    @Test("blank? returns true for nil")
    func blankNil() throws {
        #expect(try swish.eval("(str/blank? nil)") == .boolean(true))
    }

    @Test("blank? returns true for empty string")
    func blankEmpty() throws {
        #expect(try swish.eval(#"(str/blank? "")"#) == .boolean(true))
    }

    @Test("blank? returns true for all-whitespace string")
    func blankWhitespace() throws {
        #expect(try swish.eval(#"(str/blank? "   ")"#) == .boolean(true))
    }

    @Test("blank? returns false for non-whitespace string")
    func blankNonWhitespace() throws {
        #expect(try swish.eval(#"(str/blank? "hello")"#) == .boolean(false))
    }

    @Test("blank? returns false for string with whitespace and content")
    func blankMixed() throws {
        #expect(try swish.eval(#"(str/blank? "  hi  ")"#) == .boolean(false))
    }

    @Test("blank? returns true for U+2007 (Figure Space — whitespace in Swift/Unicode)")
    func blankFigureSpace() throws {
        #expect(try swish.eval("(str/blank? \"\u{2007}\")") == .boolean(true))
    }

    @Test("reverse returns empty string for empty input")
    func reverseEmpty() throws {
        #expect(try swish.eval(#"(str/reverse "")"#) == .string(""))
    }

    @Test("reverse handles single grapheme cluster (U+058E Armenian)")
    func reverseGraphemeCluster() throws {
        #expect(try swish.eval("(str/reverse \"\u{058E}\")") == .string("\u{058E}"))
    }

    @Test("reverse reverses grapheme clusters correctly")
    func reverseGraphemeClusters() throws {
        #expect(try swish.eval("(str/reverse \"\u{058E}a\")") == .string("a\u{058E}"))
    }

    @Test("reverse reverses ASCII string")
    func reverseASCII() throws {
        #expect(try swish.eval(#"(str/reverse "a-test")"#) == .string("tset-a"))
    }

    @Test("reverse throws for nil")
    func reverseNilThrows() throws {
        #expect(throws: (any Error).self) { try swish.eval("(str/reverse nil)") }
    }

    @Test("replace string/string replaces all occurrences")
    func replaceStringString() throws {
        #expect(try swish.eval(#"(str/replace "hello world" "o" "0")"#) == .string("hell0 w0rld"))
    }

    @Test("replace string/string with no match returns original")
    func replaceStringNoMatch() throws {
        #expect(try swish.eval(#"(str/replace "hello" "x" "y")"#) == .string("hello"))
    }

    @Test("replace char/char replaces all occurrences")
    func replaceCharChar() throws {
        #expect(try swish.eval(#"(str/replace "hello" \l \r)"#) == .string("herro"))
    }

    @Test("replace regex/string treats replacement as literal")
    func replaceRegexString() throws {
        #expect(try swish.eval(#"(str/replace "hello world" #"\s+" "-")"#) == .string("hello-world"))
    }

    @Test("replace regex/string with dollar sign is literal not backreference")
    func replaceRegexStringLiteral() throws {
        #expect(try swish.eval(#"(str/replace "hello" #"hello" "$0")"#) == .string("$0"))
    }

    @Test("replace regex/function calls function with each match")
    func replaceRegexFunction() throws {
        #expect(try swish.eval(#"(str/replace "hello world" #"\w+" str/upper-case)"#)
            == .string("HELLO WORLD"))
    }

    @Test("escape on empty string is a no-op regardless of cmap")
    func escapeEmptyString() throws {
        #expect(try swish.eval(#"(str/escape "" {})"#) == .string(""))
        #expect(try swish.eval(#"(str/escape "" {\c "C_C"})"#) == .string(""))
    }

    @Test("escape replaces only characters present as keys in cmap")
    func escapeSingleCharKey() throws {
        #expect(try swish.eval(#"(str/escape "abc" {\a "A_A"})"#) == .string("A_Abc"))
    }

    @Test("escape replaces multiple characters via cmap")
    func escapeMultiCharKey() throws {
        #expect(try swish.eval(#"(str/escape "abc" {\a "A_A" \c "C_C"})"#) == .string("A_AbC_C"))
    }

    @Test("escape ignores extraneous or mismatched-type cmap keys")
    func escapeIgnoresExtraneousKeys() throws {
        #expect(try swish.eval(#"(str/escape "abc" {\a "A_A" \c "C_C" (int \a) 1 nil 'junk :garbage 42.42})"#)
            == .string("A_AbC_C"))
    }

    @Test("escape throws when s is not a string")
    func escapeThrowsForNonString() throws {
        #expect(throws: (any Error).self) { try swish.eval(#"(str/escape nil {\a "A_A" \c "C_C"})"#) }
        #expect(throws: (any Error).self) { try swish.eval(#"(str/escape 1 {\a "A_A" \c "C_C"})"#) }
        #expect(throws: (any Error).self) { try swish.eval(#"(str/escape 'a {\a "A_A" \c "C_C"})"#) }
        #expect(throws: (any Error).self) { try swish.eval(#"(str/escape :a {\a "A_A" \c "C_C"})"#) }
    }
}

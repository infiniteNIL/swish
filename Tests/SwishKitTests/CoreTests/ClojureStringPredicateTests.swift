import Testing
@testable import SwishKit

@Suite("clojure.string predicate Tests", .serialized)
struct ClojureStringPredicateTests {
    static let _shared: Swish = {
        let swish = Swish()
        _ = try? swish.eval("(require '[clojure.string :as str])")
        return swish
    }()
    var swish: Swish { Self._shared }

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

}

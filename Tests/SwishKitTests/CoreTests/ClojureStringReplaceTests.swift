import Testing
@testable import SwishKit

@Suite("clojure.string replace/escape Tests", .serialized)
struct ClojureStringReplaceTests {
    static let _shared: Swish = {
        let swish = Swish()
        _ = try? swish.eval("(require '[clojure.string :as str])")
        return swish
    }()
    var swish: Swish { Self._shared }

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

    @Test("replace regex/string substitutes $0 as a whole-match backreference")
    func replaceRegexStringSubstitutesWholeMatchBackreference() throws {
        #expect(try swish.eval(#"(str/replace "hello" #"hello" "$0")"#) == .string("hello"))
    }

    @Test("replace regex/string substitutes $1/$2 capture-group backreferences")
    func replaceRegexStringSubstitutesCaptureGroups() throws {
        #expect(try swish.eval(#"(str/replace "Almost Pig Latin" #"\b(\w)(\w+)\b" "$2$1ay")"#)
            == .string("lmostAay igPay atinLay"))
    }

    @Test("replace regex/string leaves a $ with no valid group number literal")
    func replaceRegexStringLiteralDollarNoGroup() throws {
        #expect(try swish.eval(#"(str/replace "a" #"a" "$x")"#) == .string("$x"))
    }

    @Test("replace with empty string match inserts replacement between every character")
    func replaceEmptyStringMatch() throws {
        #expect(try swish.eval(#"(str/replace "x" "" "y")"#) == .string("yxy"))
        #expect(try swish.eval(#"(str/replace "x" "" "yy")"#) == .string("yyxyy"))
    }

    @Test("replace with empty input and empty match does not infinite loop")
    func replaceEmptyInputEmptyMatch() throws {
        #expect(try swish.eval(#"(str/replace "" "" "")"#) == .string(""))
    }

    @Test("replace coerces a non-string, non-nil first argument via str")
    func replaceCoercesFirstArgument() throws {
        #expect(try swish.eval(#"(str/replace :foo "foo" "bar")"#) == .string(":bar"))
        #expect(try swish.eval(#"(str/replace [:foo] "foo" "bar")"#) == .string("[:bar]"))
    }

    @Test("replace still throws for a nil first argument")
    func replaceNilFirstArgumentThrows() throws {
        #expect(throws: (any Error).self) { try swish.eval(#"(str/replace nil "x" "y")"#) }
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

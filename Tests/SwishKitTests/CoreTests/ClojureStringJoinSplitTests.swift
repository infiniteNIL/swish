import Testing
@testable import SwishKit

@Suite("clojure.string join/split Tests", .serialized)
struct ClojureStringJoinSplitTests {
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

    @Test("join propagates a lazy-seq thunk's error instead of silently truncating")
    func joinPropagatesThunkError() throws {
        #expect(throws: (any Error).self) {
            try swish.eval("(str/join (map (fn [x] (if (= x 3) (throw \"boom\") x)) [1 2 3 4 5]))")
        }
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

}

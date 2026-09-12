import Foundation
import Testing
@testable import SwishKit

@Suite("Interop: typed decoding")
struct TypedDecodeTests {
    @Test("eval infers the Swift type from context")
    func evalInfers() throws {
        let swish = Swish()

        let n: Int = try swish.eval("(+ 1 2)")
        let s: String = try swish.eval(#""hi""#)
        let xs: [Int] = try swish.eval("(range 1 4)")

        #expect(n == 3)
        #expect(s == "hi")
        #expect(xs == [1, 2, 3])
    }

    @Test("eval takes an explicit type where there is nothing to infer from")
    func evalExplicit() throws {
        let swish = Swish()

        #expect(try swish.eval("(+ 1 2)", as: Int.self) == 3)
        #expect(try swish.eval("[1 2]", as: [Int].self) == [1, 2])
    }

    @Test("The untyped eval still returns a raw Expr")
    func untypedEvalUnchanged() throws {
        let swish = Swish()

        let raw = try swish.eval("(+ 1 2)")
        #expect(raw == .integer(3))
        // Discarding must stay unambiguous — 290 call sites in this suite do it.
        _ = try swish.eval("(+ 1 2)")
    }

    @Test("A mismatch says what it wanted and what it got")
    func conversionErrorIsInformative() throws {
        let swish = Swish()

        do {
            let _: Int = try swish.eval(#""not a number""#)
            Issue.record("Expected a throw")
        }
        catch let error as SwishConversionError {
            #expect(error.expected == "Int")
            #expect(error.value == .string("not a number"))
            #expect("\(error)".contains("Int"))
        }
    }

    @Test("Expr.decode is the throwing counterpart of T(swishValue:)")
    func exprDecode() throws {
        #expect(try Expr.integer(7).decode(Int.self) == 7)
        #expect(try Expr.string("x").decode() == "x")
        expectSwishError { try Expr.string("x").decode(Int.self) }
    }

    @Test("Keyword-keyed maps decode to [String: Int]")
    func keywordKeysDecodeAsStrings() throws {
        let swish = Swish()

        let tally: [String: Int] = try swish.eval("{:a 1 :b 2}")
        #expect(tally == ["a": 1, "b": 2])
    }

    @Test("Keyword preserves the distinction, and round-trips")
    func keywordRoundTrips() throws {
        let swish = Swish()

        let tally: [Keyword: Int] = try swish.eval("{:a 1 :b 2}")
        #expect(tally == [Keyword("a"): 1, Keyword("b"): 2])

        // Handing it back keeps keyword keys, so Clojure's (:a m) still finds it.
        let found: Int = try swish.call("get", tally, Keyword("a"))
        #expect(found == 1)
    }

    @Test("A String round trip is lossy, by documented design")
    func stringRoundTripIsLossy() throws {
        let swish = Swish()

        let tally: [String: Int] = try swish.eval("{:a 1}")
        let back: Expr = try swish.call("identity", tally)
        // String always encodes to a Swish string, so the keys are no longer keywords.
        #expect(try swish.call("get", back, Keyword("a")) == Expr.nil)
        #expect(try swish.call("get", back, "a") == Expr.integer(1))
    }

    @Test("Keyword and Symbol split a qualified name")
    func qualifiedNames() throws {
        let swish = Swish()

        let k: Keyword = try swish.eval(":user/name", as: Keyword.self)
        #expect(k.namespace == "user")
        #expect(k.name == "name")
        #expect(k.description == ":user/name")

        let s: Symbol = try swish.eval("'clojure.core/map")
        #expect(s.namespace == "clojure.core")
        #expect(s.name == "map")
        #expect(s.description == "clojure.core/map")

        // A bare name has no namespace; a lone "/" is a name, not a separator.
        #expect(Keyword("a").namespace == nil)
        #expect(Keyword("/").name == "/")
    }

    @Test("A string literal still resolves to String, not Keyword")
    func stringLiteralsAreUnambiguous() throws {
        let swish = Swish()
        _ = try swish.eval(#"(defn hello [s] (str "Hello, " s))"#)

        // ExpressibleByStringLiteral on Keyword must not hijack these.
        let greeting: String = try swish.call("hello", "Swish")
        #expect(greeting == "Hello, Swish")
        try swish.define("1.2.3", as: "app-version")
        #expect(try swish.eval("app-version") == .string("1.2.3"))
    }
}

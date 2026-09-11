import Testing
@testable import SwishKit

@Suite("Interop: calling Swish from Swift")
struct SwishCallTests {
    @Test("Calls a Swish function and converts the result")
    func callsAndConverts() throws {
        let swish = Swish()
        _ = try swish.eval(#"(defn hello [s] (str "Hello, " s "!"))"#)

        let greeting: String = try swish.call("hello", "Swish")
        #expect(greeting == "Hello, Swish!")
    }

    @Test("Converts arguments on the way in")
    func convertsArguments() throws {
        let swish = Swish()
        _ = try swish.eval("(defn total [xs n] (+ (reduce + 0 xs) n))")

        let total: Int = try swish.call("total", [1, 2, 3], 4)
        #expect(total == 10)
    }

    @Test("Resolves a namespace-qualified name")
    func qualifiedName() throws {
        let swish = Swish()
        _ = try swish.eval("(ns app) (defn shout [s] (str s \"!\"))")
        _ = try swish.eval("(in-ns 'user)")

        let shouted: String = try swish.call("app/shout", "hi")
        #expect(shouted == "hi!")
    }

    @Test("A qualified name in a lib that has not been required is an error")
    func qualifiedNameNeedsRequire() throws {
        let swish = Swish()
        // Matches Clojure: clojure.string is loaded by `require`, not up front.
        expectSwishError {
            let _: String = try swish.call("clojure.string/upper-case", "abc")
        }

        _ = try swish.eval("(require 'clojure.string)")
        let upper: String = try swish.call("clojure.string/upper-case", "abc")
        #expect(upper == "ABC")
    }

    @Test("Returns a raw Expr when no conversion is asked for")
    func rawExprResult() throws {
        let swish = Swish()
        _ = try swish.eval("(defn pair [] [1 2])")

        let value: Expr = try swish.call("pair")
        #expect(value == .vector(SwishPersistentVector([.integer(1), .integer(2)]), metadata: nil))
    }

    @Test("An unconvertible result is a conversion error")
    func conversionError() throws {
        let swish = Swish()
        _ = try swish.eval(#"(defn text [] "not a number")"#)

        expectSwishError {
            let _: Int = try swish.call("text")
        }
    }

    @Test("An unknown name throws rather than trapping")
    func unknownName() throws {
        let swish = Swish()
        expectSwishError {
            let _: Int = try swish.call("no-such-function")
        }
    }

    @Test("Round-trips through a registered Swift function")
    func roundTripThroughRegistration() throws {
        let swish = Swish()
        swish.register({ (n: Int) in n * 2 }, as: "double-it")
        _ = try swish.eval("(defn quadruple [n] (double-it (double-it n)))")

        let result: Int = try swish.call("quadruple", 5)
        #expect(result == 20)
    }

    @Test("Errors thrown by the Swish function surface as SwishError")
    func swishErrorsPropagate() throws {
        let swish = Swish()
        _ = try swish.eval(#"(defn boom [] (throw (ex-info "kaboom" {})))"#)

        do {
            let _: Expr = try swish.call("boom")
            Issue.record("Expected a throw")
        }
        catch let error as SwishException {
            #expect(try swish.call("ex-message", error.value) == Expr.string("kaboom"))
        }
    }
}

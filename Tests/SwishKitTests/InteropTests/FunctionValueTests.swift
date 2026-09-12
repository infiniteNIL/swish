import Testing
@testable import SwishKit

@Suite("Interop: calling function values")
struct FunctionValueTests {
    @Test("A fn value obtained from eval is callable")
    func callsAnAnonymousFunction() throws {
        let swish = Swish()
        let double = try swish.eval("(fn [x] (* x 2))")

        let six: Int = try swish.call(double, 3)
        #expect(six == 6)
    }

    @Test("function(named:) resolves once and calls many times")
    func resolvesOnce() throws {
        let swish = Swish()
        _ = try swish.eval("(defn shout [s] (str s \"!\"))")

        let shout = try swish.function(named: "shout")
        #expect(try swish.call(shout, "a") as String == "a!")
        #expect(try swish.call(shout, "b") as String == "b!")
    }

    @Test("A function Swish hands back can be called from Swift")
    func callsACallbackFromSwish() throws {
        let swish = Swish()
        _ = try swish.eval("(defn adder [n] (fn [x] (+ x n)))")

        let addTen = try swish.call("adder", 10)
        #expect(try swish.call(addTen, 5) as Int == 15)
    }

    @Test("A pre-built argument list works where varargs can't")
    func nonVariadicForm() throws {
        let swish = Swish()
        _ = try swish.eval("(defn total [& xs] (reduce + 0 xs))")

        let args: [any SwishRepresentable] = [1, 2, 3, 4]
        #expect(try swish.call("total", arguments: args) as Int == 10)

        let total = try swish.function(named: "total")
        #expect(try swish.call(total, arguments: args) as Int == 10)
    }

    @Test("Swish's other callables work too, matching Clojure")
    func collectionsAreCallable() throws {
        let swish = Swish()
        let map = try swish.eval("{:a 1 :b 2}")

        // A keyword, map, vector or set is callable in Clojure; so here.
        #expect(try swish.call(Expr.keyword("a"), map) as Int == 1)
        #expect(try swish.call(map, Keyword("b")) as Int == 2)
        #expect(try swish.call(try swish.eval("[10 20 30]"), 1) as Int == 20)
    }

    @Test("Calling a non-function is an error, not a crash")
    func nonCallableThrows() throws {
        let swish = Swish()
        expectSwishError { try swish.call(Expr.integer(1), 2) as Expr }
    }

    @Test("A raw Expr result is available without conversion")
    func rawResult() throws {
        let swish = Swish()
        let identity = try swish.eval("(fn [x] x)")

        let result: Expr = try swish.call(identity, "hi")
        #expect(result == .string("hi"))
    }
}

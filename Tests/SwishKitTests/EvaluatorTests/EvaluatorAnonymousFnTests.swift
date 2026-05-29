import Testing
@testable import SwishKit

@Suite("Evaluator Anonymous Fn Tests")
struct EvaluatorAnonymousFnTests {
    let swish = Swish()

    @Test("Single arg with %")
    func singleArgBarePercent() throws {
        let result = try swish.eval("(#(+ % 1) 5)")
        #expect(result == .integer(6))
    }

    @Test("Single arg with %1")
    func singleArgExplicit() throws {
        let result = try swish.eval("(#(+ %1 1) 5)")
        #expect(result == .integer(6))
    }

    @Test("Two positional args")
    func twoArgs() throws {
        let result = try swish.eval("(#(+ %1 %2) 3 4)")
        #expect(result == .integer(7))
    }

    @Test("Zero-arity fn")
    func zeroArity() throws {
        let result = try swish.eval("(#(+ 1 2))")
        #expect(result == .integer(3))
    }

    @Test("Empty body returns nil")
    func emptyBody() throws {
        let result = try swish.eval("(#())")
        #expect(result == .nil)
    }

    @Test("Rest arg")
    func restArg() throws {
        let result = try swish.eval("(#(apply str %&) \"a\" \"b\")")
        #expect(result == .string("ab"))
    }

    @Test("Used as higher-order function argument")
    func higherOrder() throws {
        let result = try swish.eval("(map #(* % 2) [1 2 3])")
        #expect(result == .list([.integer(2), .integer(4), .integer(6)], metadata: nil))
    }

    @Test("Assigned to a var and called")
    func assignedToVar() throws {
        _ = try swish.eval("(def f #(+ % 10))")
        let result = try swish.eval("(f 5)")
        #expect(result == .integer(15))
    }

    @Test("Gap-filling: %2 without %1 generates two params")
    func gapFilling() throws {
        let result = try swish.eval("(#(str %2) \"ignored\" \"hello\")")
        #expect(result == .string("hello"))
    }

    @Test("% outside anonymous fn is an unbound symbol")
    func barePercentOutsideAnonFn() throws {
        #expect(throws: EvaluatorError.self) {
            try swish.eval("%")
        }
    }
}

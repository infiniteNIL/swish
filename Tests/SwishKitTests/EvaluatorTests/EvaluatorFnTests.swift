import Testing
@testable import SwishKit

@Suite("Evaluator Fn Tests")
struct EvaluatorFnTests {
    let evaluator = Evaluator()

    @Test("fn evaluates to a function value")
    func fnEvaluatesToFunction() throws {
        let result = try evaluator.eval(.list([.symbol("fn", metadata: nil), .vector([.symbol("x", metadata: nil)], metadata: nil), .symbol("x", metadata: nil)], metadata: nil))
        #expect(result == .function(name: nil, params: ["x"], body: [.symbol("x", metadata: nil)], metadata: nil))
    }

    @Test("fn with no params evaluates to a zero-param function")
    func fnNoParamsEvaluatesToFunction() throws {
        let result = try evaluator.eval(.list([.symbol("fn", metadata: nil), .vector([], metadata: nil), .integer(42)], metadata: nil))
        #expect(result == .function(name: nil, params: [], body: [.integer(42)], metadata: nil))
    }

    @Test("Named fn evaluates to a function with name")
    func namedFnEvaluatesToNamedFunction() throws {
        let result = try evaluator.eval(.list([
            .symbol("fn", metadata: nil), .symbol("square", metadata: nil),
            .vector([.symbol("x", metadata: nil)], metadata: nil),
            .list([.symbol("*", metadata: nil), .symbol("x", metadata: nil), .symbol("x", metadata: nil)], metadata: nil)
        ], metadata: nil))
        #expect(result == .function(
            name: "square",
            params: ["x"],
            body: [.list([.symbol("clojure.core/*", metadata: nil), .symbol("x", metadata: nil), .symbol("x", metadata: nil)], metadata: nil)],
            metadata: nil
        ))
    }

    @Test("Immediately invoked fn returns body result")
    func immediatelyInvokedFn() throws {
        // ((fn [x] x) 5) => 5
        let result = try evaluator.eval(.list([
            .list([.symbol("fn", metadata: nil), .vector([.symbol("x", metadata: nil)], metadata: nil), .symbol("x", metadata: nil)], metadata: nil),
            .integer(5)
        ], metadata: nil))
        #expect(result == .integer(5))
    }

    @Test("fn with multiple params binds all arguments")
    func fnMultipleParams() throws {
        // ((fn [x y] (+ x y)) 2 3) => 5
        let result = try evaluator.eval(.list([
            .list([
                .symbol("fn", metadata: nil),
                .vector([.symbol("x", metadata: nil), .symbol("y", metadata: nil)], metadata: nil),
                .list([.symbol("+", metadata: nil), .symbol("x", metadata: nil), .symbol("y", metadata: nil)], metadata: nil)
            ], metadata: nil),
            .integer(2),
            .integer(3)
        ], metadata: nil))
        #expect(result == .integer(5))
    }

    @Test("fn with no params called with no args returns body result")
    func fnNoParamsCall() throws {
        // ((fn [] 42)) => 42
        let result = try evaluator.eval(.list([
            .list([.symbol("fn", metadata: nil), .vector([], metadata: nil), .integer(42)], metadata: nil)
        ], metadata: nil))
        #expect(result == .integer(42))
    }

    @Test("fn with multi-expression body returns last expression")
    func fnMultiExprBody() throws {
        // ((fn [x] 1 2 x) 7) => 7
        let result = try evaluator.eval(.list([
            .list([
                .symbol("fn", metadata: nil),
                .vector([.symbol("x", metadata: nil)], metadata: nil),
                .integer(1),
                .integer(2),
                .symbol("x", metadata: nil)
            ], metadata: nil),
            .integer(7)
        ], metadata: nil))
        #expect(result == .integer(7))
    }

    @Test("fn with empty body returns nil")
    func fnEmptyBody() throws {
        // ((fn [])) => nil
        let result = try evaluator.eval(.list([
            .list([.symbol("fn", metadata: nil), .vector([], metadata: nil)], metadata: nil)
        ], metadata: nil))
        #expect(result == .nil)
    }

    @Test("def can bind a fn and it can be called by name")
    func defFnAndCall() throws {
        // (def double (fn [x] (+ x x)))
        // (double 4) => 8
        _ = try evaluator.eval(.list([
            .symbol("def", metadata: nil), .symbol("double", metadata: nil),
            .list([
                .symbol("fn", metadata: nil),
                .vector([.symbol("x", metadata: nil)], metadata: nil),
                .list([.symbol("+", metadata: nil), .symbol("x", metadata: nil), .symbol("x", metadata: nil)], metadata: nil)
            ], metadata: nil)
        ], metadata: nil))
        let result = try evaluator.eval(.list([.symbol("double", metadata: nil), .integer(4)], metadata: nil))
        #expect(result == .integer(8))
    }

    @Test("fn closes over let bindings in enclosing scope")
    func fnClosesOverLetBindings() throws {
        // (let [x 10] ((fn [y] (+ x y)) 5)) => 15
        let result = try evaluator.eval(.list([
            .symbol("let", metadata: nil),
            .vector([.symbol("x", metadata: nil), .integer(10)], metadata: nil),
            .list([
                .list([
                    .symbol("fn", metadata: nil),
                    .vector([.symbol("y", metadata: nil)], metadata: nil),
                    .list([.symbol("+", metadata: nil), .symbol("x", metadata: nil), .symbol("y", metadata: nil)], metadata: nil)
                ], metadata: nil),
                .integer(5)
            ], metadata: nil)
        ], metadata: nil))
        #expect(result == .integer(15))
    }

    @Test("Calling fn with too few arguments throws arityMismatch")
    func fnTooFewArgsThrows() throws {
        #expect(throws: EvaluatorError.arityMismatch(name: "fn", expected: .fixed(2), got: 1)) {
            try evaluator.eval(.list([
                .list([
                    .symbol("fn", metadata: nil),
                    .vector([.symbol("x", metadata: nil), .symbol("y", metadata: nil)], metadata: nil),
                    .symbol("x", metadata: nil)
                ], metadata: nil),
                .integer(1)
            ], metadata: nil))
        }
    }

    @Test("Calling fn with too many arguments throws arityMismatch")
    func fnTooManyArgsThrows() throws {
        #expect(throws: EvaluatorError.arityMismatch(name: "fn", expected: .fixed(1), got: 2)) {
            try evaluator.eval(.list([
                .list([
                    .symbol("fn", metadata: nil),
                    .vector([.symbol("x", metadata: nil)], metadata: nil),
                    .symbol("x", metadata: nil)
                ], metadata: nil),
                .integer(1),
                .integer(2)
            ], metadata: nil))
        }
    }

    @Test("Named fn uses its name in arity mismatch error")
    func namedFnArityMismatchUsesName() throws {
        #expect(throws: EvaluatorError.arityMismatch(name: "inc", expected: .fixed(1), got: 0)) {
            try evaluator.eval(.list([
                .list([
                    .symbol("fn", metadata: nil),
                    .symbol("inc", metadata: nil),
                    .vector([.symbol("x", metadata: nil)], metadata: nil),
                    .symbol("x", metadata: nil)
                ], metadata: nil)
            ], metadata: nil))
        }
    }

    @Test("fn with unknown symbol in body succeeds at definition time")
    func fnUnknownSymbolDefinitionSucceeds() throws {
        #expect(throws: Never.self) {
            try evaluator.eval(.list([.symbol("fn", metadata: nil), .vector([], metadata: nil), .symbol("x", metadata: nil)], metadata: nil))
        }
    }

    @Test("fn with unknown symbol throws undefinedSymbol at call time")
    func fnUnknownSymbolCallTimeThrows() throws {
        let fn = try evaluator.eval(.list([.symbol("fn", metadata: nil), .vector([], metadata: nil), .symbol("x", metadata: nil)], metadata: nil))
        #expect(throws: EvaluatorError.undefinedSymbol("x")) {
            try evaluator.eval(.list([fn], metadata: nil))
        }
    }

    @Test("fn does not throw for symbols that are parameters")
    func fnParamSymbolsAreValid() throws {
        // (fn [x] x) — x is a param, should not throw
        #expect(throws: Never.self) {
            try evaluator.eval(.list([.symbol("fn", metadata: nil), .vector([.symbol("x", metadata: nil)], metadata: nil), .symbol("x", metadata: nil)], metadata: nil))
        }
    }

    @Test("fn does not throw for symbols defined in the enclosing environment")
    func fnClosedOverSymbolIsValid() throws {
        // (let [x 1] (fn [] x)) — x is in scope, should not throw
        #expect(throws: Never.self) {
            try evaluator.eval(.list([
                .symbol("let", metadata: nil),
                .vector([.symbol("x", metadata: nil), .integer(1)], metadata: nil),
                .list([.symbol("fn", metadata: nil), .vector([], metadata: nil), .symbol("x", metadata: nil)], metadata: nil)
            ], metadata: nil))
        }
    }

    @Test("fn with unknown symbol nested in body succeeds at definition time")
    func fnNestedUnknownSymbolDefinitionSucceeds() throws {
        #expect(throws: Never.self) {
            try evaluator.eval(.list([
                .symbol("fn", metadata: nil),
                .vector([.symbol("x", metadata: nil)], metadata: nil),
                .list([.symbol("+", metadata: nil), .symbol("x", metadata: nil), .symbol("y", metadata: nil)], metadata: nil)
            ], metadata: nil))
        }
    }

    @Test("fn with unknown symbol nested in body throws undefinedSymbol at call time")
    func fnNestedUnknownSymbolCallTimeThrows() throws {
        let fn = try evaluator.eval(.list([
            .symbol("fn", metadata: nil),
            .vector([.symbol("x", metadata: nil)], metadata: nil),
            .list([.symbol("+", metadata: nil), .symbol("x", metadata: nil), .symbol("y", metadata: nil)], metadata: nil)
        ], metadata: nil))
        #expect(throws: EvaluatorError.undefinedSymbol("y")) {
            try evaluator.eval(.list([fn, .integer(1)], metadata: nil))
        }
    }

    @Test("fn with nested fn checks inner body with inner params")
    func fnNestedFnUsesInnerParams() throws {
        // (fn [x] (fn [y] (+ x y))) — both x and y are in scope for inner body
        #expect(throws: Never.self) {
            try evaluator.eval(.list([
                .symbol("fn", metadata: nil),
                .vector([.symbol("x", metadata: nil)], metadata: nil),
                .list([
                    .symbol("fn", metadata: nil),
                    .vector([.symbol("y", metadata: nil)], metadata: nil),
                    .list([.symbol("+", metadata: nil), .symbol("x", metadata: nil), .symbol("y", metadata: nil)], metadata: nil)
                ], metadata: nil)
            ], metadata: nil))
        }
    }

    @Test("fn with let in body sees let-bound symbols")
    func fnLetBindingInBody() throws {
        // (fn [] (let [x 1] x)) — x is bound by let, should not throw
        #expect(throws: Never.self) {
            try evaluator.eval(.list([
                .symbol("fn", metadata: nil),
                .vector([], metadata: nil),
                .list([
                    .symbol("let", metadata: nil),
                    .vector([.symbol("x", metadata: nil), .integer(1)], metadata: nil),
                    .symbol("x", metadata: nil)
                ], metadata: nil)
            ], metadata: nil))
        }
    }

    // MARK: - Variadic parameters (& rest)

    @Test("fn with & rest collects extra args into a list")
    func fnVariadicRestCollectsExtraArgs() throws {
        // (def f (fn [x & rest] rest))
        // (f 1 2 3) => (2 3)
        let swish = Swish()
        let result = try swish.eval("(def f (fn [x & rest] rest)) (f 1 2 3)")
        #expect(result == .list([.integer(2), .integer(3)], metadata: nil))
    }

    @Test("fn with & rest and no extra args binds empty list")
    func fnVariadicRestBindsEmptyList() throws {
        // (def f (fn [x & rest] rest))
        // (f 1) => ()
        let swish = Swish()
        let result = try swish.eval("(def f (fn [x & rest] rest)) (f 1)")
        #expect(result == .list([], metadata: nil))
    }

    @Test("fn with only & rest param collects all args")
    func fnOnlyRestParamCollectsAll() throws {
        // (def f (fn [& args] args))
        // (f 1 2 3) => (1 2 3)
        let swish = Swish()
        let result = try swish.eval("(def f (fn [& args] args)) (f 1 2 3)")
        #expect(result == .list([.integer(1), .integer(2), .integer(3)], metadata: nil))
    }

    @Test("fn with only & rest param called with no args binds empty list")
    func fnOnlyRestParamNoArgs() throws {
        // (def f (fn [& args] args))
        // (f) => ()
        let swish = Swish()
        let result = try swish.eval("(def f (fn [& args] args)) (f)")
        #expect(result == .list([], metadata: nil))
    }

    @Test("fn with & rest too few fixed args throws arityMismatch")
    func fnVariadicTooFewFixedArgs() throws {
        // (def f (fn [x y & rest] rest))
        // (f 1) => throws arityMismatch
        let swish = Swish()
        _ = try swish.eval("(def f (fn [x y & rest] rest))")
        #expect(throws: EvaluatorError.arityMismatch(name: "fn", expected: .fixed(2), got: 1)) {
            try swish.eval("(f 1)")
        }
    }

    @Test("fn with & rest binds fixed params and rest correctly")
    func fnVariadicFixedAndRest() throws {
        // (def f (fn [a b & rest] (+ a b)))
        // (f 3 4 5 6) => 7
        let swish = Swish()
        let result = try swish.eval("(def f (fn [a b & rest] (+ a b))) (f 3 4 5 6)")
        #expect(result == .integer(7))
    }
}

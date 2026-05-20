import Testing
@testable import SwishKit

@Suite("Evaluator Special Forms Tests")
struct EvaluatorSpecialFormsTests {
    let evaluator = Evaluator()

    // MARK: - def special form

    @Test("def binds a value and returns the varRef")
    func defBindsValueAndReturnsVarRef() throws {
        let result = try evaluator.eval(.list([.symbol("def", metadata: nil), .symbol("x", metadata: nil), .integer(10)], metadata: nil))
        guard case .varRef(let v) = result else {
            Issue.record("Expected .varRef, got \(result)")
            return
        }
        #expect(v.name == "x")
        #expect(v.value == .integer(10))
    }

    @Test("Symbol lookup after def")
    func symbolLookupAfterDef() throws {
        _ = try evaluator.eval(.list([.symbol("def", metadata: nil), .symbol("y", metadata: nil), .integer(42)], metadata: nil))
        let result = try evaluator.eval(.symbol("y", metadata: nil))
        #expect(result == .integer(42))
    }

    @Test("Redefining overwrites previous binding")
    func redefiningOverwritesBinding() throws {
        _ = try evaluator.eval(.list([.symbol("def", metadata: nil), .symbol("z", metadata: nil), .integer(1)], metadata: nil))
        _ = try evaluator.eval(.list([.symbol("def", metadata: nil), .symbol("z", metadata: nil), .integer(2)], metadata: nil))
        let result = try evaluator.eval(.symbol("z", metadata: nil))
        #expect(result == .integer(2))
    }

    @Test("Undefined symbol throws undefinedSymbol")
    func undefinedSymbolThrows() throws {
        #expect(throws: EvaluatorError.undefinedSymbol("unknown")) {
            try evaluator.eval(.symbol("unknown", metadata: nil))
        }
    }

    @Test("def evaluates its value argument")
    func defEvaluatesValueArgument() throws {
        let result = try evaluator.eval(.list([.symbol("def", metadata: nil), .symbol("x", metadata: nil),
            .list([.symbol("def", metadata: nil), .symbol("y", metadata: nil), .integer(5)], metadata: nil)], metadata: nil))

        guard case .varRef(let xVar) = result else {
            Issue.record("Expected .varRef for x, got \(result)")
            return
        }
        #expect(xVar.name == "x")

        guard case .varRef(let yVar) = xVar.value else {
            Issue.record("Expected x's value to be .varRef for y, got \(String(describing: xVar.value))")
            return
        }
        #expect(yVar.name == "y")

        let yValue = try evaluator.eval(.symbol("y", metadata: nil))
        #expect(yValue == .integer(5))
    }

    @Test("def with apostrophe in symbol name")
    func defWithApostropheSymbol() throws {
        let exprs = try Reader.readString("(def a'b 5)")
        #expect(exprs.count == 1)

        let result = try evaluator.eval(exprs[0])
        guard case .varRef(let v) = result else {
            Issue.record("Expected .varRef, got \(result)")
            return
        }
        #expect(v.name == "a'b")

        let value = try evaluator.eval(.symbol("a'b", metadata: nil))
        #expect(value == .integer(5))
    }

    // MARK: - if special form

    @Test("if with no arguments throws")
    func ifNoArgumentsThrows() throws {
        #expect(throws: EvaluatorError.invalidArgument(function: "if",
            message: "requires a condition and a then-branch")) {
            try evaluator.eval(.list([.symbol("if", metadata: nil)], metadata: nil))
        }
    }

    @Test("if with only condition throws")
    func ifOnlyConditionThrows() throws {
        #expect(throws: EvaluatorError.invalidArgument(function: "if",
            message: "requires a condition and a then-branch")) {
            try evaluator.eval(.list([.symbol("if", metadata: nil), .boolean(true)], metadata: nil))
        }
    }

    @Test("if with truthy condition evaluates then-branch")
    func ifTruthyEvalsThenBranch() throws {
        let result = try evaluator.eval(.list([.symbol("if", metadata: nil), .boolean(true), .integer(1), .integer(2)], metadata: nil))
        #expect(result == .integer(1))
    }

    @Test("if with false evaluates else-branch")
    func ifFalseEvalsElseBranch() throws {
        let result = try evaluator.eval(.list([.symbol("if", metadata: nil), .boolean(false), .integer(1), .integer(2)], metadata: nil))
        #expect(result == .integer(2))
    }

    @Test("if with nil evaluates else-branch")
    func ifNilEvalsElseBranch() throws {
        let result = try evaluator.eval(.list([.symbol("if", metadata: nil), .nil, .integer(1), .integer(2)], metadata: nil))
        #expect(result == .integer(2))
    }

    @Test("if with 0 evaluates then-branch (0 is truthy)")
    func ifZeroEvalsThenBranch() throws {
        let result = try evaluator.eval(.list([.symbol("if", metadata: nil), .integer(0), .integer(1), .integer(2)], metadata: nil))
        #expect(result == .integer(1))
    }

    @Test("if with falsy condition and no else-branch returns nil")
    func ifFalsyNoElseReturnsNil() throws {
        let result = try evaluator.eval(.list([.symbol("if", metadata: nil), .boolean(false), .integer(1)], metadata: nil))
        #expect(result == .nil)
    }

    @Test("if with truthy condition and no else-branch evaluates then-branch")
    func ifTruthyNoElseEvalsThenBranch() throws {
        let result = try evaluator.eval(.list([.symbol("if", metadata: nil), .boolean(true), .integer(42)], metadata: nil))
        #expect(result == .integer(42))
    }

    // MARK: - let special form

    @Test("let with no body returns nil")
    func letNoBodyReturnsNil() throws {
        let result = try evaluator.eval(.list([.symbol("let", metadata: nil), .vector([], metadata: nil)], metadata: nil))
        #expect(result == .nil)
    }

    @Test("let with empty bindings evaluates body")
    func letEmptyBindingsEvaluatesBody() throws {
        let result = try evaluator.eval(.list([.symbol("let", metadata: nil), .vector([], metadata: nil), .integer(42)], metadata: nil))
        #expect(result == .integer(42))
    }

    @Test("let binds a symbol and returns it from body")
    func letBindsSymbol() throws {
        let result = try evaluator.eval(.list([
            .symbol("let", metadata: nil),
            .vector([.symbol("x", metadata: nil), .integer(1)], metadata: nil),
            .symbol("x", metadata: nil)
        ], metadata: nil))
        #expect(result == .integer(1))
    }

    @Test("let with multiple bindings evaluates body with all bindings")
    func letMultipleBindings() throws {
        let result = try evaluator.eval(.list([
            .symbol("let", metadata: nil),
            .vector([.symbol("x", metadata: nil), .integer(1), .symbol("y", metadata: nil), .integer(2)], metadata: nil),
            .list([.symbol("+", metadata: nil), .symbol("x", metadata: nil), .symbol("y", metadata: nil)], metadata: nil)
        ], metadata: nil))
        #expect(result == .integer(3))
    }

    @Test("let returns last body expression")
    func letReturnsLastBodyExpr() throws {
        let result = try evaluator.eval(.list([
            .symbol("let", metadata: nil),
            .vector([.symbol("x", metadata: nil), .integer(1)], metadata: nil),
            .integer(99),
            .symbol("x", metadata: nil)
        ], metadata: nil))
        #expect(result == .integer(1))
    }

    @Test("let bindings are sequential (later can reference earlier)")
    func letSequentialBindings() throws {
        let result = try evaluator.eval(.list([
            .symbol("let", metadata: nil),
            .vector([
                .symbol("x", metadata: nil), .integer(1),
                .symbol("y", metadata: nil), .list([.symbol("+", metadata: nil), .symbol("x", metadata: nil), .integer(1)], metadata: nil)
            ], metadata: nil),
            .symbol("y", metadata: nil)
        ], metadata: nil))
        #expect(result == .integer(2))
    }

    @Test("let is lexically scoped (binding not visible outside)")
    func letBindingNotVisibleOutside() throws {
        _ = try evaluator.eval(.list([
            .symbol("let", metadata: nil), .vector([.symbol("local", metadata: nil), .integer(7)], metadata: nil), .symbol("local", metadata: nil)
        ], metadata: nil))
        #expect(throws: EvaluatorError.undefinedSymbol("local")) {
            try evaluator.eval(.symbol("local", metadata: nil))
        }
    }

    @Test("nested let can reference outer binding")
    func nestedLetReferencesOuter() throws {
        let result = try evaluator.eval(.list([
            .symbol("let", metadata: nil),
            .vector([.symbol("x", metadata: nil), .integer(10)], metadata: nil),
            .list([
                .symbol("let", metadata: nil),
                .vector([.symbol("y", metadata: nil), .integer(20)], metadata: nil),
                .list([.symbol("+", metadata: nil), .symbol("x", metadata: nil), .symbol("y", metadata: nil)], metadata: nil)
            ], metadata: nil)
        ], metadata: nil))
        #expect(result == .integer(30))
    }

    @Test("let can shadow outer binding")
    func letShadowsOuterBinding() throws {
        _ = try evaluator.eval(.list([.symbol("def", metadata: nil), .symbol("x", metadata: nil), .integer(1)], metadata: nil))
        let result = try evaluator.eval(.list([
            .symbol("let", metadata: nil),
            .vector([.symbol("x", metadata: nil), .integer(99)], metadata: nil),
            .symbol("x", metadata: nil)
        ], metadata: nil))
        #expect(result == .integer(99))
        // outer x is unchanged
        #expect(try evaluator.eval(.symbol("x", metadata: nil)) == .integer(1))
    }

    // MARK: - do special form

    @Test("do with no expressions returns nil")
    func doNoExpressionsReturnsNil() throws {
        let result = try evaluator.eval(.list([.symbol("do", metadata: nil)], metadata: nil))
        #expect(result == .nil)
    }

    @Test("do with single expression returns it")
    func doSingleExpressionReturnsIt() throws {
        let result = try evaluator.eval(.list([.symbol("do", metadata: nil), .integer(42)], metadata: nil))
        #expect(result == .integer(42))
    }

    @Test("do with multiple expressions returns last")
    func doMultipleExpressionsReturnsLast() throws {
        let result = try evaluator.eval(.list([.symbol("do", metadata: nil), .integer(1), .integer(2), .integer(3)], metadata: nil))
        #expect(result == .integer(3))
    }

    @Test("do evaluates side effects")
    func doEvaluatesSideEffects() throws {
        let result = try evaluator.eval(.list([
            .symbol("do", metadata: nil),
            .list([.symbol("def", metadata: nil), .symbol("doSideEffect", metadata: nil), .integer(7)], metadata: nil),
            .symbol("doSideEffect", metadata: nil)
        ], metadata: nil))
        #expect(result == .integer(7))
    }

    @Test("nested do returns last expression of outer")
    func nestedDoReturnsLastOfOuter() throws {
        let result = try evaluator.eval(.list([
            .symbol("do", metadata: nil),
            .list([.symbol("do", metadata: nil), .integer(1), .integer(2)], metadata: nil),
            .integer(3)
        ], metadata: nil))
        #expect(result == .integer(3))
    }

    // MARK: - quote special form

    @Test("(quote x) returns symbol unevaluated")
    func quoteReturnsSymbolUnevaluated() throws {
        let result = try evaluator.eval(.list([.symbol("quote", metadata: nil), .symbol("x", metadata: nil)], metadata: nil))
        #expect(result == .symbol("x", metadata: nil))
    }

    @Test("(quote) with no argument throws")
    func quoteNoArgumentThrows() throws {
        #expect(throws: EvaluatorError.invalidArgument(function: "quote", message: "requires exactly 1 argument")) {
            try evaluator.eval(.list([.symbol("quote", metadata: nil)], metadata: nil))
        }
    }

    // MARK: - Native functions

    @Test("Native function self-evaluates")
    func nativeFunctionSelfEvaluates() throws {
        let fn = Expr.nativeFunction(name: "inc", arity: .fixed(1)) { args in .integer(0) }
        let result = try evaluator.eval(fn)
        #expect(result == fn)
    }

    @Test("register places native function in clojure.core namespace")
    func registerPlacesNativeFunctionInCoreEnvironment() {
        let evaluator = Evaluator()
        evaluator.register(name: "inc", arity: .fixed(1)) { args in args[0] }
        let stored = evaluator.findNs("clojure.core")?.findVar(name: "inc")?.value
        #expect(stored == .nativeFunction(name: "inc", arity: .fixed(1)) { _ in .nil })
    }

    @Test("Calling a fixed-arity native function returns its result")
    func callingFixedArityNativeFunction() throws {
        let evaluator = Evaluator()
        evaluator.register(name: "inc", arity: .fixed(1)) { args in
            guard case .integer(let n) = args[0] else { return .nil }
            return .integer(n + 1)
        }
        let result = try evaluator.eval(.list([.symbol("inc", metadata: nil), .integer(4)], metadata: nil))
        #expect(result == .integer(5))
    }

    @Test("Calling a native function with wrong arity throws arityMismatch")
    func callingNativeFunctionWithWrongArityThrows() throws {
        let evaluator = Evaluator()
        evaluator.register(name: "inc", arity: .fixed(1)) { args in args[0] }
        #expect(throws: EvaluatorError.arityMismatch(name: "inc", expected: .fixed(1), got: 2)) {
            try evaluator.eval(.list([.symbol("inc", metadata: nil), .integer(1), .integer(2)], metadata: nil))
        }
    }

    @Test("Calling a variadic native function works with any number of args")
    func callingVariadicNativeFunction() throws {
        let evaluator = Evaluator()
        evaluator.register(name: "count", arity: .variadic) { args in .integer(args.count) }
        #expect(try evaluator.eval(.list([.symbol("count", metadata: nil)], metadata: nil)) == .integer(0))
        #expect(try evaluator.eval(.list([.symbol("count", metadata: nil), .integer(1), .integer(2)], metadata: nil)) == .integer(2))
    }
}

import Testing
@testable import SwishKit

@Suite("Evaluator Special Forms Tests")
struct EvaluatorSpecialFormsTests {
    let evaluator = Evaluator()

    // MARK: - def special form

    @Test("def binds a value and returns the symbol")
    func defBindsValueAndReturnsSymbol() throws {
        let result = try evaluator.eval(.list([.symbol("def"), .symbol("x"), .integer(10)]))
        #expect(result == .symbol("x"))
    }

    @Test("Symbol lookup after def")
    func symbolLookupAfterDef() throws {
        _ = try evaluator.eval(.list([.symbol("def"), .symbol("y"), .integer(42)]))
        let result = try evaluator.eval(.symbol("y"))
        #expect(result == .integer(42))
    }

    @Test("Redefining overwrites previous binding")
    func redefiningOverwritesBinding() throws {
        _ = try evaluator.eval(.list([.symbol("def"), .symbol("z"), .integer(1)]))
        _ = try evaluator.eval(.list([.symbol("def"), .symbol("z"), .integer(2)]))
        let result = try evaluator.eval(.symbol("z"))
        #expect(result == .integer(2))
    }

    @Test("Undefined symbol throws undefinedSymbol")
    func undefinedSymbolThrows() throws {
        #expect(throws: EvaluatorError.undefinedSymbol("unknown")) {
            try evaluator.eval(.symbol("unknown"))
        }
    }

    @Test("def evaluates its value argument")
    func defEvaluatesValueArgument() throws {
        let result = try evaluator.eval(.list([.symbol("def"), .symbol("x"),
            .list([.symbol("def"), .symbol("y"), .integer(5)])]))
        #expect(result == .symbol("x"))
        let xValue = try evaluator.eval(.symbol("x"))
        #expect(xValue == .symbol("y"))
        let yValue = try evaluator.eval(.symbol("y"))
        #expect(yValue == .integer(5))
    }

    @Test("def with apostrophe in symbol name")
    func defWithApostropheSymbol() throws {
        let exprs = try Reader.readString("(def a'b 5)")
        #expect(exprs.count == 1)
        let result = try evaluator.eval(exprs[0])
        #expect(result == .symbol("a'b"))
        let value = try evaluator.eval(.symbol("a'b"))
        #expect(value == .integer(5))
    }

    // MARK: - if special form

    @Test("if with no arguments throws")
    func ifNoArgumentsThrows() throws {
        #expect(throws: EvaluatorError.invalidArgument(function: "if",
            message: "requires a condition and a then-branch")) {
            try evaluator.eval(.list([.symbol("if")]))
        }
    }

    @Test("if with only condition throws")
    func ifOnlyConditionThrows() throws {
        #expect(throws: EvaluatorError.invalidArgument(function: "if",
            message: "requires a condition and a then-branch")) {
            try evaluator.eval(.list([.symbol("if"), .boolean(true)]))
        }
    }

    @Test("if with truthy condition evaluates then-branch")
    func ifTruthyEvalsThenBranch() throws {
        let result = try evaluator.eval(.list([.symbol("if"), .boolean(true), .integer(1), .integer(2)]))
        #expect(result == .integer(1))
    }

    @Test("if with false evaluates else-branch")
    func ifFalseEvalsElseBranch() throws {
        let result = try evaluator.eval(.list([.symbol("if"), .boolean(false), .integer(1), .integer(2)]))
        #expect(result == .integer(2))
    }

    @Test("if with nil evaluates else-branch")
    func ifNilEvalsElseBranch() throws {
        let result = try evaluator.eval(.list([.symbol("if"), .nil, .integer(1), .integer(2)]))
        #expect(result == .integer(2))
    }

    @Test("if with 0 evaluates then-branch (0 is truthy)")
    func ifZeroEvalsThenBranch() throws {
        let result = try evaluator.eval(.list([.symbol("if"), .integer(0), .integer(1), .integer(2)]))
        #expect(result == .integer(1))
    }

    @Test("if with falsy condition and no else-branch returns nil")
    func ifFalsyNoElseReturnsNil() throws {
        let result = try evaluator.eval(.list([.symbol("if"), .boolean(false), .integer(1)]))
        #expect(result == .nil)
    }

    @Test("if with truthy condition and no else-branch evaluates then-branch")
    func ifTruthyNoElseEvalsThenBranch() throws {
        let result = try evaluator.eval(.list([.symbol("if"), .boolean(true), .integer(42)]))
        #expect(result == .integer(42))
    }

    // MARK: - let special form

    @Test("let with no body returns nil")
    func letNoBodyReturnsNil() throws {
        let result = try evaluator.eval(.list([.symbol("let"), .vector([])]))
        #expect(result == .nil)
    }

    @Test("let with empty bindings evaluates body")
    func letEmptyBindingsEvaluatesBody() throws {
        let result = try evaluator.eval(.list([.symbol("let"), .vector([]), .integer(42)]))
        #expect(result == .integer(42))
    }

    @Test("let binds a symbol and returns it from body")
    func letBindsSymbol() throws {
        let result = try evaluator.eval(.list([
            .symbol("let"),
            .vector([.symbol("x"), .integer(1)]),
            .symbol("x")
        ]))
        #expect(result == .integer(1))
    }

    @Test("let with multiple bindings evaluates body with all bindings")
    func letMultipleBindings() throws {
        let result = try evaluator.eval(.list([
            .symbol("let"),
            .vector([.symbol("x"), .integer(1), .symbol("y"), .integer(2)]),
            .list([.symbol("+"), .symbol("x"), .symbol("y")])
        ]))
        #expect(result == .integer(3))
    }

    @Test("let returns last body expression")
    func letReturnsLastBodyExpr() throws {
        let result = try evaluator.eval(.list([
            .symbol("let"),
            .vector([.symbol("x"), .integer(1)]),
            .integer(99),
            .symbol("x")
        ]))
        #expect(result == .integer(1))
    }

    @Test("let bindings are sequential (later can reference earlier)")
    func letSequentialBindings() throws {
        let result = try evaluator.eval(.list([
            .symbol("let"),
            .vector([
                .symbol("x"), .integer(1),
                .symbol("y"), .list([.symbol("+"), .symbol("x"), .integer(1)])
            ]),
            .symbol("y")
        ]))
        #expect(result == .integer(2))
    }

    @Test("let is lexically scoped (binding not visible outside)")
    func letBindingNotVisibleOutside() throws {
        _ = try evaluator.eval(.list([
            .symbol("let"), .vector([.symbol("local"), .integer(7)]), .symbol("local")
        ]))
        #expect(throws: EvaluatorError.undefinedSymbol("local")) {
            try evaluator.eval(.symbol("local"))
        }
    }

    @Test("nested let can reference outer binding")
    func nestedLetReferencesOuter() throws {
        let result = try evaluator.eval(.list([
            .symbol("let"),
            .vector([.symbol("x"), .integer(10)]),
            .list([
                .symbol("let"),
                .vector([.symbol("y"), .integer(20)]),
                .list([.symbol("+"), .symbol("x"), .symbol("y")])
            ])
        ]))
        #expect(result == .integer(30))
    }

    @Test("let can shadow outer binding")
    func letShadowsOuterBinding() throws {
        _ = try evaluator.eval(.list([.symbol("def"), .symbol("x"), .integer(1)]))
        let result = try evaluator.eval(.list([
            .symbol("let"),
            .vector([.symbol("x"), .integer(99)]),
            .symbol("x")
        ]))
        #expect(result == .integer(99))
        // outer x is unchanged
        #expect(try evaluator.eval(.symbol("x")) == .integer(1))
    }

    // MARK: - Native functions

    @Test("Native function self-evaluates")
    func nativeFunctionSelfEvaluates() throws {
        let fn = Expr.nativeFunction(name: "inc", arity: .fixed(1)) { args in .integer(0) }
        let result = try evaluator.eval(fn)
        #expect(result == fn)
    }

    @Test("register places native function in core environment")
    func registerPlacesNativeFunctionInCoreEnvironment() {
        let evaluator = Evaluator()
        evaluator.register(name: "inc", arity: .fixed(1)) { args in args[0] }
        let stored = evaluator.coreEnvironment.get("inc")
        #expect(stored == .nativeFunction(name: "inc", arity: .fixed(1)) { _ in .nil })
    }

    @Test("Calling a fixed-arity native function returns its result")
    func callingFixedArityNativeFunction() throws {
        let evaluator = Evaluator()
        evaluator.register(name: "inc", arity: .fixed(1)) { args in
            guard case .integer(let n) = args[0] else { return .nil }
            return .integer(n + 1)
        }
        let result = try evaluator.eval(.list([.symbol("inc"), .integer(4)]))
        #expect(result == .integer(5))
    }

    @Test("Calling a native function with wrong arity throws arityMismatch")
    func callingNativeFunctionWithWrongArityThrows() throws {
        let evaluator = Evaluator()
        evaluator.register(name: "inc", arity: .fixed(1)) { args in args[0] }
        #expect(throws: EvaluatorError.arityMismatch(name: "inc", expected: .fixed(1), got: 2)) {
            try evaluator.eval(.list([.symbol("inc"), .integer(1), .integer(2)]))
        }
    }

    @Test("Calling a variadic native function works with any number of args")
    func callingVariadicNativeFunction() throws {
        let evaluator = Evaluator()
        evaluator.register(name: "count", arity: .variadic) { args in .integer(args.count) }
        #expect(try evaluator.eval(.list([.symbol("count")])) == .integer(0))
        #expect(try evaluator.eval(.list([.symbol("count"), .integer(1), .integer(2)])) == .integer(2))
    }
}

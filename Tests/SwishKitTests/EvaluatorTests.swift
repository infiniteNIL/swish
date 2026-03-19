import Testing
@testable import SwishKit

@Suite("Evaluator Tests")
struct EvaluatorTests {
    let evaluator = Evaluator()

    @Test("Integer evaluates to itself")
    func integerSelfEvaluates() throws {
        let result = try evaluator.eval(.integer(42))
        #expect(result == .integer(42))
    }

    @Test("Negative integer evaluates to itself")
    func negativeIntegerSelfEvaluates() throws {
        let result = try evaluator.eval(.integer(-17))
        #expect(result == .integer(-17))
    }

    @Test("Zero evaluates to itself")
    func zeroSelfEvaluates() throws {
        let result = try evaluator.eval(.integer(0))
        #expect(result == .integer(0))
    }

    // MARK: - Floating point literals

    @Test("Float evaluates to itself")
    func floatSelfEvaluates() throws {
        let result = try evaluator.eval(.float(3.14))
        #expect(result == .float(3.14))
    }

    @Test("Negative float evaluates to itself")
    func negativeFloatSelfEvaluates() throws {
        let result = try evaluator.eval(.float(-2.5))
        #expect(result == .float(-2.5))
    }

    @Test("Float zero evaluates to itself")
    func floatZeroSelfEvaluates() throws {
        let result = try evaluator.eval(.float(0.0))
        #expect(result == .float(0.0))
    }

    // MARK: - Ratio literals

    @Test("Ratio evaluates to itself")
    func ratioSelfEvaluates() throws {
        let result = try evaluator.eval(.ratio(Ratio(3, 4)))
        #expect(result == .ratio(Ratio(3, 4)))
    }

    @Test("Negative ratio evaluates to itself")
    func negativeRatioSelfEvaluates() throws {
        let result = try evaluator.eval(.ratio(Ratio(-3, 4)))
        #expect(result == .ratio(Ratio(-3, 4)))
    }

    // MARK: - String literals

    @Test("String evaluates to itself")
    func stringSelfEvaluates() throws {
        let result = try evaluator.eval(.string("hello"))
        #expect(result == .string("hello"))
    }

    @Test("Empty string evaluates to itself")
    func emptyStringSelfEvaluates() throws {
        let result = try evaluator.eval(.string(""))
        #expect(result == .string(""))
    }

    @Test("String with escapes evaluates to itself")
    func stringWithEscapesSelfEvaluates() throws {
        let result = try evaluator.eval(.string("hello\nworld"))
        #expect(result == .string("hello\nworld"))
    }

    // MARK: - Keyword literals

    @Test("Keyword evaluates to itself")
    func keywordSelfEvaluates() throws {
        let result = try evaluator.eval(.keyword("foo"))
        #expect(result == .keyword("foo"))
    }

    @Test("Hyphenated keyword evaluates to itself")
    func hyphenatedKeywordSelfEvaluates() throws {
        let result = try evaluator.eval(.keyword("foo-bar"))
        #expect(result == .keyword("foo-bar"))
    }

    @Test("Namespaced keyword evaluates to itself")
    func namespacedKeywordSelfEvaluates() throws {
        let result = try evaluator.eval(.keyword("user/name"))
        #expect(result == .keyword("user/name"))
    }

    @Test(":true keyword evaluates to itself")
    func trueKeywordSelfEvaluates() throws {
        let result = try evaluator.eval(.keyword("true"))
        #expect(result == .keyword("true"))
    }

    // MARK: - List literals

    @Test("Empty list evaluates to itself")
    func emptyListSelfEvaluates() throws {
        let result = try evaluator.eval(.list([]))
        #expect(result == .list([]))
    }

    @Test("List with integer head throws notAFunction")
    func listWithIntegerHeadThrows() throws {
        #expect(throws: EvaluatorError.notAFunction(.integer(1))) {
            try evaluator.eval(.list([.integer(1), .integer(2), .integer(3)]))
        }
    }

    @Test("Nested list with integer head throws notAFunction")
    func nestedListWithIntegerHeadThrows() throws {
        #expect(throws: EvaluatorError.notAFunction(.integer(1))) {
            try evaluator.eval(.list([.integer(1), .list([.integer(2), .integer(3)]), .integer(4)]))
        }
    }

    @Test("Symbol bound to non-function throws notAFunction")
    func symbolBoundToNonFunctionThrows() throws {
        _ = try evaluator.eval(.list([.symbol("def"), .symbol("a"), .integer(5)]))
        #expect(throws: EvaluatorError.notAFunction(.integer(5))) {
            try evaluator.eval(.list([.symbol("a")]))
        }
    }

    @Test("nil as list head throws notAFunction")
    func nilAsListHeadThrows() throws {
        #expect(throws: EvaluatorError.notAFunction(.nil)) {
            try evaluator.eval(.list([.nil]))
        }
    }

    @Test("Keyword as list head throws notAFunction")
    func keywordAsListHeadThrows() throws {
        #expect(throws: EvaluatorError.notAFunction(.keyword("foo"))) {
            try evaluator.eval(.list([.keyword("foo")]))
        }
    }

    @Test("List with undefined symbol throws undefinedSymbol")
    func listWithUndefinedSymbolThrows() throws {
        #expect(throws: EvaluatorError.undefinedSymbol("nope")) {
            try evaluator.eval(.list([.symbol("nope")]))
        }
    }

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

    // MARK: - Environment parent lookup

    @Test("Child environment looks up symbol in parent")
    func childEnvironmentLooksUpInParent() {
        let parent = Environment()
        parent.set("x", .integer(99))
        let child = Environment(parent: parent)
        #expect(child.get("x") == .integer(99))
    }

    @Test("Child environment binding shadows parent binding")
    func childEnvironmentShadowsParent() {
        let parent = Environment()
        parent.set("x", .integer(1))
        let child = Environment(parent: parent)
        child.set("x", .integer(2))
        #expect(child.get("x") == .integer(2))
        #expect(parent.get("x") == .integer(1))
    }

    // MARK: - Core environment

    @Test("Core environment symbol is visible during eval")
    func coreEnvironmentSymbolVisibleDuringEval() throws {
        let evaluator = Evaluator()
        evaluator.coreEnvironment.set("pi", .float(3.14159))
        let result = try evaluator.eval(.symbol("pi"))
        #expect(result == .float(3.14159))
    }

    @Test("def does not affect core environment")
    func defDoesNotAffectCoreEnvironment() throws {
        let evaluator = Evaluator()
        _ = try evaluator.eval(.list([.symbol("def"), .symbol("myVar"), .integer(7)]))
        #expect(evaluator.coreEnvironment.get("myVar") == nil)
        #expect(evaluator.environment.get("myVar") == .integer(7))
    }

    // MARK: - vector literals

    @Test("Empty vector evaluates to empty vector")
    func emptyVectorEvaluates() throws {
        let result = try evaluator.eval(.vector([]))
        #expect(result == .vector([]))
    }

    @Test("Vector with literals evaluates elements")
    func vectorWithLiteralsEvaluates() throws {
        let result = try evaluator.eval(.vector([.integer(1), .boolean(true), .nil]))
        #expect(result == .vector([.integer(1), .boolean(true), .nil]))
    }

    @Test("Vector elements are evaluated")
    func vectorElementsAreEvaluated() throws {
        // (+ 1 1) inside a vector should evaluate to 2
        let result = try evaluator.eval(.vector([
            .integer(1),
            .list([.symbol("+"), .integer(1), .integer(1)]),
            .integer(3)
        ]))
        #expect(result == .vector([.integer(1), .integer(2), .integer(3)]))
    }

    @Test("Nested vector evaluates inner elements")
    func nestedVectorEvaluates() throws {
        let result = try evaluator.eval(.vector([
            .integer(1),
            .vector([.integer(2), .integer(3)])
        ]))
        #expect(result == .vector([.integer(1), .vector([.integer(2), .integer(3)])]))
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

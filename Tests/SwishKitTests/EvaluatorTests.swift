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

    // MARK: - fn special form

    @Test("fn evaluates to a function value")
    func fnEvaluatesToFunction() throws {
        let result = try evaluator.eval(.list([.symbol("fn"), .vector([.symbol("x")]), .symbol("x")]))
        #expect(result == .function(name: nil, params: ["x"], body: [.symbol("x")]))
    }

    @Test("fn with no params evaluates to a zero-param function")
    func fnNoParamsEvaluatesToFunction() throws {
        let result = try evaluator.eval(.list([.symbol("fn"), .vector([]), .integer(42)]))
        #expect(result == .function(name: nil, params: [], body: [.integer(42)]))
    }

    @Test("Named fn evaluates to a function with name")
    func namedFnEvaluatesToNamedFunction() throws {
        let result = try evaluator.eval(.list([
            .symbol("fn"), .symbol("square"),
            .vector([.symbol("x")]),
            .list([.symbol("*"), .symbol("x"), .symbol("x")])
        ]))
        #expect(result == .function(
            name: "square",
            params: ["x"],
            body: [.list([.symbol("*"), .symbol("x"), .symbol("x")])]
        ))
    }

    @Test("Immediately invoked fn returns body result")
    func immediatelyInvokedFn() throws {
        // ((fn [x] x) 5) => 5
        let result = try evaluator.eval(.list([
            .list([.symbol("fn"), .vector([.symbol("x")]), .symbol("x")]),
            .integer(5)
        ]))
        #expect(result == .integer(5))
    }

    @Test("fn with multiple params binds all arguments")
    func fnMultipleParams() throws {
        // ((fn [x y] (+ x y)) 2 3) => 5
        let result = try evaluator.eval(.list([
            .list([
                .symbol("fn"),
                .vector([.symbol("x"), .symbol("y")]),
                .list([.symbol("+"), .symbol("x"), .symbol("y")])
            ]),
            .integer(2),
            .integer(3)
        ]))
        #expect(result == .integer(5))
    }

    @Test("fn with no params called with no args returns body result")
    func fnNoParamsCall() throws {
        // ((fn [] 42)) => 42
        let result = try evaluator.eval(.list([
            .list([.symbol("fn"), .vector([]), .integer(42)])
        ]))
        #expect(result == .integer(42))
    }

    @Test("fn with multi-expression body returns last expression")
    func fnMultiExprBody() throws {
        // ((fn [x] 1 2 x) 7) => 7
        let result = try evaluator.eval(.list([
            .list([
                .symbol("fn"),
                .vector([.symbol("x")]),
                .integer(1),
                .integer(2),
                .symbol("x")
            ]),
            .integer(7)
        ]))
        #expect(result == .integer(7))
    }

    @Test("fn with empty body returns nil")
    func fnEmptyBody() throws {
        // ((fn [])) => nil
        let result = try evaluator.eval(.list([
            .list([.symbol("fn"), .vector([])])
        ]))
        #expect(result == .nil)
    }

    @Test("def can bind a fn and it can be called by name")
    func defFnAndCall() throws {
        // (def double (fn [x] (+ x x)))
        // (double 4) => 8
        _ = try evaluator.eval(.list([
            .symbol("def"), .symbol("double"),
            .list([
                .symbol("fn"),
                .vector([.symbol("x")]),
                .list([.symbol("+"), .symbol("x"), .symbol("x")])
            ])
        ]))
        let result = try evaluator.eval(.list([.symbol("double"), .integer(4)]))
        #expect(result == .integer(8))
    }

    @Test("fn closes over let bindings in enclosing scope")
    func fnClosesOverLetBindings() throws {
        // (let [x 10] ((fn [y] (+ x y)) 5)) => 15
        let result = try evaluator.eval(.list([
            .symbol("let"),
            .vector([.symbol("x"), .integer(10)]),
            .list([
                .list([
                    .symbol("fn"),
                    .vector([.symbol("y")]),
                    .list([.symbol("+"), .symbol("x"), .symbol("y")])
                ]),
                .integer(5)
            ])
        ]))
        #expect(result == .integer(15))
    }

    @Test("Calling fn with too few arguments throws arityMismatch")
    func fnTooFewArgsThrows() throws {
        #expect(throws: EvaluatorError.arityMismatch(name: "fn", expected: .fixed(2), got: 1)) {
            try evaluator.eval(.list([
                .list([
                    .symbol("fn"),
                    .vector([.symbol("x"), .symbol("y")]),
                    .symbol("x")
                ]),
                .integer(1)
            ]))
        }
    }

    @Test("Calling fn with too many arguments throws arityMismatch")
    func fnTooManyArgsThrows() throws {
        #expect(throws: EvaluatorError.arityMismatch(name: "fn", expected: .fixed(1), got: 2)) {
            try evaluator.eval(.list([
                .list([
                    .symbol("fn"),
                    .vector([.symbol("x")]),
                    .symbol("x")
                ]),
                .integer(1),
                .integer(2)
            ]))
        }
    }

    @Test("Named fn uses its name in arity mismatch error")
    func namedFnArityMismatchUsesName() throws {
        #expect(throws: EvaluatorError.arityMismatch(name: "inc", expected: .fixed(1), got: 0)) {
            try evaluator.eval(.list([
                .list([
                    .symbol("fn"),
                    .symbol("inc"),
                    .vector([.symbol("x")]),
                    .symbol("x")
                ])
            ]))
        }
    }

    @Test("fn throws undefinedSymbol when body references unknown symbol")
    func fnUndefinedSymbolInBodyThrows() throws {
        #expect(throws: EvaluatorError.undefinedSymbol("x")) {
            try evaluator.eval(.list([.symbol("fn"), .vector([]), .symbol("x")]))
        }
    }

    @Test("fn does not throw for symbols that are parameters")
    func fnParamSymbolsAreValid() throws {
        // (fn [x] x) — x is a param, should not throw
        #expect(throws: Never.self) {
            try evaluator.eval(.list([.symbol("fn"), .vector([.symbol("x")]), .symbol("x")]))
        }
    }

    @Test("fn does not throw for symbols defined in the enclosing environment")
    func fnClosedOverSymbolIsValid() throws {
        // (let [x 1] (fn [] x)) — x is in scope, should not throw
        #expect(throws: Never.self) {
            try evaluator.eval(.list([
                .symbol("let"),
                .vector([.symbol("x"), .integer(1)]),
                .list([.symbol("fn"), .vector([]), .symbol("x")])
            ]))
        }
    }

    @Test("fn throws undefinedSymbol for unknown symbol nested in body expression")
    func fnNestedUndefinedSymbolThrows() throws {
        // (fn [x] (+ x y)) — y is not defined
        #expect(throws: EvaluatorError.undefinedSymbol("y")) {
            try evaluator.eval(.list([
                .symbol("fn"),
                .vector([.symbol("x")]),
                .list([.symbol("+"), .symbol("x"), .symbol("y")])
            ]))
        }
    }

    @Test("fn with nested fn checks inner body with inner params")
    func fnNestedFnUsesInnerParams() throws {
        // (fn [x] (fn [y] (+ x y))) — both x and y are in scope for inner body
        #expect(throws: Never.self) {
            try evaluator.eval(.list([
                .symbol("fn"),
                .vector([.symbol("x")]),
                .list([
                    .symbol("fn"),
                    .vector([.symbol("y")]),
                    .list([.symbol("+"), .symbol("x"), .symbol("y")])
                ])
            ]))
        }
    }

    @Test("fn with let in body sees let-bound symbols")
    func fnLetBindingInBody() throws {
        // (fn [] (let [x 1] x)) — x is bound by let, should not throw
        #expect(throws: Never.self) {
            try evaluator.eval(.list([
                .symbol("fn"),
                .vector([]),
                .list([
                    .symbol("let"),
                    .vector([.symbol("x"), .integer(1)]),
                    .symbol("x")
                ])
            ]))
        }
    }

    // MARK: - syntax-quote / unquote / unquote-splicing

    @Test("syntax-quote returns atom as-is")
    func syntaxQuoteAtomReturnsItself() throws {
        let result = try evaluator.eval(.list([.symbol("syntax-quote"), .symbol("a")]))
        #expect(result == .symbol("a"))
    }

    @Test("syntax-quote returns integer as-is")
    func syntaxQuoteIntegerReturnsItself() throws {
        let result = try evaluator.eval(.list([.symbol("syntax-quote"), .integer(42)]))
        #expect(result == .integer(42))
    }

    @Test("syntax-quote returns plain list unevaluated")
    func syntaxQuotePlainListUnevaluated() throws {
        let result = try evaluator.eval(.list([
            .symbol("syntax-quote"),
            .list([.integer(1), .integer(2), .integer(3)])
        ]))
        #expect(result == .list([.integer(1), .integer(2), .integer(3)]))
    }

    @Test("syntax-quote with top-level unquote evaluates the inner expr")
    func syntaxQuoteTopLevelUnquoteEvaluates() throws {
        // bind x = 5
        _ = try evaluator.eval(.list([.symbol("def"), .symbol("x"), .integer(5)]))
        // (syntax-quote (unquote x)) => 5
        let result = try evaluator.eval(.list([
            .symbol("syntax-quote"),
            .list([.symbol("unquote"), .symbol("x")])
        ]))
        #expect(result == .integer(5))
    }

    @Test("syntax-quote substitutes unquote in a list element")
    func syntaxQuoteUnquoteSubstitution() throws {
        _ = try evaluator.eval(.list([.symbol("def"), .symbol("x"), .integer(2)]))
        // (syntax-quote (1 (unquote x) 3)) => (1 2 3)
        let result = try evaluator.eval(.list([
            .symbol("syntax-quote"),
            .list([
                .integer(1),
                .list([.symbol("unquote"), .symbol("x")]),
                .integer(3)
            ])
        ]))
        #expect(result == .list([.integer(1), .integer(2), .integer(3)]))
    }

    @Test("syntax-quote unquote substitution is recursive")
    func syntaxQuoteUnquoteRecursive() throws {
        _ = try evaluator.eval(.list([.symbol("def"), .symbol("x"), .integer(5)]))
        // (syntax-quote (1 (2 (unquote x)) 3)) => (1 (2 5) 3)
        let result = try evaluator.eval(.list([
            .symbol("syntax-quote"),
            .list([
                .integer(1),
                .list([.integer(2), .list([.symbol("unquote"), .symbol("x")])]),
                .integer(3)
            ])
        ]))
        #expect(result == .list([
            .integer(1),
            .list([.integer(2), .integer(5)]),
            .integer(3)
        ]))
    }

    @Test("syntax-quote splices unquote-splicing into the surrounding list")
    func syntaxQuoteUnquoteSplicing() throws {
        _ = try evaluator.eval(.list([
            .symbol("def"), .symbol("xs"),
            .list([.symbol("quote"), .list([.integer(4), .integer(5)])])
        ]))
        // (syntax-quote (1 (unquote-splicing xs) 3)) => (1 4 5 3)
        let result = try evaluator.eval(.list([
            .symbol("syntax-quote"),
            .list([
                .integer(1),
                .list([.symbol("unquote-splicing"), .symbol("xs")]),
                .integer(3)
            ])
        ]))
        #expect(result == .list([.integer(1), .integer(4), .integer(5), .integer(3)]))
    }

    @Test("syntax-quote handles mixed unquote and unquote-splicing")
    func syntaxQuoteMixedUnquoteAndSplicing() throws {
        _ = try evaluator.eval(.list([.symbol("def"), .symbol("x"), .integer(2)]))
        _ = try evaluator.eval(.list([
            .symbol("def"), .symbol("xs"),
            .list([.symbol("quote"), .list([.integer(4), .integer(5)])])
        ]))
        // (syntax-quote ((unquote x) (unquote-splicing xs) (unquote x))) => (2 4 5 2)
        let result = try evaluator.eval(.list([
            .symbol("syntax-quote"),
            .list([
                .list([.symbol("unquote"), .symbol("x")]),
                .list([.symbol("unquote-splicing"), .symbol("xs")]),
                .list([.symbol("unquote"), .symbol("x")])
            ])
        ]))
        #expect(result == .list([.integer(2), .integer(4), .integer(5), .integer(2)]))
    }

    @Test("unquote of undefined symbol throws undefinedSymbol")
    func unquoteUndefinedSymbolThrows() throws {
        #expect(throws: EvaluatorError.undefinedSymbol("y")) {
            try evaluator.eval(.list([
                .symbol("syntax-quote"),
                .list([.symbol("unquote"), .symbol("y")])
            ]))
        }
    }

    @Test("unquote-splicing a non-list throws invalidArgument")
    func unquoteSplicingNonListThrows() throws {
        _ = try evaluator.eval(.list([.symbol("def"), .symbol("v"), .integer(99)]))
        #expect(throws: EvaluatorError.invalidArgument(
            function: "unquote-splicing", message: "value must be a list"
        )) {
            try evaluator.eval(.list([
                .symbol("syntax-quote"),
                .list([
                    .integer(1),
                    .list([.symbol("unquote-splicing"), .symbol("v")]),
                    .integer(3)
                ])
            ]))
        }
    }

    @Test("fn body with syntax-quote and unquote checks param symbols")
    func fnBodySyntaxQuoteUnquoteChecksParams() throws {
        // (fn [x] (syntax-quote (1 (unquote x) 3))) — x is a param, should succeed
        #expect(throws: Never.self) {
            try evaluator.eval(.list([
                .symbol("fn"),
                .vector([.symbol("x")]),
                .list([
                    .symbol("syntax-quote"),
                    .list([
                        .integer(1),
                        .list([.symbol("unquote"), .symbol("x")]),
                        .integer(3)
                    ])
                ])
            ]))
        }
    }

    @Test("fn body with syntax-quote and unquote rejects undefined symbols")
    func fnBodySyntaxQuoteUnquoteRejectsUndefined() throws {
        // (fn [] (syntax-quote (1 (unquote y) 3))) — y is not defined
        #expect(throws: EvaluatorError.undefinedSymbol("y")) {
            try evaluator.eval(.list([
                .symbol("fn"),
                .vector([]),
                .list([
                    .symbol("syntax-quote"),
                    .list([
                        .integer(1),
                        .list([.symbol("unquote"), .symbol("y")]),
                        .integer(3)
                    ])
                ])
            ]))
        }
    }

    @Test("fn body with syntax-quote and unquote-splicing checks param symbols")
    func fnBodySyntaxQuoteUnquoteSplicingChecksParams() throws {
        // (fn [xs] (syntax-quote (1 (unquote-splicing xs) 3))) — xs is a param
        #expect(throws: Never.self) {
            try evaluator.eval(.list([
                .symbol("fn"),
                .vector([.symbol("xs")]),
                .list([
                    .symbol("syntax-quote"),
                    .list([
                        .integer(1),
                        .list([.symbol("unquote-splicing"), .symbol("xs")]),
                        .integer(3)
                    ])
                ])
            ]))
        }
    }

    @Test("fn body with syntax-quote and unquote-splicing rejects undefined symbols")
    func fnBodySyntaxQuoteUnquoteSplicingRejectsUndefined() throws {
        // (fn [] (syntax-quote (1 (unquote-splicing zs) 3))) — zs is not defined
        #expect(throws: EvaluatorError.undefinedSymbol("zs")) {
            try evaluator.eval(.list([
                .symbol("fn"),
                .vector([]),
                .list([
                    .symbol("syntax-quote"),
                    .list([
                        .integer(1),
                        .list([.symbol("unquote-splicing"), .symbol("zs")]),
                        .integer(3)
                    ])
                ])
            ]))
        }
    }

    @Test("fn body with plain syntax-quote does not check symbols inside it")
    func fnBodyPlainSyntaxQuoteDoesNotCheckSymbols() throws {
        // (fn [] (syntax-quote (1 undefined-sym 3))) — undefined-sym is not evaluated
        #expect(throws: Never.self) {
            try evaluator.eval(.list([
                .symbol("fn"),
                .vector([]),
                .list([
                    .symbol("syntax-quote"),
                    .list([.integer(1), .symbol("undefined-sym"), .integer(3)])
                ])
            ]))
        }
    }

    // MARK: - Variadic parameters (& rest)

    @Test("fn with & rest collects extra args into a list")
    func fnVariadicRestCollectsExtraArgs() throws {
        // (def f (fn [x & rest] rest))
        // (f 1 2 3) => (2 3)
        let swish = Swish()
        let result = try swish.eval("(def f (fn [x & rest] rest)) (f 1 2 3)")
        #expect(result == .list([.integer(2), .integer(3)]))
    }

    @Test("fn with & rest and no extra args binds empty list")
    func fnVariadicRestBindsEmptyList() throws {
        // (def f (fn [x & rest] rest))
        // (f 1) => ()
        let swish = Swish()
        let result = try swish.eval("(def f (fn [x & rest] rest)) (f 1)")
        #expect(result == .list([]))
    }

    @Test("fn with only & rest param collects all args")
    func fnOnlyRestParamCollectsAll() throws {
        // (def f (fn [& args] args))
        // (f 1 2 3) => (1 2 3)
        let swish = Swish()
        let result = try swish.eval("(def f (fn [& args] args)) (f 1 2 3)")
        #expect(result == .list([.integer(1), .integer(2), .integer(3)]))
    }

    @Test("fn with only & rest param called with no args binds empty list")
    func fnOnlyRestParamNoArgs() throws {
        // (def f (fn [& args] args))
        // (f) => ()
        let swish = Swish()
        let result = try swish.eval("(def f (fn [& args] args)) (f)")
        #expect(result == .list([]))
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

    // MARK: - Macros

    @Test("defmacro defines a macro and returns its name")
    func defmacroReturnsName() throws {
        // (defmacro my-macro [x] x) => my-macro
        let swish = Swish()
        let result = try swish.eval("(defmacro my-macro [x] x)")
        #expect(result == .symbol("my-macro"))
    }

    @Test("macro value self-evaluates")
    func macroSelfEvaluates() throws {
        let m = Expr.macro(name: "test", params: ["x"], body: [.symbol("x")])
        let result = try evaluator.eval(m)
        #expect(result == m)
    }

    @Test("Simple macro expands and evaluates")
    func simpleMacroExpansion() throws {
        // (defmacro unless [cond then] `(if ~cond nil ~then))
        // (unless false 42) => 42
        let swish = Swish()
        let result = try swish.eval("""
            (defmacro unless [cond then] `(if ~cond nil ~then))
            (unless false 42)
            """)
        #expect(result == .integer(42))
    }

    @Test("Macro receives unevaluated arguments")
    func macroReceivesUnevaluatedArgs() throws {
        // (defmacro get-code [x] `(quote ~x))
        // (get-code (+ 1 2)) => (+ 1 2)   not 3
        let swish = Swish()
        let result = try swish.eval("""
            (defmacro get-code [x] `(quote ~x))
            (get-code (+ 1 2))
            """)
        #expect(result == .list([.symbol("+"), .integer(1), .integer(2)]))
    }

    @Test("Macro with multiple body forms returns last expansion")
    func macroMultipleBodyForms() throws {
        // The last body form becomes the expansion
        // (defmacro double-if [c a b] (quote nil) `(if ~c ~a ~b))
        // (double-if true 10 20) => 10
        let swish = Swish()
        let result = try swish.eval("""
            (defmacro double-if [c a b]
              (quote nil)
              `(if ~c ~a ~b))
            (double-if true 10 20)
            """)
        #expect(result == .integer(10))
    }

    @Test("Macro expansion result is evaluated in caller's environment")
    func macroEvalsInCallerEnv() throws {
        // (def y 10)
        // (defmacro use-y [] 'y)
        // (use-y) => 10
        let swish = Swish()
        let result = try swish.eval("""
            (def y 10)
            (defmacro use-y [] 'y)
            (use-y)
            """)
        #expect(result == .integer(10))
    }

    @Test("Macro arity mismatch throws arityMismatch error")
    func macroArityMismatch() throws {
        // (defmacro m [x] x) then (m 1 2) should throw
        let swish = Swish()
        _ = try swish.eval("(defmacro m [x] x)")
        #expect(throws: EvaluatorError.arityMismatch(name: "m", expected: .fixed(1), got: 2)) {
            try swish.eval("(m 1 2)")
        }
    }

    @Test("Variadic macro with & rest")
    func variadicMacro() throws {
        // (defmacro my-list [& items] `(quote ~items))
        // (my-list 1 2 3) => (1 2 3)
        let swish = Swish()
        let result = try swish.eval("""
            (defmacro my-list [& items] `(quote ~items))
            (my-list 1 2 3)
            """)
        #expect(result == .list([.integer(1), .integer(2), .integer(3)]))
    }

    @Test("gensym produces unique symbols")
    func gensymUnique() throws {
        // Two calls to gensym produce different symbols
        let swish = Swish()
        let a = try swish.eval("(gensym)")
        let b = try swish.eval("(gensym)")
        #expect(a != b)
        if case .symbol = a { } else { Issue.record("expected symbol, got \(a)") }
    }

    @Test("gensym accepts a custom prefix")
    func gensymCustomPrefix() throws {
        // (gensym "tmp__") => a symbol starting with "tmp__"
        let swish = Swish()
        let result = try swish.eval(#"(gensym "tmp__")"#)
        guard case .symbol(let name) = result else {
            Issue.record("expected symbol, got \(result)")
            return
        }
        #expect(name.hasPrefix("tmp__"))
    }

    @Test("Auto-gensym replaces foo# with unique symbol in syntax-quote")
    func autoGensymInSyntaxQuote() throws {
        // `x# should produce a unique symbol (not the literal x#)
        let swish = Swish()
        let result = try swish.eval("`x#")
        guard case .symbol(let name) = result else {
            Issue.record("expected symbol, got \(result)")
            return
        }
        #expect(name != "x#")
        #expect(name.hasPrefix("x__"))
    }

    @Test("Auto-gensym produces the same symbol for repeated foo# in one template")
    func autoGensymConsistentInTemplate() throws {
        // `(x# x#) should produce (G1 G1) — both x# become the same symbol
        let swish = Swish()
        let result = try swish.eval("`(x# x#)")
        guard case .list(let elems) = result, elems.count == 2 else {
            Issue.record("expected 2-element list, got \(result)")
            return
        }
        #expect(elems[0] == elems[1])
    }

    @Test("Auto-gensym produces different symbols across separate syntax-quote expansions")
    func autoGensymFreshAcrossExpansions() throws {
        // Two separate backtick evaluations get different gensyms for x#
        let swish = Swish()
        let first = try swish.eval("`x#")
        let second = try swish.eval("`x#")
        #expect(first != second)
    }

    @Test("Auto-gensym works inside vectors in syntax-quote")
    func autoGensymInVector() throws {
        // `[x# x#] => [G1 G1]
        let swish = Swish()
        let result = try swish.eval("`[x# x#]")
        guard case .vector(let elems) = result, elems.count == 2 else {
            Issue.record("expected 2-element vector, got \(result)")
            return
        }
        #expect(elems[0] == elems[1])
    }

    @Test("macroexpand-1 expands one step")
    func macroexpand1OneStep() throws {
        // (defmacro unless [cond then] `(if ~cond nil ~then))
        // (macroexpand-1 '(unless false 42)) => (if false nil 42)
        let swish = Swish()
        let result = try swish.eval("""
            (defmacro unless [cond then] `(if ~cond nil ~then))
            (macroexpand-1 '(unless false 42))
            """)
        #expect(result == .list([.symbol("if"), .boolean(false), .nil, .integer(42)]))
    }

    @Test("macroexpand-1 returns non-macro form unchanged")
    func macroexpand1NonMacro() throws {
        // (macroexpand-1 '(+ 1 2)) => (+ 1 2)
        let swish = Swish()
        let result = try swish.eval("(macroexpand-1 '(+ 1 2))")
        #expect(result == .list([.symbol("+"), .integer(1), .integer(2)]))
    }

    @Test("macroexpand fully expands nested macros")
    func macroexpandFull() throws {
        // (defmacro a [x] `(b ~x))
        // (defmacro b [x] x)
        // (macroexpand '(a 42)) => 42
        let swish = Swish()
        let result = try swish.eval("""
            (defmacro b [x] x)
            (defmacro a [x] `(b ~x))
            (macroexpand '(a 42))
            """)
        #expect(result == .integer(42))
    }

    @Test("macroexpand-1 returns non-list form unchanged")
    func macroexpand1Atom() throws {
        let swish = Swish()
        let result = try swish.eval("(macroexpand-1 42)")
        #expect(result == .integer(42))
    }

    @Test("defmacro with def template does not throw at parse time")
    func defmacroDefTemplateParses() throws {
        // `(def ~name ~value) inside a macro body must not be validated as a real def
        let swish = Swish()
        #expect(throws: Never.self) {
            try swish.eval("(defmacro defn [name value] `(def ~name ~value))")
        }
    }

    @Test("defmacro with fn template does not throw at parse time")
    func defmacroFnTemplateParses() throws {
        // `(def ~name (fn ~args ~body)) inside a macro body must not be validated as real fn
        let swish = Swish()
        #expect(throws: Never.self) {
            try swish.eval("(defmacro defn [name args body] `(def ~name (fn ~args ~body)))")
        }
    }

    @Test("defn macro defined via defmacro works end-to-end")
    func defnMacroEndToEnd() throws {
        let swish = Swish()
        let result = try swish.eval("""
            (defmacro defn [name args body] `(def ~name (fn ~args ~body)))
            (defn square [x] (* x x))
            (square 5)
            """)
        #expect(result == .integer(25))
    }
}

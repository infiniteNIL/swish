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

    @Test("List with integers evaluates to itself")
    func listWithIntegersSelfEvaluates() throws {
        let result = try evaluator.eval(.list([.integer(1), .integer(2), .integer(3)]))
        #expect(result == .list([.integer(1), .integer(2), .integer(3)]))
    }

    @Test("Nested list evaluates to itself")
    func nestedListSelfEvaluates() throws {
        let result = try evaluator.eval(.list([.integer(1), .list([.integer(2), .integer(3)]), .integer(4)]))
        #expect(result == .list([.integer(1), .list([.integer(2), .integer(3)]), .integer(4)]))
    }

    @Test("List evaluates symbols to their bound values")
    func listEvaluatesSymbols() throws {
        _ = try evaluator.eval(.list([.symbol("def"), .symbol("a"), .integer(5)]))
        let result = try evaluator.eval(.list([.symbol("a")]))
        #expect(result == .list([.integer(5)]))
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

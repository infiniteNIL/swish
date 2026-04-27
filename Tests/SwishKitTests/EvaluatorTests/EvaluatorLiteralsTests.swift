import Testing
@testable import SwishKit

@Suite("Evaluator Literals Tests")
struct EvaluatorLiteralsTests {
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

    @Test("Symbol registered in clojure.core is visible in user namespace")
    func coreEnvironmentSymbolVisibleDuringEval() throws {
        let evaluator = Evaluator()
        evaluator.findNs("clojure.core")!.intern(name: "pi", value: .float(3.14159))
        let result = try evaluator.eval(.symbol("pi"))
        #expect(result == .float(3.14159))
    }

    @Test("def interns into user namespace, not clojure.core")
    func defDoesNotAffectCoreEnvironment() throws {
        let evaluator = Evaluator()
        _ = try evaluator.eval(.list([.symbol("def"), .symbol("myVar"), .integer(7)]))
        #expect(evaluator.findNs("clojure.core")?.findVar(name: "myVar") == nil)

        let v = evaluator.findNs("user")?.findVar(name: "myVar")
        #expect(v?.value == .integer(7))
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
}

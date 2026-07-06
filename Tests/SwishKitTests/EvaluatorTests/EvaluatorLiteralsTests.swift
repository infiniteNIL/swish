import Testing
@testable import SwishKit

@Suite("Evaluator Literals Tests", .serialized)
struct EvaluatorLiteralsTests {
    static let _shared = Evaluator()
    var evaluator: Evaluator { Self._shared }

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
        let result = try evaluator.eval(.double(3.14))
        #expect(result == .double(3.14))
    }

    @Test("Negative float evaluates to itself")
    func negativeFloatSelfEvaluates() throws {
        let result = try evaluator.eval(.double(-2.5))
        #expect(result == .double(-2.5))
    }

    @Test("Float zero evaluates to itself")
    func floatZeroSelfEvaluates() throws {
        let result = try evaluator.eval(.double(0.0))
        #expect(result == .double(0.0))
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
        let result = try evaluator.eval(.list([], metadata: nil))
        #expect(result == .list([], metadata: nil))
    }

    @Test("List with integer head throws notAFunction")
    func listWithIntegerHeadThrows() throws {
        #expect(throws: EvaluatorError.notAFunction(.integer(1))) {
            try evaluator.eval(.list([.integer(1), .integer(2), .integer(3)], metadata: nil))
        }
    }

    @Test("Nested list with integer head throws notAFunction")
    func nestedListWithIntegerHeadThrows() throws {
        #expect(throws: EvaluatorError.notAFunction(.integer(1))) {
            try evaluator.eval(.list([.integer(1), .list([.integer(2), .integer(3)], metadata: nil), .integer(4)], metadata: nil))
        }
    }

    @Test("Symbol bound to non-function throws notAFunction")
    func symbolBoundToNonFunctionThrows() throws {
        _ = try evaluator.eval(.list([.symbol("def", metadata: nil), .symbol("a", metadata: nil), .integer(5)], metadata: nil))
        #expect(throws: EvaluatorError.notAFunction(.integer(5))) {
            try evaluator.eval(.list([.symbol("a", metadata: nil)], metadata: nil))
        }
    }

    @Test("nil as list head throws notAFunction")
    func nilAsListHeadThrows() throws {
        #expect(throws: EvaluatorError.notAFunction(.nil)) {
            try evaluator.eval(.list([.nil], metadata: nil))
        }
    }

    @Test("Keyword as list head with no args throws invalidArgument")
    func keywordAsListHeadNoArgsThrows() throws {
        #expect(throws: EvaluatorError.invalidArgument(function: "keyword", message: "requires 1 or 2 arguments, got 0")) {
            try evaluator.eval(.list([.keyword("foo")], metadata: nil))
        }
    }

    @Test("List with undefined symbol throws undefinedSymbol")
    func listWithUndefinedSymbolThrows() throws {
        #expect(throws: EvaluatorError.undefinedSymbol("nope")) {
            try evaluator.eval(.list([.symbol("nope", metadata: nil)], metadata: nil))
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
        evaluator.findNs("clojure.core")!.intern(name: "pi", value: .double(3.14159))
        let result = try evaluator.eval(.symbol("pi", metadata: nil))
        #expect(result == .double(3.14159))
    }

    @Test("def interns into user namespace, not clojure.core")
    func defDoesNotAffectCoreEnvironment() throws {
        let evaluator = Evaluator()
        _ = try evaluator.eval(.list([.symbol("def", metadata: nil), .symbol("myVar", metadata: nil), .integer(7)], metadata: nil))
        #expect(evaluator.findNs("clojure.core")?.findVar(name: "myVar") == nil)

        let v = evaluator.findNs("user")?.findVar(name: "myVar")
        #expect(v?.value == .integer(7))
    }

    // MARK: - vector literals

    @Test("Empty vector evaluates to empty vector")
    func emptyVectorEvaluates() throws {
        let result = try evaluator.eval(.vector([], metadata: nil))
        #expect(result == .vector([], metadata: nil))
    }

    @Test("Vector with literals evaluates elements")
    func vectorWithLiteralsEvaluates() throws {
        let result = try evaluator.eval(.vector([.integer(1), .boolean(true), .nil], metadata: nil))
        #expect(result == .vector([.integer(1), .boolean(true), .nil], metadata: nil))
    }

    @Test("Vector elements are evaluated")
    func vectorElementsAreEvaluated() throws {
        // (+ 1 1) inside a vector should evaluate to 2
        let result = try evaluator.eval(.vector([
            .integer(1),
            .list([.symbol("+", metadata: nil), .integer(1), .integer(1)], metadata: nil),
            .integer(3)
        ], metadata: nil))
        #expect(result == .vector([.integer(1), .integer(2), .integer(3)], metadata: nil))
    }

    @Test("Nested vector evaluates inner elements")
    func nestedVectorEvaluates() throws {
        let result = try evaluator.eval(.vector([
            .integer(1),
            .vector([.integer(2), .integer(3)], metadata: nil)
        ], metadata: nil))
        #expect(result == .vector([.integer(1), .vector([.integer(2), .integer(3)], metadata: nil)], metadata: nil))
    }
}

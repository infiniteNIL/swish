import Testing
@testable import SwishKit

@Suite("Evaluator Tests")
struct EvaluatorTests {
    let evaluator = Evaluator()

    @Test("Integer evaluates to itself")
    func integerSelfEvaluates() {
        let result = evaluator.eval(.integer(42))
        #expect(result == .integer(42))
    }

    @Test("Negative integer evaluates to itself")
    func negativeIntegerSelfEvaluates() {
        let result = evaluator.eval(.integer(-17))
        #expect(result == .integer(-17))
    }

    @Test("Zero evaluates to itself")
    func zeroSelfEvaluates() {
        let result = evaluator.eval(.integer(0))
        #expect(result == .integer(0))
    }

    // MARK: - Floating point literals

    @Test("Float evaluates to itself")
    func floatSelfEvaluates() {
        let result = evaluator.eval(.float(3.14))
        #expect(result == .float(3.14))
    }

    @Test("Negative float evaluates to itself")
    func negativeFloatSelfEvaluates() {
        let result = evaluator.eval(.float(-2.5))
        #expect(result == .float(-2.5))
    }

    @Test("Float zero evaluates to itself")
    func floatZeroSelfEvaluates() {
        let result = evaluator.eval(.float(0.0))
        #expect(result == .float(0.0))
    }

    // MARK: - Ratio literals

    @Test("Ratio evaluates to itself")
    func ratioSelfEvaluates() {
        let result = evaluator.eval(.ratio(Ratio(3, 4)))
        #expect(result == .ratio(Ratio(3, 4)))
    }

    @Test("Negative ratio evaluates to itself")
    func negativeRatioSelfEvaluates() {
        let result = evaluator.eval(.ratio(Ratio(-3, 4)))
        #expect(result == .ratio(Ratio(-3, 4)))
    }

    // MARK: - String literals

    @Test("String evaluates to itself")
    func stringSelfEvaluates() {
        let result = evaluator.eval(.string("hello"))
        #expect(result == .string("hello"))
    }

    @Test("Empty string evaluates to itself")
    func emptyStringSelfEvaluates() {
        let result = evaluator.eval(.string(""))
        #expect(result == .string(""))
    }

    @Test("String with escapes evaluates to itself")
    func stringWithEscapesSelfEvaluates() {
        let result = evaluator.eval(.string("hello\nworld"))
        #expect(result == .string("hello\nworld"))
    }

    // MARK: - Symbol literals

    @Test("Symbol evaluates to itself")
    func symbolSelfEvaluates() {
        let result = evaluator.eval(.symbol("foo"))
        #expect(result == .symbol("foo"))
    }

    @Test("Hyphenated symbol evaluates to itself")
    func hyphenatedSymbolSelfEvaluates() {
        let result = evaluator.eval(.symbol("foo-bar"))
        #expect(result == .symbol("foo-bar"))
    }

    @Test("+ symbol evaluates to itself")
    func plusSymbolSelfEvaluates() {
        let result = evaluator.eval(.symbol("+"))
        #expect(result == .symbol("+"))
    }

    @Test("Namespaced symbol evaluates to itself")
    func namespacedSymbolSelfEvaluates() {
        let result = evaluator.eval(.symbol("clojure.core/map"))
        #expect(result == .symbol("clojure.core/map"))
    }
}

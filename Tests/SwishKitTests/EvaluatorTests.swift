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
}

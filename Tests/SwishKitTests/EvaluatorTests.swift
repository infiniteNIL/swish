import Testing
@testable import SwishKit

@Suite("Evaluator Tests")
struct EvaluatorTests {
    @Test("Integer evaluates to itself")
    func integerSelfEvaluates() {
        let result = eval(.integer(42))
        #expect(result == .integer(42))
    }

    @Test("Negative integer evaluates to itself")
    func negativeIntegerSelfEvaluates() {
        let result = eval(.integer(-17))
        #expect(result == .integer(-17))
    }

    @Test("Zero evaluates to itself")
    func zeroSelfEvaluates() {
        let result = eval(.integer(0))
        #expect(result == .integer(0))
    }
}

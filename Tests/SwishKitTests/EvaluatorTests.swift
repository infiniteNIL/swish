import Testing
@testable import SwishKit

@Suite("Evaluator Tests")
struct EvaluatorTests {
    @Test("Integer evaluates to itself")
    func integerSelfEvaluates() {
        let result = evaluate(.integer(.int(42)))
        #expect(result == .integer(.int(42)))
    }

    @Test("Negative integer evaluates to itself")
    func negativeIntegerSelfEvaluates() {
        let result = evaluate(.integer(.int(-17)))
        #expect(result == .integer(.int(-17)))
    }

    @Test("Zero evaluates to itself")
    func zeroSelfEvaluates() {
        let result = evaluate(.integer(.int(0)))
        #expect(result == .integer(.int(0)))
    }
}

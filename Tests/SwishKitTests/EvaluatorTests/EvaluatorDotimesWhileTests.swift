import Testing
@testable import SwishKit

@Suite("Evaluator dotimes/while Tests", .serialized)
struct EvaluatorDotimesWhileTests {
    static let _shared = Swish()
    var swish: Swish { Self._shared }

    // MARK: - dotimes

    @Test("dotimes runs body n times with indices 0..<n")
    func dotimesRunsWithIndices() throws {
        #expect(
            try swish.eval("(let [a (atom [])] (dotimes [i 3] (swap! a conj i)) @a)")
                == .vector([.integer(0), .integer(1), .integer(2)], metadata: nil))
    }

    @Test("dotimes with n=0 runs zero times")
    func dotimesZero() throws {
        #expect(try swish.eval("(let [a (atom 0)] (dotimes [i 0] (swap! a inc)) @a)") == .integer(0))
    }

    // MARK: - while

    @Test("while runs until test goes false")
    func whileRunsUntilFalse() throws {
        #expect(try swish.eval("(let [a (atom 0)] (while (< @a 5) (swap! a inc)) @a)") == .integer(5))
    }

    @Test("while with initially-false test runs zero times")
    func whileInitiallyFalse() throws {
        #expect(try swish.eval("(let [a (atom 0)] (while false (swap! a inc)) @a)") == .integer(0))
    }
}

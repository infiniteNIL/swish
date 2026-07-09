import Testing
@testable import SwishKit

@Suite("Core zero? Tests", .serialized)
struct CoreZeroPredicateTests {
    nonisolated(unsafe) static let _shared = Swish()
    var swish: Swish { Self._shared }

    @Test("(zero? 0) is true")
    func zeroPredicateZero() throws {
        #expect(try swish.eval("(zero? 0)") == .boolean(true))
    }

    @Test("(zero? 0.0) is true")
    func zeroPredicateDoubleZero() throws {
        #expect(try swish.eval("(zero? 0.0)") == .boolean(true))
    }

    @Test("(zero? 1) is false")
    func zeroPredicateOne() throws {
        #expect(try swish.eval("(zero? 1)") == .boolean(false))
    }

    @Test("(zero? ##NaN) is false")
    func zeroPredicateNaN() throws {
        #expect(try swish.eval("(zero? ##NaN)") == .boolean(false))
    }

    @Test("(zero? ##Inf) is false")
    func zeroPredicateInfinity() throws {
        #expect(try swish.eval("(zero? ##Inf)") == .boolean(false))
    }
}

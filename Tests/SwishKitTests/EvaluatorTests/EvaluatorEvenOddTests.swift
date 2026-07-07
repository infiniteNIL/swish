import Testing
@testable import SwishKit

@Suite("Evaluator even? and odd? Tests", .serialized)
struct EvaluatorEvenOddTests {
    nonisolated(unsafe) static let _shared = Swish()
    var swish: Swish { Self._shared }

    // MARK: - even? valid inputs

    @Test("even? 0 is true")
    func evenZero() throws {
        #expect(try swish.eval("(even? 0)") == .boolean(true))
    }

    @Test("even? 12 is true")
    func evenTwelve() throws {
        #expect(try swish.eval("(even? 12)") == .boolean(true))
    }

    @Test("even? 17 is false")
    func evenSeventeen() throws {
        #expect(try swish.eval("(even? 17)") == .boolean(false))
    }

    @Test("even? -118 is true")
    func evenNeg118() throws {
        #expect(try swish.eval("(even? -118)") == .boolean(true))
    }

    @Test("even? -119 is false")
    func evenNeg119() throws {
        #expect(try swish.eval("(even? -119)") == .boolean(false))
    }

    @Test("even? 122N is true")
    func evenBigInt122() throws {
        #expect(try swish.eval("(even? 122N)") == .boolean(true))
    }

    @Test("even? 123N is false")
    func evenBigInt123() throws {
        #expect(try swish.eval("(even? 123N)") == .boolean(false))
    }

    // MARK: - even? invalid inputs

    @Test("even? nil throws")
    func evenNilThrows() throws {
        #expect(throws: (any Error).self) { try swish.eval("(even? nil)") }
    }

    @Test("even? ##Inf throws")
    func evenInfThrows() throws {
        #expect(throws: (any Error).self) { try swish.eval("(even? ##Inf)") }
    }

    @Test("even? ##-Inf throws")
    func evenNegInfThrows() throws {
        #expect(throws: (any Error).self) { try swish.eval("(even? ##-Inf)") }
    }

    @Test("even? ##NaN throws")
    func evenNaNThrows() throws {
        #expect(throws: (any Error).self) { try swish.eval("(even? ##NaN)") }
    }

    @Test("even? 1.5 throws")
    func evenFloatThrows() throws {
        #expect(throws: (any Error).self) { try swish.eval("(even? 1.5)") }
    }

    @Test("even? 0.2M throws")
    func evenBigDecimalThrows() throws {
        #expect(throws: (any Error).self) { try swish.eval("(even? 0.2M)") }
    }

    @Test("even? 1/2 throws")
    func evenRatioThrows() throws {
        #expect(throws: (any Error).self) { try swish.eval("(even? 1/2)") }
    }

    // MARK: - odd? valid inputs

    @Test("odd? 0 is false")
    func oddZero() throws {
        #expect(try swish.eval("(odd? 0)") == .boolean(false))
    }

    @Test("odd? 17 is true")
    func oddSeventeen() throws {
        #expect(try swish.eval("(odd? 17)") == .boolean(true))
    }

    @Test("odd? 12 is false")
    func oddTwelve() throws {
        #expect(try swish.eval("(odd? 12)") == .boolean(false))
    }

    // MARK: - odd? invalid inputs

    @Test("odd? 1.5 throws")
    func oddFloatThrows() throws {
        #expect(throws: (any Error).self) { try swish.eval("(odd? 1.5)") }
    }

    @Test("odd? 1/2 throws")
    func oddRatioThrows() throws {
        #expect(throws: (any Error).self) { try swish.eval("(odd? 1/2)") }
    }
}

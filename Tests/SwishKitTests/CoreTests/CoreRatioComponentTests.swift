import Testing
@testable import SwishKit

@Suite("Core numerator/denominator Tests", .serialized)
struct CoreRatioComponentTests {
    static let _shared = Swish()
    var swish: Swish { Self._shared }

    // MARK: - numerator on ratios

    @Test("(numerator 1/2) returns 1")
    func numeratorHalf() throws {
        #expect(try swish.eval("(numerator 1/2)") == .integer(1))
    }

    @Test("(numerator 2/3) returns 2")
    func numeratorTwoThirds() throws {
        #expect(try swish.eval("(numerator 2/3)") == .integer(2))
    }

    @Test("(numerator 3/4) returns 3")
    func numeratorThreeQuarters() throws {
        #expect(try swish.eval("(numerator 3/4)") == .integer(3))
    }

    @Test("(numerator -1/2) returns -1")
    func numeratorNegative() throws {
        #expect(try swish.eval("(numerator -1/2)") == .integer(-1))
    }

    // MARK: - denominator on ratios

    @Test("(denominator 1/2) returns 2")
    func denominatorHalf() throws {
        #expect(try swish.eval("(denominator 1/2)") == .integer(2))
    }

    @Test("(denominator 2/3) returns 3")
    func denominatorTwoThirds() throws {
        #expect(try swish.eval("(denominator 2/3)") == .integer(3))
    }

    @Test("(denominator 3/4) returns 4")
    func denominatorThreeQuarters() throws {
        #expect(try swish.eval("(denominator 3/4)") == .integer(4))
    }

    @Test("(denominator -1/2) returns 2")
    func denominatorNegative() throws {
        #expect(try swish.eval("(denominator -1/2)") == .integer(2))
    }

    // MARK: - non-ratio arguments throw

    @Test("numerator throws for non-ratio arguments")
    func numeratorThrowsForNonRatio() throws {
        #expect(throws: (any Error).self) { try swish.eval("(numerator 1)") }
        #expect(throws: (any Error).self) { try swish.eval("(numerator 1N)") }
        #expect(throws: (any Error).self) { try swish.eval("(numerator 1.0)") }
        #expect(throws: (any Error).self) { try swish.eval("(numerator 1.0M)") }
        #expect(throws: (any Error).self) { try swish.eval("(numerator ##Inf)") }
        #expect(throws: (any Error).self) { try swish.eval("(numerator ##NaN)") }
        #expect(throws: (any Error).self) { try swish.eval("(numerator nil)") }
    }

    @Test("denominator throws for non-ratio arguments")
    func denominatorThrowsForNonRatio() throws {
        #expect(throws: (any Error).self) { try swish.eval("(denominator 1)") }
        #expect(throws: (any Error).self) { try swish.eval("(denominator 1N)") }
        #expect(throws: (any Error).self) { try swish.eval("(denominator 1.0)") }
        #expect(throws: (any Error).self) { try swish.eval("(denominator 1.0M)") }
        #expect(throws: (any Error).self) { try swish.eval("(denominator ##Inf)") }
        #expect(throws: (any Error).self) { try swish.eval("(denominator ##NaN)") }
        #expect(throws: (any Error).self) { try swish.eval("(denominator nil)") }
    }
}

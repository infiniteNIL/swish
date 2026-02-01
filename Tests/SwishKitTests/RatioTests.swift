import Testing
@testable import SwishKit

@Suite("Ratio Tests")
struct RatioTests {
    @Test("Creates ratio with given values")
    func createsRatio() {
        let ratio = Ratio(3, 4)
        #expect(ratio.numerator == 3)
        #expect(ratio.denominator == 4)
    }

    @Test("Reduces ratio using GCD")
    func reducesRatio() {
        let ratio = Ratio(10, 4)
        #expect(ratio.numerator == 5)
        #expect(ratio.denominator == 2)
    }

    @Test("Reduces ratio to simplest form")
    func reducesToSimplestForm() {
        let ratio = Ratio(6, 3)
        #expect(ratio.numerator == 2)
        #expect(ratio.denominator == 1)
    }

    @Test("Handles negative numerator")
    func handlesNegativeNumerator() {
        let ratio = Ratio(-3, 4)
        #expect(ratio.numerator == -3)
        #expect(ratio.denominator == 4)
    }

    @Test("Handles negative denominator")
    func handlesNegativeDenominator() {
        let ratio = Ratio(3, -4)
        #expect(ratio.numerator == -3)
        #expect(ratio.denominator == 4)
    }

    @Test("Handles both negative")
    func handlesBothNegative() {
        let ratio = Ratio(-3, -4)
        #expect(ratio.numerator == 3)
        #expect(ratio.denominator == 4)
    }

    @Test("Handles zero numerator")
    func handlesZeroNumerator() {
        let ratio = Ratio(0, 5)
        #expect(ratio.numerator == 0)
        #expect(ratio.denominator == 1)
    }

    @Test("Reduces with GCD of large numbers")
    func reducesLargeNumbers() {
        let ratio = Ratio(1000, 4)
        #expect(ratio.numerator == 250)
        #expect(ratio.denominator == 1)
    }

    @Test("Equality works correctly")
    func equalityWorks() {
        let r1 = Ratio(1, 2)
        let r2 = Ratio(2, 4)
        #expect(r1 == r2)
    }

    @Test("Inequality works correctly")
    func inequalityWorks() {
        let r1 = Ratio(1, 2)
        let r2 = Ratio(1, 3)
        #expect(r1 != r2)
    }

    @Test("Hashable works correctly")
    func hashableWorks() {
        let r1 = Ratio(1, 2)
        let r2 = Ratio(2, 4)
        #expect(r1.hashValue == r2.hashValue)
    }
}

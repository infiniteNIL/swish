import Testing
@testable import SwishKit

@Suite("Core rationalize Tests", .serialized)
struct CoreRationalizeTests {
    static let _shared = Swish()
    var swish: Swish { Self._shared }

    // MARK: - identity for already-exact types

    @Test("rationalize returns integers unchanged")
    func rationalizeIntegerIdentity() throws {
        #expect(try swish.eval("(rationalize 1)") == .integer(1))
        #expect(try swish.eval("(rationalize 0)") == .integer(0))
        #expect(try swish.eval("(rationalize -1)") == .integer(-1))
    }

    @Test("rationalize returns bigints unchanged")
    func rationalizeBigIntIdentity() throws {
        #expect(try swish.eval("(rationalize 1N)") == .bigInteger(1))
        #expect(try swish.eval("(rationalize 0N)") == .bigInteger(0))
        #expect(try swish.eval("(rationalize -1N)") == .bigInteger(-1))
    }

    @Test("rationalize returns ratios unchanged")
    func rationalizeRatioIdentity() throws {
        #expect(try swish.eval("(rationalize 3/2)") == .ratio(Ratio(3, 2)))
    }

    // MARK: - doubles reducing to whole numbers become BigInt, not Long

    @Test("rationalize on whole-number doubles returns a BigInt")
    func rationalizeWholeNumberDouble() throws {
        #expect(try swish.eval("(rationalize 1.0)") == .bigInteger(1))
        #expect(try swish.eval("(rationalize 0.0)") == .bigInteger(0))
        #expect(try swish.eval("(rationalize -1.0)") == .bigInteger(-1))
    }

    @Test("(rationalize 1.0) is both integer? and bigint?, matching real Clojure's 1N")
    func rationalizeWholeNumberDoubleIsBigInt() throws {
        #expect(try swish.eval("(integer? (rationalize 1.0))") == .boolean(true))
        #expect(try swish.eval("(bigint? (rationalize 1.0))") == .boolean(true))
    }

    // MARK: - doubles use the shortest round-trip representation, not the exact binary expansion

    @Test("(rationalize 1.5) returns 3/2")
    func rationalizeOneAndHalf() throws {
        #expect(try swish.eval("(rationalize 1.5)") == .ratio(Ratio(3, 2)))
    }

    @Test("(rationalize 1.1) returns 11/10, not the exact IEEE754 binary expansion of 0.1")
    func rationalizeOnePointOne() throws {
        #expect(try swish.eval("(rationalize 1.1)") == .ratio(Ratio(11, 10)))
    }

    @Test("(rationalize (/ 1.0 3.0)) returns the 16-digit shortest-round-trip fraction")
    func rationalizeOneThird() throws {
        #expect(try swish.eval("(rationalize (/ 1.0 3.0))") == .ratio(Ratio(3333333333333333, 10000000000000000)))
    }

    // MARK: - BigDecimal follows the same unscaledValue/scale reduction

    @Test("rationalize on whole-number BigDecimals returns a BigInt")
    func rationalizeWholeNumberBigDecimal() throws {
        #expect(try swish.eval("(rationalize 1.0M)") == .bigInteger(1))
        #expect(try swish.eval("(rationalize 0.0M)") == .bigInteger(0))
    }

    @Test("(rationalize 1.5M) returns 3/2")
    func rationalizeBigDecimalOneAndHalf() throws {
        #expect(try swish.eval("(rationalize 1.5M)") == .ratio(Ratio(3, 2)))
    }

    @Test("(rationalize 1.1M) returns 11/10")
    func rationalizeBigDecimalOnePointOne() throws {
        #expect(try swish.eval("(rationalize 1.1M)") == .ratio(Ratio(11, 10)))
    }

    // MARK: - throws for non-numeric types

    @Test("rationalize throws for non-numeric types")
    func rationalizeThrows() throws {
        #expect(throws: (any Error).self) { try swish.eval("(rationalize nil)") }
        #expect(throws: (any Error).self) { try swish.eval("(rationalize \"1.5\")") }
        #expect(throws: (any Error).self) { try swish.eval("(rationalize :key)") }
        #expect(throws: (any Error).self) { try swish.eval("(rationalize [1])") }
    }
}

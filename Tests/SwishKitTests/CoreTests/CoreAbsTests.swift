import BigDecimal
import BigInt
import Testing
@testable import SwishKit

@Suite("Core abs Tests", .serialized)
struct CoreAbsTests {
    nonisolated(unsafe) static let _shared = Swish()
    var swish: Swish { Self._shared }

    // MARK: - Integer

    @Test("(abs 1) returns 1")
    func absPositiveInt() throws {
        #expect(try swish.eval("(abs 1)") == .integer(1))
    }

    @Test("(abs -1) returns 1")
    func absNegativeInt() throws {
        #expect(try swish.eval("(abs -1)") == .integer(1))
    }

    @Test("(abs 0) returns 0")
    func absZeroInt() throws {
        #expect(try swish.eval("(abs 0)") == .integer(0))
    }

    @Test("(abs Long/MIN_VALUE) returns Long/MIN_VALUE (2's complement)")
    func absMinInt() throws {
        #expect(try swish.eval("(abs \(Int.min))") == .integer(Int.min))
    }

    // MARK: - Double

    @Test("(abs -1.0) returns 1.0")
    func absNegativeDouble() throws {
        #expect(try swish.eval("(abs -1.0)") == .double(1.0))
    }

    @Test("(abs 1.0) returns 1.0")
    func absPositiveDouble() throws {
        #expect(try swish.eval("(abs 1.0)") == .double(1.0))
    }

    @Test("(abs -0.0) returns +0.0")
    func absNegativeZeroDouble() throws {
        #expect(try swish.eval("(abs -0.0)") == .double(0.0))
        #expect(try swish.eval("(/ 1.0 (abs -0.0))") == .double(.infinity))
    }

    @Test("(abs ##-Inf) returns ##Inf")
    func absNegativeInf() throws {
        #expect(try swish.eval("(abs ##-Inf)") == .double(.infinity))
    }

    @Test("(abs ##Inf) returns ##Inf")
    func absPositiveInf() throws {
        #expect(try swish.eval("(abs ##Inf)") == .double(.infinity))
    }

    @Test("(NaN? (abs ##NaN)) is true")
    func absNaN() throws {
        #expect(try swish.eval("(NaN? (abs ##NaN))") == .boolean(true))
    }

    // MARK: - Float

    @Test("(abs (float -1.0)) returns positive float")
    func absNegativeFloat() throws {
        #expect(try swish.eval("(abs (float -1.0))") == .float(1.0))
    }

    @Test("(abs (float 1.0)) returns same float unchanged")
    func absPositiveFloat() throws {
        #expect(try swish.eval("(abs (float 1.0))") == .float(1.0))
    }

    // MARK: - Ratio

    @Test("(abs -1/5) returns 1/5")
    func absNegativeRatio() throws {
        #expect(try swish.eval("(abs -1/5)") == .ratio(Ratio(1, 5)))
    }

    @Test("(abs 1/5) returns 1/5")
    func absPositiveRatio() throws {
        #expect(try swish.eval("(abs 1/5)") == .ratio(Ratio(1, 5)))
    }

    // MARK: - BigInteger

    @Test("(abs -123N) returns 123N")
    func absNegativeBigInt() throws {
        #expect(try swish.eval("(abs -123N)") == .bigInteger(BigInt(123)))
    }

    @Test("(abs 123N) returns 123N")
    func absPositiveBigInt() throws {
        #expect(try swish.eval("(abs 123N)") == .bigInteger(BigInt(123)))
    }

    // MARK: - BigDecimal

    @Test("(abs -123.456M) returns 123.456M")
    func absNegativeBigDecimal() throws {
        #expect(try swish.eval("(abs -123.456M)") == .bigDecimal(BigDecimal("123.456")!))
    }

    @Test("(abs 123.456M) returns 123.456M")
    func absPositiveBigDecimal() throws {
        #expect(try swish.eval("(abs 123.456M)") == .bigDecimal(BigDecimal("123.456")!))
    }

    // MARK: - Error cases

    @Test("(abs nil) throws")
    func absNilThrows() throws {
        #expect(throws: (any Error).self) { try swish.eval("(abs nil)") }
    }

    @Test("(abs \"foo\") throws")
    func absStringThrows() throws {
        #expect(throws: (any Error).self) { try swish.eval("(abs \"foo\")") }
    }
}

import Testing
@testable import SwishKit
import BigInt

@Suite("BigInteger arithmetic Tests", .serialized)
struct CoreBigIntegerArithmeticTests {
    static let _shared = Swish()
    var swish: Swish { Self._shared }

    @Test("even? returns false for odd BigInteger")
    func evenOddBigInteger() throws {
        #expect(try swish.eval("(even? 123N)") == .boolean(false))
    }

    @Test("even? returns true for even BigInteger")
    func evenEvenBigInteger() throws {
        #expect(try swish.eval("(even? 122N)") == .boolean(true))
    }

    @Test("even? returns false for negative odd BigInteger")
    func evenNegativeOddBigInteger() throws {
        #expect(try swish.eval("(even? -121N)") == .boolean(false))
    }

    @Test("even? returns true for negative even BigInteger")
    func evenNegativeEvenBigInteger() throws {
        #expect(try swish.eval("(even? -120N)") == .boolean(true))
    }

    @Test("mod with BigInteger dividend")
    func modBigIntegerDividend() throws {
        #expect(try swish.eval("(mod 10N 3)") == .bigInteger(1))
    }

    @Test("mod with two BigIntegers")
    func modTwoBigIntegers() throws {
        #expect(try swish.eval("(mod 10N 3N)") == .bigInteger(1))
    }

    @Test("rem with BigInteger")
    func remBigInteger() throws {
        #expect(try swish.eval("(rem -13N 4)") == .bigInteger(-1))
    }

    @Test("quot with BigInteger")
    func quotBigInteger() throws {
        #expect(try swish.eval("(quot 13N 4)") == .bigInteger(3))
    }

    @Test("integer equals BigInteger of same value")
    func integerEqualsBigInteger() throws {
        #expect(try swish.eval("(= 0 0N)") == .boolean(true))
        #expect(try swish.eval("(= 42 42N)") == .boolean(true))
        #expect(try swish.eval("(= 42 43N)") == .boolean(false))
    }

    @Test("BigInteger can be used as map key equal to integer key")
    func bigIntegerMapKey() throws {
        #expect(try swish.eval("(get {1 :a} 1N)") == .keyword("a"))
    }

    @Test("bigint coerces an integer")
    func bigintFromInteger() throws {
        #expect(try swish.eval("(bigint 42)") == .bigInteger(42))
        #expect(try swish.eval("(bigint -1)") == .bigInteger(-1))
    }

    @Test("bigint coerces a double by truncating")
    func bigintFromDouble() throws {
        #expect(try swish.eval("(bigint 1.0)") == .bigInteger(1))
        #expect(try swish.eval("(bigint 1.9)") == .bigInteger(1))
        #expect(try swish.eval("(bigint -1.9)") == .bigInteger(-1))
    }

    @Test("bigint coerces a string")
    func bigintFromString() throws {
        #expect(try swish.eval("(bigint \"1\")") == .bigInteger(1))
        #expect(try swish.eval("(bigint \"-1\")") == .bigInteger(-1))
    }

    @Test("bigint coerces a ratio that reduces to a whole number")
    func bigintFromRatio() throws {
        #expect(try swish.eval("(bigint 12/12)") == .bigInteger(1))
        #expect(try swish.eval("(bigint -12/12)") == .bigInteger(-1))
    }

    @Test("bigint on an existing BigInteger returns it unchanged")
    func bigintFromBigInteger() throws {
        #expect(try swish.eval("(bigint 5N)") == .bigInteger(5))
    }

    @Test("bigint throws for NaN and Infinity")
    func bigintNonFiniteThrows() throws {
        #expect(throws: (any Error).self) { try swish.eval("(bigint ##NaN)") }
        #expect(throws: (any Error).self) { try swish.eval("(bigint ##Inf)") }
    }

    @Test("bigint throws for a non-numeric string")
    func bigintInvalidStringThrows() throws {
        #expect(throws: (any Error).self) { try swish.eval("(bigint \"not a number\")") }
    }

    @Test("bigdec coerces an integer and a BigInteger")
    func bigdecFromIntegerAndBigInteger() throws {
        #expect(try swish.eval("(= 1M (bigdec 1))") == .boolean(true))
        #expect(try swish.eval("(= 1M (bigdec 1N))") == .boolean(true))
        #expect(try swish.eval("(= -1M (bigdec -1N))") == .boolean(true))
    }

    @Test("bigdec coerces a double")
    func bigdecFromDouble() throws {
        #expect(try swish.eval("(= 1M (bigdec 1.0))") == .boolean(true))
        #expect(try swish.eval("(= 0.5M (bigdec 0.5))") == .boolean(true))
    }

    @Test("bigdec coerces a string")
    func bigdecFromString() throws {
        #expect(try swish.eval("(= 0.5M (bigdec \"0.5\"))") == .boolean(true))
        #expect(try swish.eval("(= -0.5M (bigdec \"-0.5\"))") == .boolean(true))
    }

    @Test("bigdec coerces a ratio")
    func bigdecFromRatio() throws {
        #expect(try swish.eval("(= 0.5M (bigdec 1/2))") == .boolean(true))
        #expect(try swish.eval("(= -0.5M (bigdec -1/2))") == .boolean(true))
    }

    @Test("bigdec on an existing BigDecimal returns it unchanged, and satisfies decimal?")
    func bigdecIdentityAndDecimalPredicate() throws {
        #expect(try swish.eval("(= 1.5M (bigdec 1.5M))") == .boolean(true))
        #expect(try swish.eval("(decimal? (bigdec 1))") == .boolean(true))
    }

    @Test("bigdec throws for NaN, Infinity, and a non-numeric string")
    func bigdecInvalidInputsThrow() throws {
        #expect(throws: (any Error).self) { try swish.eval("(bigdec ##NaN)") }
        #expect(throws: (any Error).self) { try swish.eval("(bigdec ##Inf)") }
        #expect(throws: (any Error).self) { try swish.eval("(bigdec \"not a number\")") }
    }

    @Test("inc' promotes to BigInteger on overflow, passes through otherwise")
    func incPPromotesOnOverflow() throws {
        #expect(try swish.eval("(inc' 5)") == .integer(6))
        #expect(try swish.eval("(= 9223372036854775808N (inc (bigint 9223372036854775807)) (inc' 9223372036854775807))") == .boolean(true))
        #expect(try swish.eval("(bigint? (inc' 9223372036854775807))") == .boolean(true))
    }

    @Test("dec' promotes to BigInteger on underflow, passes through otherwise")
    func decPPromotesOnUnderflow() throws {
        #expect(try swish.eval("(dec' 5)") == .integer(4))
        #expect(try swish.eval("(= -9223372036854775809N (dec (bigint -9223372036854775808)) (dec' -9223372036854775808))") == .boolean(true))
        #expect(try swish.eval("(bigint? (dec' -9223372036854775808))") == .boolean(true))
    }

    @Test("inc'/dec' work on non-integer numeric types")
    func incPDecPNonIntegerTypes() throws {
        #expect(try swish.eval("(inc' 1.5)") == .double(2.5))
        #expect(try swish.eval("(dec' 1.5)") == .double(0.5))
        #expect(try swish.eval("(inc' 5N)") == .bigInteger(6))
    }
}

import Testing
@testable import SwishKit
import BigInt

@Suite("BigInteger arithmetic Tests", .serialized)
struct CoreBigIntegerArithmeticTests {
    nonisolated(unsafe) static let _shared = Swish()
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
}

import Testing
@testable import SwishKit

@Suite("Core BigInt / BigDecimal Tests", .serialized)
struct CoreBigNumberTests {
    nonisolated(unsafe) static let _shared = Swish()
    var swish: Swish { Self._shared }

    // MARK: - Predicates

    @Test("(bigint? 1N) returns true")
    func bigintPredicateTrue() throws {
        #expect(try swish.eval("(bigint? 1N)") == .boolean(true))
    }

    @Test("(bigint? 1) returns false")
    func bigintPredicateFalseInt() throws {
        #expect(try swish.eval("(bigint? 1)") == .boolean(false))
    }

    @Test("(bigint? 1.5) returns false")
    func bigintPredicateFalseFloat() throws {
        #expect(try swish.eval("(bigint? 1.5)") == .boolean(false))
    }

    @Test("(bigint? 1.5M) returns false")
    func bigintPredicateFalseBigDecimal() throws {
        #expect(try swish.eval("(bigint? 1.5M)") == .boolean(false))
    }

    @Test("(decimal? 1.5M) returns true")
    func decimalPredicateTrue() throws {
        #expect(try swish.eval("(decimal? 1.5M)") == .boolean(true))
    }

    @Test("(decimal? 1.5) returns false")
    func decimalPredicateFalseFloat() throws {
        #expect(try swish.eval("(decimal? 1.5)") == .boolean(false))
    }

    @Test("(decimal? 1N) returns false")
    func decimalPredicateFalseBigInt() throws {
        #expect(try swish.eval("(decimal? 1N)") == .boolean(false))
    }

    @Test("(integer? 1N) returns true")
    func integerPredicateBigInt() throws {
        #expect(try swish.eval("(integer? 1N)") == .boolean(true))
    }

    @Test("(integer? 1) returns true")
    func integerPredicateInt() throws {
        #expect(try swish.eval("(integer? 1)") == .boolean(true))
    }

    @Test("(integer? 1.5M) returns false")
    func integerPredicateBigDecimalFalse() throws {
        #expect(try swish.eval("(integer? 1.5M)") == .boolean(false))
    }

    @Test("(int? 1N) returns false")
    func intPredicateBigIntFalse() throws {
        #expect(try swish.eval("(int? 1N)") == .boolean(false))
    }

    @Test("(number? 1N) returns true")
    func numberPredicateBigInt() throws {
        #expect(try swish.eval("(number? 1N)") == .boolean(true))
    }

    @Test("(number? 1.5M) returns true")
    func numberPredicateBigDecimal() throws {
        #expect(try swish.eval("(number? 1.5M)") == .boolean(true))
    }

    // MARK: - BigInt arithmetic

    @Test("(+ 1N 2N) returns 3N")
    func addBigInts() throws {
        #expect(try swish.eval("(str (+ 1N 2N))") == .string("3"))
    }

    @Test("(- 10N 3N) returns 7N")
    func subtractBigInts() throws {
        #expect(try swish.eval("(str (- 10N 3N))") == .string("7"))
    }

    @Test("(* 6N 7N) returns 42N")
    func multiplyBigInts() throws {
        #expect(try swish.eval("(str (* 6N 7N))") == .string("42"))
    }

    @Test("(/ 10N 3N) returns 3N (truncating division)")
    func divideBigInts() throws {
        #expect(try swish.eval("(str (/ 10N 3N))") == .string("3"))
    }

    @Test("(- 5N) negates BigInt")
    func negateBigInt() throws {
        #expect(try swish.eval("(str (- 5N))") == .string("-5"))
    }

    @Test("(+ 1N 2) promotes Int to BigInt")
    func addBigIntAndInt() throws {
        #expect(try swish.eval("(str (+ 1N 2))") == .string("3"))
    }

    @Test("(+ 1N 2.0) promotes BigInt to Double")
    func addBigIntAndFloat() throws {
        #expect(try swish.eval("(+ 1N 2.0)") == .double(3.0))
    }

    @Test("(+ 1N 1.5M) promotes BigInt to BigDecimal")
    func addBigIntAndBigDecimal() throws {
        #expect(try swish.eval("(decimal? (+ 1N 1.5M))") == .boolean(true))
    }

    // MARK: - BigDecimal arithmetic

    @Test("(+ 1.5M 0.5M) returns 2.0M")
    func addBigDecimals() throws {
        #expect(try swish.eval("(decimal? (+ 1.5M 0.5M))") == .boolean(true))
    }

    @Test("(- 2.0M 0.5M) is a BigDecimal")
    func subtractBigDecimals() throws {
        #expect(try swish.eval("(decimal? (- 2.0M 0.5M))") == .boolean(true))
    }

    @Test("(* 2.0M 3.0M) is a BigDecimal")
    func multiplyBigDecimals() throws {
        #expect(try swish.eval("(decimal? (* 2.0M 3.0M))") == .boolean(true))
    }

    @Test("(- 1.5M) negates BigDecimal")
    func negateBigDecimal() throws {
        #expect(try swish.eval("(decimal? (- 1.5M))") == .boolean(true))
    }

    @Test("(+ 1 1.5M) promotes Int to BigDecimal")
    func addIntAndBigDecimal() throws {
        #expect(try swish.eval("(decimal? (+ 1 1.5M))") == .boolean(true))
    }

    @Test("(+ 1.0 1.5M) Double is contagious over BigDecimal")
    func addFloatAndBigDecimal() throws {
        #expect(try swish.eval("(double? (+ 1.0 1.5M))") == .boolean(true))
    }

    @Test("BigDecimal wins over BigInt in mixed arithmetic")
    func bigDecimalWinsOverBigInt() throws {
        #expect(try swish.eval("(decimal? (+ 1N 1.0M))") == .boolean(true))
    }

    // MARK: - Equality

    @Test("(= 1N 1N) returns true")
    func bigIntEqualSelf() throws {
        #expect(try swish.eval("(= 1N 1N)") == .boolean(true))
    }

    @Test("(= 1N 2N) returns false")
    func bigIntNotEqual() throws {
        #expect(try swish.eval("(= 1N 2N)") == .boolean(false))
    }

    @Test("(= 1.5M 1.5M) returns true")
    func bigDecimalEqualSelf() throws {
        #expect(try swish.eval("(= 1.5M 1.5M)") == .boolean(true))
    }

    @Test("(= 1.5M 2.5M) returns false")
    func bigDecimalNotEqual() throws {
        #expect(try swish.eval("(= 1.5M 2.5M)") == .boolean(false))
    }

    // MARK: - Comparison

    @Test("(< 1N 2N) returns true")
    func bigIntLessThan() throws {
        #expect(try swish.eval("(< 1N 2N)") == .boolean(true))
    }

    @Test("(< 2N 1N) returns false")
    func bigIntGreaterThan() throws {
        #expect(try swish.eval("(< 2N 1N)") == .boolean(false))
    }

    @Test("(> 5N 3N) returns true")
    func bigIntGT() throws {
        #expect(try swish.eval("(> 5N 3N)") == .boolean(true))
    }

    @Test("(<= 3N 3N) returns true")
    func bigIntLTE() throws {
        #expect(try swish.eval("(<= 3N 3N)") == .boolean(true))
    }

    @Test("(< 1.0M 2.0M) returns true")
    func bigDecimalLessThan() throws {
        #expect(try swish.eval("(< 1.0M 2.0M)") == .boolean(true))
    }

    @Test("(> 2.5M 1.5M) returns true")
    func bigDecimalGreaterThan() throws {
        #expect(try swish.eval("(> 2.5M 1.5M)") == .boolean(true))
    }

    @Test("(< 1N 2) mixed BigInt and Int comparison")
    func bigIntAndIntComparison() throws {
        #expect(try swish.eval("(< 1N 2)") == .boolean(true))
    }

    // MARK: - Clojure radix notation evaluation

    @Test("(= 15 2r1111) binary radix equals decimal")
    func binaryRadixEquals() throws {
        #expect(try swish.eval("(= 15 2r1111)") == .boolean(true))
    }

    @Test("(= 255 16rFF) hex radix equals decimal")
    func hexRadixEquals() throws {
        #expect(try swish.eval("(= 255 16rFF)") == .boolean(true))
    }

    @Test("(= 127 8r177) octal radix equals decimal")
    func octalRadixEquals() throws {
        #expect(try swish.eval("(= 127 8r177)") == .boolean(true))
    }

    @Test("(= 35 36rZ) base-36 radix equals decimal")
    func base36RadixEquals() throws {
        #expect(try swish.eval("(= 35 36rZ)") == .boolean(true))
    }

    @Test("(= -10 -2r1010) negative binary radix")
    func negativeBinaryRadix() throws {
        #expect(try swish.eval("(= -10 -2r1010)") == .boolean(true))
    }

    @Test("2r1111N parses as BigInt 15")
    func binaryRadixBigInt() throws {
        #expect(try swish.eval("(= 15N 2r1111N)") == .boolean(true))
    }

    @Test("(float 1) returns 1.0")
    func floatFromInt() throws {
        #expect(try swish.eval("(float 1)") == .double(1.0))
    }

    @Test("(float 1/2) returns 0.5")
    func floatFromRatio() throws {
        #expect(try swish.eval("(float 1/2)") == .double(0.5))
    }

    @Test("(float 2N) returns 2.0")
    func floatFromBigInteger() throws {
        #expect(try swish.eval("(float 2N)") == .double(2.0))
    }

    @Test("(double 3) returns 3.0")
    func doubleFromInt() throws {
        #expect(try swish.eval("(double 3)") == .double(3.0))
    }

    @Test("(float? (float 1.0)) returns true")
    func floatPredicateAfterFloat() throws {
        #expect(try swish.eval("(float? (float 1.0))") == .boolean(true))
    }

    @Test("(float? (double 1.0)) returns true")
    func floatPredicateAfterDouble() throws {
        #expect(try swish.eval("(float? (double 1.0))") == .boolean(true))
    }
}

import Testing
@testable import SwishKit

@Suite("Core rational? Tests", .serialized)
struct CoreRationalPredicateTests {
    static let _shared = Swish()
    var swish: Swish { Self._shared }

    @Test("rational? is true for integers, including Int64 boundaries")
    func rationalTrueForIntegers() throws {
        #expect(try swish.eval("(rational? 0)") == .boolean(true))
        #expect(try swish.eval("(rational? 1)") == .boolean(true))
        #expect(try swish.eval("(rational? -1)") == .boolean(true))
        #expect(try swish.eval("(rational? 9223372036854775807)") == .boolean(true))
        #expect(try swish.eval("(rational? -9223372036854775808)") == .boolean(true))
    }

    @Test("rational? is true for bigints")
    func rationalTrueForBigInts() throws {
        #expect(try swish.eval("(rational? 0N)") == .boolean(true))
        #expect(try swish.eval("(rational? 1N)") == .boolean(true))
        #expect(try swish.eval("(rational? -1N)") == .boolean(true))
    }

    @Test("rational? is true for bigdecimals, including whole-number-valued ones")
    func rationalTrueForBigDecimals() throws {
        #expect(try swish.eval("(rational? 0.0M)") == .boolean(true))
        #expect(try swish.eval("(rational? 1.0M)") == .boolean(true))
        #expect(try swish.eval("(rational? -1.0M)") == .boolean(true))
    }

    @Test("rational? is true for ratios, including ones that reduce to a whole number")
    func rationalTrueForRatios() throws {
        #expect(try swish.eval("(rational? 0/2)") == .boolean(true))
        #expect(try swish.eval("(rational? 1/2)") == .boolean(true))
        #expect(try swish.eval("(rational? -1/2)") == .boolean(true))
    }

    @Test("rational? is false for doubles, Inf, and NaN")
    func rationalFalseForFloatingPoint() throws {
        #expect(try swish.eval("(rational? 0.0)") == .boolean(false))
        #expect(try swish.eval("(rational? 1.0)") == .boolean(false))
        #expect(try swish.eval("(rational? -1.0)") == .boolean(false))
        #expect(try swish.eval("(rational? ##Inf)") == .boolean(false))
        #expect(try swish.eval("(rational? ##-Inf)") == .boolean(false))
        #expect(try swish.eval("(rational? ##NaN)") == .boolean(false))
    }

    @Test("rational? is false for non-numeric types")
    func rationalFalseForNonNumeric() throws {
        #expect(try swish.eval("(rational? nil)") == .boolean(false))
        #expect(try swish.eval("(rational? true)") == .boolean(false))
        #expect(try swish.eval("(rational? false)") == .boolean(false))
        #expect(try swish.eval(#"(rational? "a string")"#) == .boolean(false))
        #expect(try swish.eval("(rational? {:a :map})") == .boolean(false))
        #expect(try swish.eval("(rational? #{:a-set})") == .boolean(false))
        #expect(try swish.eval("(rational? [:a :vector])") == .boolean(false))
        #expect(try swish.eval("(rational? '(:a :list))") == .boolean(false))
        #expect(try swish.eval(#"(rational? \0)"#) == .boolean(false))
        #expect(try swish.eval("(rational? :a-keyword)") == .boolean(false))
        #expect(try swish.eval("(rational? 'a-sym)") == .boolean(false))
    }
}

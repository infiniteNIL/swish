import Testing
import BigInt
import BigDecimal
@testable import SwishKit

@Suite("Parser BigInt / BigDecimal / Radix Tests")
struct ParserBigNumberTests {

    // MARK: - BigInteger literals

    @Test("Parses 42N as BigInt")
    func parseBigIntegerBasic() throws {
        let exprs = try Reader.readString("42N")
        #expect(exprs == [.bigInteger(BigInt(42))])
    }

    @Test("Parses -99N as negative BigInt")
    func parseBigIntegerNegative() throws {
        let exprs = try Reader.readString("-99N")
        #expect(exprs == [.bigInteger(BigInt(-99))])
    }

    @Test("Parses 0N as BigInt zero")
    func parseBigIntegerZero() throws {
        let exprs = try Reader.readString("0N")
        #expect(exprs == [.bigInteger(BigInt(0))])
    }

    @Test("Parses large BigInteger beyond Int64")
    func parseLargeBigInteger() throws {
        let big = "179769313486231570814527423731704356798070567525844996598917476803157260780028538760589558632766878171540458953514382464234321326889464182768467546703537516986049910576551282076245490090389328944075868508455133942304583236903222948165808559332123348274797826204144723168738177180919299881250404026184124858368"
        let exprs = try Reader.readString(big + "N")
        #expect(exprs.count == 1)
        if case .bigInteger(let v) = exprs[0] {
            #expect(String(v) == big)
        } else {
            Issue.record("Expected .bigInteger, got \(exprs[0])")
        }
    }

    @Test("Large decimal integer that overflows Int parses as BigInt")
    func parseOverflowingDecimalAsBigInt() throws {
        let exprs = try Reader.readString("99999999999999999999")
        let expected: BigInt = "99999999999999999999"
        #expect(exprs == [.bigInteger(expected)])
    }

    // MARK: - BigDecimal literals

    @Test("Parses 1.5M as BigDecimal")
    func parseBigDecimalFloat() throws {
        let exprs = try Reader.readString("1.5M")
        #expect(exprs.count == 1)
        if case .bigDecimal(let v) = exprs[0] {
            #expect(v == BigDecimal("1.5")!)
        } else {
            Issue.record("Expected .bigDecimal, got \(exprs[0])")
        }
    }

    @Test("Parses 42M as BigDecimal")
    func parseBigDecimalInteger() throws {
        let exprs = try Reader.readString("42M")
        #expect(exprs.count == 1)
        if case .bigDecimal = exprs[0] { } else {
            Issue.record("Expected .bigDecimal, got \(exprs[0])")
        }
    }

    @Test("Parses -3.14M as negative BigDecimal")
    func parseBigDecimalNegative() throws {
        let exprs = try Reader.readString("-3.14M")
        #expect(exprs.count == 1)
        if case .bigDecimal(let v) = exprs[0] {
            #expect(v == BigDecimal("-3.14")!)
        } else {
            Issue.record("Expected .bigDecimal, got \(exprs[0])")
        }
    }

    @Test("Parses 0.0M as BigDecimal zero")
    func parseBigDecimalZero() throws {
        let exprs = try Reader.readString("0.0M")
        #expect(exprs.count == 1)
        if case .bigDecimal(let v) = exprs[0] {
            #expect(v.isZero)
        } else {
            Issue.record("Expected .bigDecimal, got \(exprs[0])")
        }
    }

    // MARK: - Clojure radix notation

    @Test("Parses 2r1111 as 15")
    func parseBinaryRadix() throws {
        let exprs = try Reader.readString("2r1111")
        #expect(exprs == [.integer(15)])
    }

    @Test("Parses 8r177 as 127")
    func parseOctalRadix() throws {
        let exprs = try Reader.readString("8r177")
        #expect(exprs == [.integer(127)])
    }

    @Test("Parses 16rFF as 255")
    func parseHexRadix() throws {
        let exprs = try Reader.readString("16rFF")
        #expect(exprs == [.integer(255)])
    }

    @Test("Parses 16rff as 255 (lowercase)")
    func parseHexRadixLowercase() throws {
        let exprs = try Reader.readString("16rff")
        #expect(exprs == [.integer(255)])
    }

    @Test("Parses 36rZ as 35")
    func parseBase36Radix() throws {
        let exprs = try Reader.readString("36rZ")
        #expect(exprs == [.integer(35)])
    }

    @Test("Parses -2r1010 as -10")
    func parseNegativeRadix() throws {
        let exprs = try Reader.readString("-2r1010")
        #expect(exprs == [.integer(-10)])
    }

    @Test("Parses 2r0 as 0")
    func parseBinaryZeroRadix() throws {
        let exprs = try Reader.readString("2r0")
        #expect(exprs == [.integer(0)])
    }

    @Test("Parses 2r1111N as BigInt 15")
    func parseBinaryRadixBigInt() throws {
        let exprs = try Reader.readString("2r1111N")
        #expect(exprs == [.bigInteger(BigInt(15))])
    }

    @Test("Parses 10r1234567890 as BigInt")
    func parseBase10Radix() throws {
        let exprs = try Reader.readString("10r1234567890")
        #expect(exprs == [.integer(1234567890)])
    }

    // MARK: - Digit-starting keywords

    @Test("Parses :0 as keyword")
    func parseDigitKeyword0() throws {
        let exprs = try Reader.readString(":0")
        #expect(exprs == [.keyword("0")])
    }

    @Test("Parses :1 as keyword")
    func parseDigitKeyword1() throws {
        let exprs = try Reader.readString(":1")
        #expect(exprs == [.keyword("1")])
    }

    @Test("Parses :-1 as keyword")
    func parseDigitKeywordNeg1() throws {
        let exprs = try Reader.readString(":-1")
        #expect(exprs == [.keyword("-1")])
    }

    @Test("Parses digit keywords in a map")
    func parseDigitKeywordsInMap() throws {
        let exprs = try Reader.readString("{:0 \"zero\" :1 \"one\"}")
        #expect(exprs.count == 1)
        if case .map(let sm) = exprs[0] {
            #expect(sm.dict[.keyword("0")] == .string("zero"))
            #expect(sm.dict[.keyword("1")] == .string("one"))
        } else {
            Issue.record("Expected .map, got \(exprs[0])")
        }
    }
}

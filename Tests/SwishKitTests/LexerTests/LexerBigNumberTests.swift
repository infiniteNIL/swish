import Testing
@testable import SwishKit

@Suite("Lexer BigInt / BigDecimal / Radix Tests")
struct LexerBigNumberTests {

    // MARK: - BigInteger (N suffix)

    @Test("Scans basic BigInteger")
    func scanBasicBigInteger() throws {
        let lexer = Lexer("42N")
        let token = try lexer.nextToken()
        #expect(token.type == .bigInteger)
        #expect(token.text == "42")
    }

    @Test("Scans negative BigInteger")
    func scanNegativeBigInteger() throws {
        let lexer = Lexer("-99N")
        let token = try lexer.nextToken()
        #expect(token.type == .bigInteger)
        #expect(token.text == "-99")
    }

    @Test("Scans zero BigInteger")
    func scanZeroBigInteger() throws {
        let lexer = Lexer("0N")
        let token = try lexer.nextToken()
        #expect(token.type == .bigInteger)
        #expect(token.text == "0")
    }

    @Test("Scans large BigInteger that exceeds Int64")
    func scanLargeBigInteger() throws {
        let big = "179769313486231570814527423731704356798070567525844996598917476803157260780028538760589558632766878171540458953514382464234321326889464182768467546703537516986049910576551282076245490090389328944075868508455133942304583236903222948165808559332123348274797826204144723168738177180919299881250404026184124858368"
        let lexer = Lexer(big + "N")
        let token = try lexer.nextToken()
        #expect(token.type == .bigInteger)
        #expect(token.text == big)
    }

    @Test("Scans BigInteger with underscore separators")
    func scanBigIntegerWithUnderscores() throws {
        let lexer = Lexer("1_000N")
        let token = try lexer.nextToken()
        #expect(token.type == .bigInteger)
        #expect(token.text == "1000")
    }

    // MARK: - BigDecimal (M suffix)

    @Test("Scans basic BigDecimal")
    func scanBasicBigDecimal() throws {
        let lexer = Lexer("1.5M")
        let token = try lexer.nextToken()
        #expect(token.type == .bigDecimal)
        #expect(token.text == "1.5")
    }

    @Test("Scans negative BigDecimal")
    func scanNegativeBigDecimal() throws {
        let lexer = Lexer("-3.14M")
        let token = try lexer.nextToken()
        #expect(token.type == .bigDecimal)
        #expect(token.text == "-3.14")
    }

    @Test("Scans integer-valued BigDecimal")
    func scanIntegerValuedBigDecimal() throws {
        let lexer = Lexer("42M")
        let token = try lexer.nextToken()
        #expect(token.type == .bigDecimal)
        #expect(token.text == "42")
    }

    @Test("Scans zero BigDecimal")
    func scanZeroBigDecimal() throws {
        let lexer = Lexer("0.0M")
        let token = try lexer.nextToken()
        #expect(token.type == .bigDecimal)
        #expect(token.text == "0.0")
    }

    @Test("Scans BigDecimal with exponent")
    func scanBigDecimalWithExponent() throws {
        let lexer = Lexer("1.5e10M")
        let token = try lexer.nextToken()
        #expect(token.type == .bigDecimal)
        #expect(token.text == "1.5e10")
    }

    // MARK: - Clojure radix notation (NrDIGITS)

    @Test("Scans binary radix 2r1111")
    func scanBinaryRadix() throws {
        let lexer = Lexer("2r1111")
        let token = try lexer.nextToken()
        #expect(token.type == .integer)
        #expect(token.text == "2r1111")
    }

    @Test("Scans octal radix 8r177")
    func scanOctalRadix() throws {
        let lexer = Lexer("8r177")
        let token = try lexer.nextToken()
        #expect(token.type == .integer)
        #expect(token.text == "8r177")
    }

    @Test("Scans hex radix 16rFF")
    func scanHexRadix() throws {
        let lexer = Lexer("16rFF")
        let token = try lexer.nextToken()
        #expect(token.type == .integer)
        #expect(token.text == "16rFF")
    }

    @Test("Scans base-36 radix 36rZ")
    func scanBase36Radix() throws {
        let lexer = Lexer("36rZ")
        let token = try lexer.nextToken()
        #expect(token.type == .integer)
        #expect(token.text == "36rZ")
    }

    @Test("Scans negative radix -2r1010")
    func scanNegativeRadix() throws {
        let lexer = Lexer("-2r1010")
        let token = try lexer.nextToken()
        #expect(token.type == .integer)
        #expect(token.text == "-2r1010")
    }

    @Test("Scans radix with BigInteger suffix 2r1111N")
    func scanRadixBigInteger() throws {
        let lexer = Lexer("2r1111N")
        let token = try lexer.nextToken()
        #expect(token.type == .bigInteger)
        #expect(token.text == "2r1111")
    }

    @Test("Throws for radix with no digits after r")
    func radixNoDigitsThrows() throws {
        let lexer = Lexer("2r")
        #expect(throws: LexerError.invalidNumberFormat("2r", line: 1, column: 1)) {
            try lexer.nextToken()
        }
    }

    // MARK: - Digit-starting keywords

    @Test("Scans keyword starting with digit :0")
    func scanDigitKeyword0() throws {
        let lexer = Lexer(":0")
        let token = try lexer.nextToken()
        #expect(token.type == .keyword)
        #expect(token.text == "0")
    }

    @Test("Scans keyword starting with digit :1")
    func scanDigitKeyword1() throws {
        let lexer = Lexer(":1")
        let token = try lexer.nextToken()
        #expect(token.type == .keyword)
        #expect(token.text == "1")
    }

    @Test("Scans keyword :-1")
    func scanDigitKeywordNeg1() throws {
        let lexer = Lexer(":-1")
        let token = try lexer.nextToken()
        #expect(token.type == .keyword)
        #expect(token.text == "-1")
    }

    @Test("Scans keyword :42abc")
    func scanDigitKeywordMixed() throws {
        let lexer = Lexer(":42abc")
        let token = try lexer.nextToken()
        #expect(token.type == .keyword)
        #expect(token.text == "42abc")
    }
}

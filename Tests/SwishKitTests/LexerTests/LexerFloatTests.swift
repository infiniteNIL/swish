import Testing
@testable import SwishKit

@Suite("Lexer Float Tests")
struct LexerFloatTests {
    @Test("Scans basic float")
    func scanBasicFloat() throws {
        #expect(try Lexer("1.5").nextToken() == Token(type: .float, text: "1.5", line: 1, column: 1))
    }

    @Test("Scans float with zero integer part")
    func scanFloatWithZeroIntegerPart() throws {
        #expect(try Lexer("0.5").nextToken() == Token(type: .float, text: "0.5", line: 1, column: 1))
    }

    @Test("Scans float with zero fractional part")
    func scanFloatWithZeroFractionalPart() throws {
        #expect(try Lexer("123.0").nextToken() == Token(type: .float, text: "123.0", line: 1, column: 1))
    }

    @Test("Scans negative float")
    func scanNegativeFloat() throws {
        #expect(try Lexer("-3.14").nextToken() == Token(type: .float, text: "-3.14", line: 1, column: 1))
    }

    @Test("Scans positive float with plus sign")
    func scanPositiveFloat() throws {
        #expect(try Lexer("+3.14").nextToken() == Token(type: .float, text: "+3.14", line: 1, column: 1))
    }

    @Test("Scans float with exponent")
    func scanFloatWithExponent() throws {
        #expect(try Lexer("1.5e2").nextToken() == Token(type: .float, text: "1.5e2", line: 1, column: 1))
    }

    @Test("Scans float with uppercase exponent")
    func scanFloatWithUppercaseExponent() throws {
        #expect(try Lexer("1.5E2").nextToken() == Token(type: .float, text: "1.5E2", line: 1, column: 1))
    }

    @Test("Scans float with negative exponent")
    func scanFloatWithNegativeExponent() throws {
        #expect(try Lexer("1e-2").nextToken() == Token(type: .float, text: "1e-2", line: 1, column: 1))
    }

    @Test("Scans float with positive exponent sign")
    func scanFloatWithPositiveExponentSign() throws {
        #expect(try Lexer("1.5e+10").nextToken() == Token(type: .float, text: "1.5e+10", line: 1, column: 1))
    }

    @Test("Scans integer with exponent as float")
    func scanIntegerWithExponentAsFloat() throws {
        #expect(try Lexer("1e2").nextToken() == Token(type: .float, text: "1e2", line: 1, column: 1))
    }

    @Test("Scans float with underscores in integer part")
    func scanFloatWithUnderscoresInIntegerPart() throws {
        #expect(try Lexer("1_000.5").nextToken() == Token(type: .float, text: "1000.5", line: 1, column: 1))
    }

    @Test("Scans float with underscores in fractional part")
    func scanFloatWithUnderscoresInFractionalPart() throws {
        #expect(try Lexer("1.5_00").nextToken() == Token(type: .float, text: "1.500", line: 1, column: 1))
    }

    @Test("Scans float with underscores in exponent")
    func scanFloatWithUnderscoresInExponent() throws {
        #expect(try Lexer("1.5e1_0").nextToken() == Token(type: .float, text: "1.5e10", line: 1, column: 1))
    }

    @Test("Dot followed by digit lexes as a single symbol (.5 is a symbol, not a float)")
    func dotWithDigitLexesAsSymbol() throws {
        // In Clojure/EDN, floats require a leading digit; .5 is the symbol ".5"
        #expect(try Lexer(".5").nextToken() == Token(type: .symbol, text: ".5", line: 1, column: 1))
    }

    @Test("Trailing dot is a valid float (5. == 5.0)")
    func trailingDotIsFloat() throws {
        #expect(try Lexer("5.").nextToken() == Token(type: .float, text: "5.", line: 1, column: 1))
    }

    @Test("Exponent without digits is an error")
    func exponentWithoutDigitsIsError() throws {
        // 1e should be an error - 'e' is not a valid number terminator
        #expect(throws: LexerError.invalidNumberFormat("1e", line: 1, column: 1)) {
            try Lexer("1e").nextToken()
        }
    }

    @Test("Exponent with only sign is an error")
    func exponentWithOnlySignIsError() throws {
        // 1e- should be an error - 'e' is not a valid number terminator
        #expect(throws: LexerError.invalidNumberFormat("1e-", line: 1, column: 1)) {
            try Lexer("1e-").nextToken()
        }
    }

    @Test("Throws error for underscore adjacent to decimal point before")
    func underscoreBeforeDecimalThrows() throws {
        #expect(throws: LexerError.invalidNumberFormat("1_", line: 1, column: 1)) {
            try Lexer("1_.5").nextToken()
        }
    }

    @Test("Throws error for trailing underscore in fractional part")
    func trailingUnderscoreInFractionalPartThrows() throws {
        #expect(throws: LexerError.invalidNumberFormat("1.5_", line: 1, column: 1)) {
            try Lexer("1.5_").nextToken()
        }
    }

    @Test("Throws error for consecutive underscores in fractional part")
    func consecutiveUnderscoresInFractionalPartThrows() throws {
        #expect(throws: LexerError.invalidNumberFormat("1.5__", line: 1, column: 1)) {
            try Lexer("1.5__0").nextToken()
        }
    }

    @Test("Throws error for trailing underscore in exponent")
    func trailingUnderscoreInExponentThrows() throws {
        #expect(throws: LexerError.invalidNumberFormat("1e10_", line: 1, column: 1)) {
            try Lexer("1e10_").nextToken()
        }
    }

    @Test("Throws error for leading underscore in exponent")
    func leadingUnderscoreInExponentThrows() throws {
        // 1e_10 should be an error - 'e' is not a valid number terminator
        #expect(throws: LexerError.invalidNumberFormat("1e_10", line: 1, column: 1)) {
            try Lexer("1e_10").nextToken()
        }
    }

    @Test("Scans multiple floats")
    func scanMultipleFloats() throws {
        let lexer = Lexer("1.5 2.5 3.5")
        #expect(try lexer.nextToken() == Token(type: .float, text: "1.5", line: 1, column: 1))
        #expect(try lexer.nextToken() == Token(type: .float, text: "2.5", line: 1, column: 5))
        #expect(try lexer.nextToken() == Token(type: .float, text: "3.5", line: 1, column: 9))
        #expect(try lexer.nextToken().type == .eof)
    }
}

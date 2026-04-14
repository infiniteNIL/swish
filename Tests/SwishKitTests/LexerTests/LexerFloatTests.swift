import Testing
@testable import SwishKit

@Suite("Lexer Float Tests")
struct LexerFloatTests {
    @Test("Scans basic float")
    func scanBasicFloat() throws {
        let lexer = Lexer("1.5")
        let token = try lexer.nextToken()
        #expect(token.type == .float)
        #expect(token.text == "1.5")
    }

    @Test("Scans float with zero integer part")
    func scanFloatWithZeroIntegerPart() throws {
        let lexer = Lexer("0.5")
        let token = try lexer.nextToken()
        #expect(token.type == .float)
        #expect(token.text == "0.5")
    }

    @Test("Scans float with zero fractional part")
    func scanFloatWithZeroFractionalPart() throws {
        let lexer = Lexer("123.0")
        let token = try lexer.nextToken()
        #expect(token.type == .float)
        #expect(token.text == "123.0")
    }

    @Test("Scans negative float")
    func scanNegativeFloat() throws {
        let lexer = Lexer("-3.14")
        let token = try lexer.nextToken()
        #expect(token.type == .float)
        #expect(token.text == "-3.14")
    }

    @Test("Scans positive float with plus sign")
    func scanPositiveFloat() throws {
        let lexer = Lexer("+3.14")
        let token = try lexer.nextToken()
        #expect(token.type == .float)
        #expect(token.text == "+3.14")
    }

    @Test("Scans float with exponent")
    func scanFloatWithExponent() throws {
        let lexer = Lexer("1.5e2")
        let token = try lexer.nextToken()
        #expect(token.type == .float)
        #expect(token.text == "1.5e2")
    }

    @Test("Scans float with uppercase exponent")
    func scanFloatWithUppercaseExponent() throws {
        let lexer = Lexer("1.5E2")
        let token = try lexer.nextToken()
        #expect(token.type == .float)
        #expect(token.text == "1.5E2")
    }

    @Test("Scans float with negative exponent")
    func scanFloatWithNegativeExponent() throws {
        let lexer = Lexer("1e-2")
        let token = try lexer.nextToken()
        #expect(token.type == .float)
        #expect(token.text == "1e-2")
    }

    @Test("Scans float with positive exponent sign")
    func scanFloatWithPositiveExponentSign() throws {
        let lexer = Lexer("1.5e+10")
        let token = try lexer.nextToken()
        #expect(token.type == .float)
        #expect(token.text == "1.5e+10")
    }

    @Test("Scans integer with exponent as float")
    func scanIntegerWithExponentAsFloat() throws {
        let lexer = Lexer("1e2")
        let token = try lexer.nextToken()
        #expect(token.type == .float)
        #expect(token.text == "1e2")
    }

    @Test("Scans float with underscores in integer part")
    func scanFloatWithUnderscoresInIntegerPart() throws {
        let lexer = Lexer("1_000.5")
        let token = try lexer.nextToken()
        #expect(token.type == .float)
        #expect(token.text == "1000.5")
    }

    @Test("Scans float with underscores in fractional part")
    func scanFloatWithUnderscoresInFractionalPart() throws {
        let lexer = Lexer("1.5_00")
        let token = try lexer.nextToken()
        #expect(token.type == .float)
        #expect(token.text == "1.500")
    }

    @Test("Scans float with underscores in exponent")
    func scanFloatWithUnderscoresInExponent() throws {
        let lexer = Lexer("1.5e1_0")
        let token = try lexer.nextToken()
        #expect(token.type == .float)
        #expect(token.text == "1.5e10")
    }

    @Test("Dot without leading digit is not a float")
    func dotWithoutLeadingDigitNotFloat() throws {
        // .5 should be lexed as illegal character '.'
        let lexer = Lexer(".5")
        #expect(throws: LexerError.illegalCharacter(".", line: 1, column: 1)) {
            try lexer.nextToken()
        }
    }

    @Test("Trailing dot without digit is not a float")
    func trailingDotWithoutDigitNotFloat() throws {
        // 5. should be an error - '.' is not a valid number terminator
        let lexer = Lexer("5.")
        #expect(throws: LexerError.invalidNumberFormat("5.", line: 1, column: 1)) {
            try lexer.nextToken()
        }
    }

    @Test("Exponent without digits is an error")
    func exponentWithoutDigitsIsError() throws {
        // 1e should be an error - 'e' is not a valid number terminator
        let lexer = Lexer("1e")
        #expect(throws: LexerError.invalidNumberFormat("1e", line: 1, column: 1)) {
            try lexer.nextToken()
        }
    }

    @Test("Exponent with only sign is an error")
    func exponentWithOnlySignIsError() throws {
        // 1e- should be an error - 'e' is not a valid number terminator
        let lexer = Lexer("1e-")
        #expect(throws: LexerError.invalidNumberFormat("1e-", line: 1, column: 1)) {
            try lexer.nextToken()
        }
    }

    @Test("Throws error for underscore adjacent to decimal point before")
    func underscoreBeforeDecimalThrows() throws {
        let lexer = Lexer("1_.5")
        #expect(throws: LexerError.invalidNumberFormat("1_", line: 1, column: 1)) {
            try lexer.nextToken()
        }
    }

    @Test("Throws error for trailing underscore in fractional part")
    func trailingUnderscoreInFractionalPartThrows() throws {
        let lexer = Lexer("1.5_")
        #expect(throws: LexerError.invalidNumberFormat("1.5_", line: 1, column: 1)) {
            try lexer.nextToken()
        }
    }

    @Test("Throws error for consecutive underscores in fractional part")
    func consecutiveUnderscoresInFractionalPartThrows() throws {
        let lexer = Lexer("1.5__0")
        #expect(throws: LexerError.invalidNumberFormat("1.5__", line: 1, column: 1)) {
            try lexer.nextToken()
        }
    }

    @Test("Throws error for trailing underscore in exponent")
    func trailingUnderscoreInExponentThrows() throws {
        let lexer = Lexer("1e10_")
        #expect(throws: LexerError.invalidNumberFormat("1e10_", line: 1, column: 1)) {
            try lexer.nextToken()
        }
    }

    @Test("Throws error for leading underscore in exponent")
    func leadingUnderscoreInExponentThrows() throws {
        // 1e_10 should be an error - 'e' is not a valid number terminator
        let lexer = Lexer("1e_10")
        #expect(throws: LexerError.invalidNumberFormat("1e_10", line: 1, column: 1)) {
            try lexer.nextToken()
        }
    }

    @Test("Scans multiple floats")
    func scanMultipleFloats() throws {
        let lexer = Lexer("1.5 2.5 3.5")

        let token1 = try lexer.nextToken()
        #expect(token1.type == .float)
        #expect(token1.text == "1.5")

        let token2 = try lexer.nextToken()
        #expect(token2.type == .float)
        #expect(token2.text == "2.5")

        let token3 = try lexer.nextToken()
        #expect(token3.type == .float)
        #expect(token3.text == "3.5")

        let eofToken = try lexer.nextToken()
        #expect(eofToken.type == .eof)
    }
}

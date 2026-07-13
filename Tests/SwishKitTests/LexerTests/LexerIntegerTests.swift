import Testing
@testable import SwishKit

@Suite("Lexer Integer Tests")
struct LexerIntegerTests {
    @Test("Scans single integer")
    func scanSingleInteger() throws {
        #expect(try Lexer("42").nextToken() == Token(type: .integer, text: "42", line: 1, column: 1))
    }

    @Test("Scans negative integer")
    func scanNegativeInteger() throws {
        #expect(try Lexer("-17").nextToken() == Token(type: .integer, text: "-17", line: 1, column: 1))
    }

    @Test("Scans positive integer with plus sign")
    func scanPositiveInteger() throws {
        #expect(try Lexer("+5").nextToken() == Token(type: .integer, text: "+5", line: 1, column: 1))
    }

    @Test("Scans zero")
    func scanZero() throws {
        #expect(try Lexer("0").nextToken() == Token(type: .integer, text: "0", line: 1, column: 1))
    }

    @Test("Scans negative zero")
    func scanNegativeZero() throws {
        #expect(try Lexer("-0").nextToken() == Token(type: .integer, text: "-0", line: 1, column: 1))
    }

    @Test("Scans integer with leading whitespace")
    func scanWithLeadingWhitespace() throws {
        #expect(try Lexer("  123").nextToken() == Token(type: .integer, text: "123", line: 1, column: 3))
    }

    @Test("Scans integer with trailing whitespace then EOF")
    func scanWithTrailingWhitespace() throws {
        let lexer = Lexer("123  ")
        #expect(try lexer.nextToken() == Token(type: .integer, text: "123", line: 1, column: 1))
        #expect(try lexer.nextToken().type == .eof)
    }

    @Test("Returns EOF for empty string")
    func emptyStringReturnsEof() throws {
        #expect(try Lexer("").nextToken() == Token(type: .eof, text: "", line: 1, column: 1))
    }

    @Test("Returns EOF for whitespace-only string")
    func whitespaceOnlyReturnsEof() throws {
        #expect(try Lexer("   \n\t  ").nextToken().type == .eof)
    }

    @Test("Throws error for illegal character")
    func illegalCharacterThrows() throws {
        #expect(throws: LexerError.illegalCharacter("¡", line: 1, column: 1)) {
            try Lexer("¡").nextToken()
        }
    }

    // MARK: - Underscore digit separators

    @Test("Scans integer with underscore separators")
    func scanIntegerWithUnderscores() throws {
        #expect(try Lexer("1_000").nextToken() == Token(type: .integer, text: "1000", line: 1, column: 1))
    }

    @Test("Scans integer with multiple underscore groups")
    func scanIntegerWithMultipleUnderscoreGroups() throws {
        #expect(try Lexer("1_000_000").nextToken() == Token(type: .integer, text: "1000000", line: 1, column: 1))
    }

    @Test("Scans negative integer with underscores")
    func scanNegativeIntegerWithUnderscores() throws {
        #expect(try Lexer("-1_000").nextToken() == Token(type: .integer, text: "-1000", line: 1, column: 1))
    }

    @Test("Scans positive integer with underscores")
    func scanPositiveIntegerWithUnderscores() throws {
        #expect(try Lexer("+1_000").nextToken() == Token(type: .integer, text: "+1000", line: 1, column: 1))
    }

    @Test("Scans integer with arbitrary underscore placement")
    func scanIntegerWithArbitraryUnderscores() throws {
        #expect(try Lexer("1_2_3").nextToken() == Token(type: .integer, text: "123", line: 1, column: 1))
    }

    @Test("Throws error for trailing underscore")
    func trailingUnderscoreThrows() throws {
        #expect(throws: LexerError.invalidNumberFormat("100_", line: 1, column: 1)) {
            try Lexer("100_").nextToken()
        }
    }

    @Test("Throws error for consecutive underscores")
    func consecutiveUnderscoresThrows() throws {
        #expect(throws: LexerError.invalidNumberFormat("1__", line: 1, column: 1)) {
            try Lexer("1__000").nextToken()
        }
    }

    // MARK: - Hexadecimal integer literals

    @Test("Scans basic hex integer")
    func scanBasicHex() throws {
        #expect(try Lexer("0xFF").nextToken() == Token(type: .integer, text: "0xFF", line: 1, column: 1))
    }

    @Test("Scans hex with lowercase digits")
    func scanHexLowercase() throws {
        #expect(try Lexer("0xab").nextToken() == Token(type: .integer, text: "0xab", line: 1, column: 1))
    }

    @Test("Scans hex with mixed case digits")
    func scanHexMixedCase() throws {
        #expect(try Lexer("0xAbCd").nextToken() == Token(type: .integer, text: "0xAbCd", line: 1, column: 1))
    }

    @Test("Scans hex zero")
    func scanHexZero() throws {
        #expect(try Lexer("0x0").nextToken() == Token(type: .integer, text: "0x0", line: 1, column: 1))
    }

    @Test("Scans negative hex integer")
    func scanNegativeHex() throws {
        #expect(try Lexer("-0xFF").nextToken() == Token(type: .integer, text: "-0xFF", line: 1, column: 1))
    }

    @Test("Scans positive hex integer with plus sign")
    func scanPositiveHex() throws {
        #expect(try Lexer("+0x10").nextToken() == Token(type: .integer, text: "+0x10", line: 1, column: 1))
    }

    @Test("Scans hex with underscore separators")
    func scanHexWithUnderscores() throws {
        #expect(try Lexer("0x1_000").nextToken() == Token(type: .integer, text: "0x1000", line: 1, column: 1))
    }

    @Test("Scans hex with multiple underscore groups")
    func scanHexWithMultipleUnderscores() throws {
        #expect(try Lexer("0xFF_FF").nextToken() == Token(type: .integer, text: "0xFFFF", line: 1, column: 1))
    }

    @Test("Throws error for hex with no digits")
    func hexNoDigitsThrows() throws {
        #expect(throws: LexerError.invalidNumberFormat("0x", line: 1, column: 1)) {
            try Lexer("0x").nextToken()
        }
    }

    @Test("Throws error for hex with leading underscore")
    func hexLeadingUnderscoreThrows() throws {
        #expect(throws: LexerError.invalidNumberFormat("0x_", line: 1, column: 1)) {
            try Lexer("0x_FF").nextToken()
        }
    }

    @Test("Throws error for hex with trailing underscore")
    func hexTrailingUnderscoreThrows() throws {
        #expect(throws: LexerError.invalidNumberFormat("0xFF_", line: 1, column: 1)) {
            try Lexer("0xFF_").nextToken()
        }
    }

    @Test("Throws error for hex with consecutive underscores")
    func hexConsecutiveUnderscoresThrows() throws {
        #expect(throws: LexerError.invalidNumberFormat("0xF__", line: 1, column: 1)) {
            try Lexer("0xF__F").nextToken()
        }
    }

    @Test("Uppercase X prefix is valid hex (0XFF = 255)")
    func uppercasePrefixHex() throws {
        #expect(try Lexer("0XFF").nextToken() == Token(type: .integer, text: "0XFF", line: 1, column: 1))
    }

    // MARK: - Binary integer literals

    @Test("Scans basic binary integer")
    func scanBasicBinary() throws {
        #expect(try Lexer("0b1010").nextToken() == Token(type: .integer, text: "0b1010", line: 1, column: 1))
    }

    @Test("Scans binary zero")
    func scanBinaryZero() throws {
        #expect(try Lexer("0b0").nextToken() == Token(type: .integer, text: "0b0", line: 1, column: 1))
    }

    @Test("Scans binary one")
    func scanBinaryOne() throws {
        #expect(try Lexer("0b1").nextToken() == Token(type: .integer, text: "0b1", line: 1, column: 1))
    }

    @Test("Scans negative binary integer")
    func scanNegativeBinary() throws {
        #expect(try Lexer("-0b1010").nextToken() == Token(type: .integer, text: "-0b1010", line: 1, column: 1))
    }

    @Test("Scans positive binary integer with plus sign")
    func scanPositiveBinary() throws {
        #expect(try Lexer("+0b100").nextToken() == Token(type: .integer, text: "+0b100", line: 1, column: 1))
    }

    @Test("Scans binary with underscore separators")
    func scanBinaryWithUnderscores() throws {
        #expect(try Lexer("0b1111_0000").nextToken() == Token(type: .integer, text: "0b11110000", line: 1, column: 1))
    }

    @Test("Scans binary with multiple underscore groups")
    func scanBinaryWithMultipleUnderscores() throws {
        #expect(try Lexer("0b1_0_1_0").nextToken() == Token(type: .integer, text: "0b1010", line: 1, column: 1))
    }

    @Test("Throws error for binary with no digits")
    func binaryNoDigitsThrows() throws {
        #expect(throws: LexerError.invalidNumberFormat("0b", line: 1, column: 1)) {
            try Lexer("0b").nextToken()
        }
    }

    @Test("Throws error for binary with leading underscore")
    func binaryLeadingUnderscoreThrows() throws {
        #expect(throws: LexerError.invalidNumberFormat("0b_", line: 1, column: 1)) {
            try Lexer("0b_1").nextToken()
        }
    }

    @Test("Throws error for binary with trailing underscore")
    func binaryTrailingUnderscoreThrows() throws {
        #expect(throws: LexerError.invalidNumberFormat("0b1_", line: 1, column: 1)) {
            try Lexer("0b1_").nextToken()
        }
    }

    @Test("Throws error for binary with consecutive underscores")
    func binaryConsecutiveUnderscoresThrows() throws {
        #expect(throws: LexerError.invalidNumberFormat("0b1__", line: 1, column: 1)) {
            try Lexer("0b1__0").nextToken()
        }
    }

    @Test("Throws error for binary with invalid digit")
    func binaryInvalidDigitThrows() throws {
        // 0b2 should be lexed as 0b with no valid digits
        #expect(throws: LexerError.invalidNumberFormat("0b", line: 1, column: 1)) {
            try Lexer("0b2").nextToken()
        }
    }

    @Test("Uppercase prefix is not recognized as binary")
    func uppercasePrefixNotBinary() throws {
        // 0B1010 should be an error - 'B' is not a valid number terminator
        #expect(throws: LexerError.invalidNumberFormat("0B1010", line: 1, column: 1)) {
            try Lexer("0B1010").nextToken()
        }
    }

    // MARK: - Octal integer literals

    @Test("Scans basic octal integer")
    func scanBasicOctal() throws {
        #expect(try Lexer("0o700").nextToken() == Token(type: .integer, text: "0o700", line: 1, column: 1))
    }

    @Test("Scans octal zero")
    func scanOctalZero() throws {
        #expect(try Lexer("0o0").nextToken() == Token(type: .integer, text: "0o0", line: 1, column: 1))
    }

    @Test("Scans short octal")
    func scanShortOctal() throws {
        #expect(try Lexer("0o7").nextToken() == Token(type: .integer, text: "0o7", line: 1, column: 1))
    }

    @Test("Scans negative octal integer")
    func scanNegativeOctal() throws {
        #expect(try Lexer("-0o700").nextToken() == Token(type: .integer, text: "-0o700", line: 1, column: 1))
    }

    @Test("Scans positive octal integer with plus sign")
    func scanPositiveOctal() throws {
        #expect(try Lexer("+0o755").nextToken() == Token(type: .integer, text: "+0o755", line: 1, column: 1))
    }

    @Test("Scans octal with underscore separators")
    func scanOctalWithUnderscores() throws {
        #expect(try Lexer("0o7_55").nextToken() == Token(type: .integer, text: "0o755", line: 1, column: 1))
    }

    @Test("Throws error for octal with no digits")
    func octalNoDigitsThrows() throws {
        #expect(throws: LexerError.invalidNumberFormat("0o", line: 1, column: 1)) {
            try Lexer("0o").nextToken()
        }
    }

    @Test("Throws error for octal with leading underscore")
    func octalLeadingUnderscoreThrows() throws {
        #expect(throws: LexerError.invalidNumberFormat("0o_", line: 1, column: 1)) {
            try Lexer("0o_7").nextToken()
        }
    }

    @Test("Throws error for octal with trailing underscore")
    func octalTrailingUnderscoreThrows() throws {
        #expect(throws: LexerError.invalidNumberFormat("0o7_", line: 1, column: 1)) {
            try Lexer("0o7_").nextToken()
        }
    }

    @Test("Throws error for octal with consecutive underscores")
    func octalConsecutiveUnderscoresThrows() throws {
        #expect(throws: LexerError.invalidNumberFormat("0o7__", line: 1, column: 1)) {
            try Lexer("0o7__5").nextToken()
        }
    }

    @Test("Throws error for octal with invalid digit")
    func octalInvalidDigitThrows() throws {
        // 0o8 should be lexed as 0o with no valid digits
        #expect(throws: LexerError.invalidNumberFormat("0o", line: 1, column: 1)) {
            try Lexer("0o8").nextToken()
        }
    }

    @Test("Uppercase prefix is not recognized as octal")
    func uppercasePrefixNotOctal() throws {
        // 0O7 should be an error - 'O' is not a valid number terminator
        #expect(throws: LexerError.invalidNumberFormat("0O7", line: 1, column: 1)) {
            try Lexer("0O7").nextToken()
        }
    }

    // MARK: - Clojure-style octal integers (leading zero)

    @Test("Leading zero scans as octal: 0700 = 448")
    func scanLeadingZeroOctal() throws {
        #expect(try Lexer("0700").nextToken() == Token(type: .integer, text: "0o700", line: 1, column: 1))
    }

    @Test("Throws for invalid octal digit after leading zero: 08")
    func scanLeadingZero08Throws() throws {
        #expect(throws: (any Error).self) { try Lexer("08").nextToken() }
    }

    @Test("Leading zero with double zero scans as octal 0: 00")
    func scanLeadingZero00() throws {
        #expect(try Lexer("00").nextToken() == Token(type: .integer, text: "0o0", line: 1, column: 1))
    }

    @Test("Plain zero is still valid")
    func plainZeroStillValid() throws {
        #expect(try Lexer("0").nextToken() == Token(type: .integer, text: "0", line: 1, column: 1))
    }

    @Test("Uppercase R radix notation: 8R52 = 42")
    func uppercaseRRadix() throws {
        #expect(try Lexer("8R52").nextToken() == Token(type: .integer, text: "8R52", line: 1, column: 1))
    }

    @Test("Uppercase X hex notation: -0X2a = -42")
    func uppercaseXHex() throws {
        #expect(try Lexer("-0X2a").nextToken() == Token(type: .integer, text: "-0X2a", line: 1, column: 1))
    }
}

import Testing
@testable import SwishKit

@Suite("Lexer Tests")
struct LexerTests {
    @Test("Scans single integer")
    func scanSingleInteger() throws {
        let lexer = Lexer("42")
        let token = try lexer.nextToken()
        #expect(token.type == .integer)
        #expect(token.text == "42")
        #expect(token.line == 1)
        #expect(token.column == 1)
    }

    @Test("Scans negative integer")
    func scanNegativeInteger() throws {
        let lexer = Lexer("-17")
        let token = try lexer.nextToken()
        #expect(token.type == .integer)
        #expect(token.text == "-17")
        #expect(token.line == 1)
        #expect(token.column == 1)
    }

    @Test("Scans positive integer with plus sign")
    func scanPositiveInteger() throws {
        let lexer = Lexer("+5")
        let token = try lexer.nextToken()
        #expect(token.type == .integer)
        #expect(token.text == "+5")
        #expect(token.line == 1)
        #expect(token.column == 1)
    }

    @Test("Scans zero")
    func scanZero() throws {
        let lexer = Lexer("0")
        let token = try lexer.nextToken()
        #expect(token.type == .integer)
        #expect(token.text == "0")
    }

    @Test("Scans negative zero")
    func scanNegativeZero() throws {
        let lexer = Lexer("-0")
        let token = try lexer.nextToken()
        #expect(token.type == .integer)
        #expect(token.text == "-0")
    }

    @Test("Scans integer with leading whitespace")
    func scanWithLeadingWhitespace() throws {
        let lexer = Lexer("  123")
        let token = try lexer.nextToken()
        #expect(token.type == .integer)
        #expect(token.text == "123")
        #expect(token.column == 3)
    }

    @Test("Scans integer with trailing whitespace then EOF")
    func scanWithTrailingWhitespace() throws {
        let lexer = Lexer("123  ")
        let intToken = try lexer.nextToken()
        #expect(intToken.type == .integer)
        #expect(intToken.text == "123")

        let eofToken = try lexer.nextToken()
        #expect(eofToken.type == .eof)
    }

    @Test("Returns EOF for empty string")
    func emptyStringReturnsEof() throws {
        let lexer = Lexer("")
        let token = try lexer.nextToken()
        #expect(token.type == .eof)
        #expect(token.text == "")
        #expect(token.line == 1)
        #expect(token.column == 1)
    }

    @Test("Returns EOF for whitespace-only string")
    func whitespaceOnlyReturnsEof() throws {
        let lexer = Lexer("   \n\t  ")
        let token = try lexer.nextToken()
        #expect(token.type == .eof)
    }

    @Test("Throws error for illegal character")
    func illegalCharacterThrows() throws {
        let lexer = Lexer("abc")
        #expect(throws: LexerError.illegalCharacter("a", line: 1, column: 1)) {
            try lexer.nextToken()
        }
    }

    @Test("Throws error for lone plus sign")
    func lonePlusSignThrows() throws {
        let lexer = Lexer("+")
        #expect(throws: LexerError.illegalCharacter("+", line: 1, column: 1)) {
            try lexer.nextToken()
        }
    }

    @Test("Throws error for lone minus sign")
    func loneMinusSignThrows() throws {
        let lexer = Lexer("-")
        #expect(throws: LexerError.illegalCharacter("-", line: 1, column: 1)) {
            try lexer.nextToken()
        }
    }

    @Test("Throws error for sign followed by non-digit")
    func signFollowedByNonDigitThrows() throws {
        let lexer = Lexer("-abc")
        #expect(throws: LexerError.illegalCharacter("-", line: 1, column: 1)) {
            try lexer.nextToken()
        }
    }

    @Test("Tracks line and column across newlines")
    func positionTrackingAcrossNewlines() throws {
        let lexer = Lexer("\n\n  42")
        let token = try lexer.nextToken()
        #expect(token.type == .integer)
        #expect(token.text == "42")
        #expect(token.line == 3)
        #expect(token.column == 3)
    }

    @Test("Scans multiple integers")
    func scanMultipleIntegers() throws {
        let lexer = Lexer("1 2 3")

        let token1 = try lexer.nextToken()
        #expect(token1.type == .integer)
        #expect(token1.text == "1")
        #expect(token1.column == 1)

        let token2 = try lexer.nextToken()
        #expect(token2.type == .integer)
        #expect(token2.text == "2")
        #expect(token2.column == 3)

        let token3 = try lexer.nextToken()
        #expect(token3.type == .integer)
        #expect(token3.text == "3")
        #expect(token3.column == 5)

        let eofToken = try lexer.nextToken()
        #expect(eofToken.type == .eof)
    }

    // MARK: - Underscore digit separators

    @Test("Scans integer with underscore separators")
    func scanIntegerWithUnderscores() throws {
        let lexer = Lexer("1_000")
        let token = try lexer.nextToken()
        #expect(token.type == .integer)
        #expect(token.text == "1000")
    }

    @Test("Scans integer with multiple underscore groups")
    func scanIntegerWithMultipleUnderscoreGroups() throws {
        let lexer = Lexer("1_000_000")
        let token = try lexer.nextToken()
        #expect(token.type == .integer)
        #expect(token.text == "1000000")
    }

    @Test("Scans negative integer with underscores")
    func scanNegativeIntegerWithUnderscores() throws {
        let lexer = Lexer("-1_000")
        let token = try lexer.nextToken()
        #expect(token.type == .integer)
        #expect(token.text == "-1000")
    }

    @Test("Scans positive integer with underscores")
    func scanPositiveIntegerWithUnderscores() throws {
        let lexer = Lexer("+1_000")
        let token = try lexer.nextToken()
        #expect(token.type == .integer)
        #expect(token.text == "+1000")
    }

    @Test("Scans integer with arbitrary underscore placement")
    func scanIntegerWithArbitraryUnderscores() throws {
        let lexer = Lexer("1_2_3")
        let token = try lexer.nextToken()
        #expect(token.type == .integer)
        #expect(token.text == "123")
    }

    @Test("Throws error for trailing underscore")
    func trailingUnderscoreThrows() throws {
        let lexer = Lexer("100_")
        #expect(throws: LexerError.invalidNumberFormat("100_", line: 1, column: 1)) {
            try lexer.nextToken()
        }
    }

    @Test("Throws error for consecutive underscores")
    func consecutiveUnderscoresThrows() throws {
        let lexer = Lexer("1__000")
        #expect(throws: LexerError.invalidNumberFormat("1__", line: 1, column: 1)) {
            try lexer.nextToken()
        }
    }

    // MARK: - Hexadecimal integer literals

    @Test("Scans basic hex integer")
    func scanBasicHex() throws {
        let lexer = Lexer("0xFF")
        let token = try lexer.nextToken()
        #expect(token.type == .integer)
        #expect(token.text == "0xFF")
    }

    @Test("Scans hex with lowercase digits")
    func scanHexLowercase() throws {
        let lexer = Lexer("0xab")
        let token = try lexer.nextToken()
        #expect(token.type == .integer)
        #expect(token.text == "0xab")
    }

    @Test("Scans hex with mixed case digits")
    func scanHexMixedCase() throws {
        let lexer = Lexer("0xAbCd")
        let token = try lexer.nextToken()
        #expect(token.type == .integer)
        #expect(token.text == "0xAbCd")
    }

    @Test("Scans hex zero")
    func scanHexZero() throws {
        let lexer = Lexer("0x0")
        let token = try lexer.nextToken()
        #expect(token.type == .integer)
        #expect(token.text == "0x0")
    }

    @Test("Scans negative hex integer")
    func scanNegativeHex() throws {
        let lexer = Lexer("-0xFF")
        let token = try lexer.nextToken()
        #expect(token.type == .integer)
        #expect(token.text == "-0xFF")
    }

    @Test("Scans positive hex integer with plus sign")
    func scanPositiveHex() throws {
        let lexer = Lexer("+0x10")
        let token = try lexer.nextToken()
        #expect(token.type == .integer)
        #expect(token.text == "+0x10")
    }

    @Test("Scans hex with underscore separators")
    func scanHexWithUnderscores() throws {
        let lexer = Lexer("0x1_000")
        let token = try lexer.nextToken()
        #expect(token.type == .integer)
        #expect(token.text == "0x1000")
    }

    @Test("Scans hex with multiple underscore groups")
    func scanHexWithMultipleUnderscores() throws {
        let lexer = Lexer("0xFF_FF")
        let token = try lexer.nextToken()
        #expect(token.type == .integer)
        #expect(token.text == "0xFFFF")
    }

    @Test("Throws error for hex with no digits")
    func hexNoDigitsThrows() throws {
        let lexer = Lexer("0x")
        #expect(throws: LexerError.invalidNumberFormat("0x", line: 1, column: 1)) {
            try lexer.nextToken()
        }
    }

    @Test("Throws error for hex with leading underscore")
    func hexLeadingUnderscoreThrows() throws {
        let lexer = Lexer("0x_FF")
        #expect(throws: LexerError.invalidNumberFormat("0x_", line: 1, column: 1)) {
            try lexer.nextToken()
        }
    }

    @Test("Throws error for hex with trailing underscore")
    func hexTrailingUnderscoreThrows() throws {
        let lexer = Lexer("0xFF_")
        #expect(throws: LexerError.invalidNumberFormat("0xFF_", line: 1, column: 1)) {
            try lexer.nextToken()
        }
    }

    @Test("Throws error for hex with consecutive underscores")
    func hexConsecutiveUnderscoresThrows() throws {
        let lexer = Lexer("0xF__F")
        #expect(throws: LexerError.invalidNumberFormat("0xF__", line: 1, column: 1)) {
            try lexer.nextToken()
        }
    }

    @Test("Uppercase prefix is not recognized as hex")
    func uppercasePrefixNotHex() throws {
        // 0XFF should be lexed as 0 followed by illegal character X
        let lexer = Lexer("0XFF")
        let token = try lexer.nextToken()
        #expect(token.type == .integer)
        #expect(token.text == "0")

        #expect(throws: LexerError.illegalCharacter("X", line: 1, column: 2)) {
            try lexer.nextToken()
        }
    }

    // MARK: - Binary integer literals

    @Test("Scans basic binary integer")
    func scanBasicBinary() throws {
        let lexer = Lexer("0b1010")
        let token = try lexer.nextToken()
        #expect(token.type == .integer)
        #expect(token.text == "0b1010")
    }

    @Test("Scans binary zero")
    func scanBinaryZero() throws {
        let lexer = Lexer("0b0")
        let token = try lexer.nextToken()
        #expect(token.type == .integer)
        #expect(token.text == "0b0")
    }

    @Test("Scans binary one")
    func scanBinaryOne() throws {
        let lexer = Lexer("0b1")
        let token = try lexer.nextToken()
        #expect(token.type == .integer)
        #expect(token.text == "0b1")
    }

    @Test("Scans negative binary integer")
    func scanNegativeBinary() throws {
        let lexer = Lexer("-0b1010")
        let token = try lexer.nextToken()
        #expect(token.type == .integer)
        #expect(token.text == "-0b1010")
    }

    @Test("Scans positive binary integer with plus sign")
    func scanPositiveBinary() throws {
        let lexer = Lexer("+0b100")
        let token = try lexer.nextToken()
        #expect(token.type == .integer)
        #expect(token.text == "+0b100")
    }

    @Test("Scans binary with underscore separators")
    func scanBinaryWithUnderscores() throws {
        let lexer = Lexer("0b1111_0000")
        let token = try lexer.nextToken()
        #expect(token.type == .integer)
        #expect(token.text == "0b11110000")
    }

    @Test("Scans binary with multiple underscore groups")
    func scanBinaryWithMultipleUnderscores() throws {
        let lexer = Lexer("0b1_0_1_0")
        let token = try lexer.nextToken()
        #expect(token.type == .integer)
        #expect(token.text == "0b1010")
    }

    @Test("Throws error for binary with no digits")
    func binaryNoDigitsThrows() throws {
        let lexer = Lexer("0b")
        #expect(throws: LexerError.invalidNumberFormat("0b", line: 1, column: 1)) {
            try lexer.nextToken()
        }
    }

    @Test("Throws error for binary with leading underscore")
    func binaryLeadingUnderscoreThrows() throws {
        let lexer = Lexer("0b_1")
        #expect(throws: LexerError.invalidNumberFormat("0b_", line: 1, column: 1)) {
            try lexer.nextToken()
        }
    }

    @Test("Throws error for binary with trailing underscore")
    func binaryTrailingUnderscoreThrows() throws {
        let lexer = Lexer("0b1_")
        #expect(throws: LexerError.invalidNumberFormat("0b1_", line: 1, column: 1)) {
            try lexer.nextToken()
        }
    }

    @Test("Throws error for binary with consecutive underscores")
    func binaryConsecutiveUnderscoresThrows() throws {
        let lexer = Lexer("0b1__0")
        #expect(throws: LexerError.invalidNumberFormat("0b1__", line: 1, column: 1)) {
            try lexer.nextToken()
        }
    }

    @Test("Throws error for binary with invalid digit")
    func binaryInvalidDigitThrows() throws {
        // 0b2 should be lexed as 0b with no valid digits
        let lexer = Lexer("0b2")
        #expect(throws: LexerError.invalidNumberFormat("0b", line: 1, column: 1)) {
            try lexer.nextToken()
        }
    }

    @Test("Uppercase prefix is not recognized as binary")
    func uppercasePrefixNotBinary() throws {
        // 0B1010 should be lexed as 0 followed by illegal character B
        let lexer = Lexer("0B1010")
        let token = try lexer.nextToken()
        #expect(token.type == .integer)
        #expect(token.text == "0")

        #expect(throws: LexerError.illegalCharacter("B", line: 1, column: 2)) {
            try lexer.nextToken()
        }
    }

    // MARK: - Octal integer literals

    @Test("Scans basic octal integer")
    func scanBasicOctal() throws {
        let lexer = Lexer("0o700")
        let token = try lexer.nextToken()
        #expect(token.type == .integer)
        #expect(token.text == "0o700")
    }

    @Test("Scans octal zero")
    func scanOctalZero() throws {
        let lexer = Lexer("0o0")
        let token = try lexer.nextToken()
        #expect(token.type == .integer)
        #expect(token.text == "0o0")
    }

    @Test("Scans short octal")
    func scanShortOctal() throws {
        let lexer = Lexer("0o7")
        let token = try lexer.nextToken()
        #expect(token.type == .integer)
        #expect(token.text == "0o7")
    }

    @Test("Scans negative octal integer")
    func scanNegativeOctal() throws {
        let lexer = Lexer("-0o700")
        let token = try lexer.nextToken()
        #expect(token.type == .integer)
        #expect(token.text == "-0o700")
    }

    @Test("Scans positive octal integer with plus sign")
    func scanPositiveOctal() throws {
        let lexer = Lexer("+0o755")
        let token = try lexer.nextToken()
        #expect(token.type == .integer)
        #expect(token.text == "+0o755")
    }

    @Test("Scans octal with underscore separators")
    func scanOctalWithUnderscores() throws {
        let lexer = Lexer("0o7_55")
        let token = try lexer.nextToken()
        #expect(token.type == .integer)
        #expect(token.text == "0o755")
    }

    @Test("Throws error for octal with no digits")
    func octalNoDigitsThrows() throws {
        let lexer = Lexer("0o")
        #expect(throws: LexerError.invalidNumberFormat("0o", line: 1, column: 1)) {
            try lexer.nextToken()
        }
    }

    @Test("Throws error for octal with leading underscore")
    func octalLeadingUnderscoreThrows() throws {
        let lexer = Lexer("0o_7")
        #expect(throws: LexerError.invalidNumberFormat("0o_", line: 1, column: 1)) {
            try lexer.nextToken()
        }
    }

    @Test("Throws error for octal with trailing underscore")
    func octalTrailingUnderscoreThrows() throws {
        let lexer = Lexer("0o7_")
        #expect(throws: LexerError.invalidNumberFormat("0o7_", line: 1, column: 1)) {
            try lexer.nextToken()
        }
    }

    @Test("Throws error for octal with consecutive underscores")
    func octalConsecutiveUnderscoresThrows() throws {
        let lexer = Lexer("0o7__5")
        #expect(throws: LexerError.invalidNumberFormat("0o7__", line: 1, column: 1)) {
            try lexer.nextToken()
        }
    }

    @Test("Throws error for octal with invalid digit")
    func octalInvalidDigitThrows() throws {
        // 0o8 should be lexed as 0o with no valid digits
        let lexer = Lexer("0o8")
        #expect(throws: LexerError.invalidNumberFormat("0o", line: 1, column: 1)) {
            try lexer.nextToken()
        }
    }

    @Test("Uppercase prefix is not recognized as octal")
    func uppercasePrefixNotOctal() throws {
        // 0O7 should be lexed as 0 followed by illegal character O
        let lexer = Lexer("0O7")
        let token = try lexer.nextToken()
        #expect(token.type == .integer)
        #expect(token.text == "0")

        #expect(throws: LexerError.illegalCharacter("O", line: 1, column: 2)) {
            try lexer.nextToken()
        }
    }

    // MARK: - Decimal integers with leading zeros

    @Test("Scans decimal with leading zero")
    func scanDecimalWithLeadingZero() throws {
        let lexer = Lexer("0700")
        let token = try lexer.nextToken()
        #expect(token.type == .integer)
        #expect(token.text == "0700")
    }

    @Test("Scans decimal 08")
    func scanDecimal08() throws {
        let lexer = Lexer("08")
        let token = try lexer.nextToken()
        #expect(token.type == .integer)
        #expect(token.text == "08")
    }

    @Test("Scans decimal 00")
    func scanDecimal00() throws {
        let lexer = Lexer("00")
        let token = try lexer.nextToken()
        #expect(token.type == .integer)
        #expect(token.text == "00")
    }

    @Test("Plain zero is still valid")
    func plainZeroStillValid() throws {
        let lexer = Lexer("0")
        let token = try lexer.nextToken()
        #expect(token.type == .integer)
        #expect(token.text == "0")
    }

    // MARK: - Floating point literals

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
        // 5. should be lexed as integer 5, then illegal character '.'
        let lexer = Lexer("5.")
        let token = try lexer.nextToken()
        #expect(token.type == .integer)
        #expect(token.text == "5")

        #expect(throws: LexerError.illegalCharacter(".", line: 1, column: 2)) {
            try lexer.nextToken()
        }
    }

    @Test("Exponent without digits remains integer")
    func exponentWithoutDigitsRemainsInteger() throws {
        // 1e should be lexed as integer 1, then illegal character 'e'
        let lexer = Lexer("1e")
        let token = try lexer.nextToken()
        #expect(token.type == .integer)
        #expect(token.text == "1")

        #expect(throws: LexerError.illegalCharacter("e", line: 1, column: 2)) {
            try lexer.nextToken()
        }
    }

    @Test("Exponent with only sign remains integer")
    func exponentWithOnlySignRemainsInteger() throws {
        // 1e- should be lexed as integer 1, then illegal characters
        let lexer = Lexer("1e-")
        let token = try lexer.nextToken()
        #expect(token.type == .integer)
        #expect(token.text == "1")
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
        let lexer = Lexer("1e_10")
        // 1e is not a valid exponent (no digits), so 1 is returned as integer
        let token = try lexer.nextToken()
        #expect(token.type == .integer)
        #expect(token.text == "1")
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

    // MARK: - Ratio literals

    @Test("Scans basic ratio")
    func scanBasicRatio() throws {
        let lexer = Lexer("3/4")
        let token = try lexer.nextToken()
        #expect(token.type == .ratio)
        #expect(token.text == "3/4")
    }

    @Test("Scans ratio with larger numbers")
    func scanRatioLargerNumbers() throws {
        let lexer = Lexer("10/4")
        let token = try lexer.nextToken()
        #expect(token.type == .ratio)
        #expect(token.text == "10/4")
    }

    @Test("Scans negative ratio")
    func scanNegativeRatio() throws {
        let lexer = Lexer("-3/4")
        let token = try lexer.nextToken()
        #expect(token.type == .ratio)
        #expect(token.text == "-3/4")
    }

    @Test("Scans positive ratio with plus sign")
    func scanPositiveRatio() throws {
        let lexer = Lexer("+3/4")
        let token = try lexer.nextToken()
        #expect(token.type == .ratio)
        #expect(token.text == "+3/4")
    }

    @Test("Scans ratio with zero numerator")
    func scanRatioZeroNumerator() throws {
        let lexer = Lexer("0/5")
        let token = try lexer.nextToken()
        #expect(token.type == .ratio)
        #expect(token.text == "0/5")
    }

    @Test("Scans ratio with underscores in numerator")
    func scanRatioWithUnderscoresInNumerator() throws {
        let lexer = Lexer("1_000/4")
        let token = try lexer.nextToken()
        #expect(token.type == .ratio)
        #expect(token.text == "1000/4")
    }

    @Test("Scans ratio with underscores in denominator")
    func scanRatioWithUnderscoresInDenominator() throws {
        let lexer = Lexer("3/1_000")
        let token = try lexer.nextToken()
        #expect(token.type == .ratio)
        #expect(token.text == "3/1000")
    }

    @Test("Scans ratio with underscores in both parts")
    func scanRatioWithUnderscoresInBothParts() throws {
        let lexer = Lexer("1_000/2_000")
        let token = try lexer.nextToken()
        #expect(token.type == .ratio)
        #expect(token.text == "1000/2000")
    }

    @Test("Throws error for ratio with zero denominator")
    func ratioZeroDenominatorThrows() throws {
        let lexer = Lexer("3/0")
        #expect(throws: LexerError.invalidRatio("3/0", line: 1, column: 1)) {
            try lexer.nextToken()
        }
    }

    @Test("Throws error for trailing underscore in ratio denominator")
    func ratioTrailingUnderscoreInDenominatorThrows() throws {
        let lexer = Lexer("3/4_")
        #expect(throws: LexerError.invalidNumberFormat("3/4_", line: 1, column: 1)) {
            try lexer.nextToken()
        }
    }

    @Test("Throws error for consecutive underscores in ratio denominator")
    func ratioConsecutiveUnderscoresInDenominatorThrows() throws {
        let lexer = Lexer("3/4__5")
        #expect(throws: LexerError.invalidNumberFormat("3/4__", line: 1, column: 1)) {
            try lexer.nextToken()
        }
    }

    @Test("Scans multiple ratios")
    func scanMultipleRatios() throws {
        let lexer = Lexer("1/2 3/4 5/6")

        let token1 = try lexer.nextToken()
        #expect(token1.type == .ratio)
        #expect(token1.text == "1/2")

        let token2 = try lexer.nextToken()
        #expect(token2.type == .ratio)
        #expect(token2.text == "3/4")

        let token3 = try lexer.nextToken()
        #expect(token3.type == .ratio)
        #expect(token3.text == "5/6")

        let eofToken = try lexer.nextToken()
        #expect(eofToken.type == .eof)
    }
}

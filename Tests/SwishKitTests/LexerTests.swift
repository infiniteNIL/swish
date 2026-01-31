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
}

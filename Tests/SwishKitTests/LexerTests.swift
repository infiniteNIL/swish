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
        let lexer = Lexer("@")
        #expect(throws: LexerError.illegalCharacter("@", line: 1, column: 1)) {
            try lexer.nextToken()
        }
    }

    // MARK: - Symbol literals

    @Test("Scans simple symbol")
    func scanSimpleSymbol() throws {
        let lexer = Lexer("foo")
        let token = try lexer.nextToken()
        #expect(token.type == .symbol)
        #expect(token.text == "foo")
        #expect(token.line == 1)
        #expect(token.column == 1)
    }

    @Test("Scans symbol with digits")
    func scanSymbolWithDigits() throws {
        let lexer = Lexer("foo123")
        let token = try lexer.nextToken()
        #expect(token.type == .symbol)
        #expect(token.text == "foo123")
    }

    @Test("Scans hyphenated symbol")
    func scanHyphenatedSymbol() throws {
        let lexer = Lexer("foo-bar")
        let token = try lexer.nextToken()
        #expect(token.type == .symbol)
        #expect(token.text == "foo-bar")
    }

    @Test("Scans symbol starting with hyphen")
    func scanSymbolStartingWithHyphen() throws {
        let lexer = Lexer("-bar")
        let token = try lexer.nextToken()
        #expect(token.type == .symbol)
        #expect(token.text == "-bar")
    }

    @Test("Scans lone plus as symbol")
    func scanLonePlusAsSymbol() throws {
        let lexer = Lexer("+")
        let token = try lexer.nextToken()
        #expect(token.type == .symbol)
        #expect(token.text == "+")
    }

    @Test("Scans lone minus as symbol")
    func scanLoneMinusAsSymbol() throws {
        let lexer = Lexer("-")
        let token = try lexer.nextToken()
        #expect(token.type == .symbol)
        #expect(token.text == "-")
    }

    @Test("Scans symbol with special start chars")
    func scanSymbolWithSpecialStartChars() throws {
        let lexer = Lexer("*foo*")
        let token = try lexer.nextToken()
        #expect(token.type == .symbol)
        #expect(token.text == "*foo*")
    }

    @Test("Scans question mark symbol")
    func scanQuestionMarkSymbol() throws {
        let lexer = Lexer("empty?")
        let token = try lexer.nextToken()
        #expect(token.type == .symbol)
        #expect(token.text == "empty?")
    }

    @Test("Scans bang symbol")
    func scanBangSymbol() throws {
        let lexer = Lexer("swap!")
        let token = try lexer.nextToken()
        #expect(token.type == .symbol)
        #expect(token.text == "swap!")
    }

    @Test("Scans arrow symbol")
    func scanArrowSymbol() throws {
        let lexer = Lexer("->")
        let token = try lexer.nextToken()
        #expect(token.type == .symbol)
        #expect(token.text == "->")
    }

    @Test("Scans comparison symbols")
    func scanComparisonSymbols() throws {
        let lexer = Lexer("<=>")
        let token = try lexer.nextToken()
        #expect(token.type == .symbol)
        #expect(token.text == "<=>")
    }

    @Test("Scans +foo as symbol")
    func scanPlusFooAsSymbol() throws {
        let lexer = Lexer("+foo")
        let token = try lexer.nextToken()
        #expect(token.type == .symbol)
        #expect(token.text == "+foo")
    }

    @Test("+5 is still an integer")
    func plusFiveIsStillInteger() throws {
        let lexer = Lexer("+5")
        let token = try lexer.nextToken()
        #expect(token.type == .integer)
        #expect(token.text == "+5")
    }

    @Test("-3 is still an integer")
    func minusThreeIsStillInteger() throws {
        let lexer = Lexer("-3")
        let token = try lexer.nextToken()
        #expect(token.type == .integer)
        #expect(token.text == "-3")
    }

    @Test("Scans / as symbol")
    func scanSlashAsSymbol() throws {
        let lexer = Lexer("/")
        let token = try lexer.nextToken()
        #expect(token.type == .symbol)
        #expect(token.text == "/")
    }

    @Test("Scans namespaced symbol")
    func scanNamespacedSymbol() throws {
        let lexer = Lexer("clojure.core/map")
        let token = try lexer.nextToken()
        #expect(token.type == .symbol)
        #expect(token.text == "clojure.core/map")
    }

    @Test("Scans dotted symbol")
    func scanDottedSymbol() throws {
        let lexer = Lexer("java.util.BitSet")
        let token = try lexer.nextToken()
        #expect(token.type == .symbol)
        #expect(token.text == "java.util.BitSet")
    }

    @Test("Scans namespaced symbol with hyphen")
    func scanNamespacedSymbolWithHyphen() throws {
        let lexer = Lexer("my-ns/my-fn")
        let token = try lexer.nextToken()
        #expect(token.type == .symbol)
        #expect(token.text == "my-ns/my-fn")
    }

    @Test("true is still a boolean")
    func trueIsStillBoolean() throws {
        let lexer = Lexer("true")
        let token = try lexer.nextToken()
        #expect(token.type == .boolean)
        #expect(token.text == "true")
    }

    @Test("false is still a boolean")
    func falseIsStillBoolean() throws {
        let lexer = Lexer("false")
        let token = try lexer.nextToken()
        #expect(token.type == .boolean)
        #expect(token.text == "false")
    }

    @Test("nil is still nil")
    func nilIsStillNil() throws {
        let lexer = Lexer("nil")
        let token = try lexer.nextToken()
        #expect(token.type == .nil)
        #expect(token.text == "nil")
    }

    @Test("Scans multiple symbols")
    func scanMultipleSymbols() throws {
        let lexer = Lexer("foo bar baz")

        let token1 = try lexer.nextToken()
        #expect(token1.type == .symbol)
        #expect(token1.text == "foo")

        let token2 = try lexer.nextToken()
        #expect(token2.type == .symbol)
        #expect(token2.text == "bar")

        let token3 = try lexer.nextToken()
        #expect(token3.type == .symbol)
        #expect(token3.text == "baz")

        let eofToken = try lexer.nextToken()
        #expect(eofToken.type == .eof)
    }

    @Test("Scans mixed symbols and numbers")
    func scanMixedSymbolsAndNumbers() throws {
        let lexer = Lexer("foo 42 bar")

        let token1 = try lexer.nextToken()
        #expect(token1.type == .symbol)
        #expect(token1.text == "foo")

        let token2 = try lexer.nextToken()
        #expect(token2.type == .integer)
        #expect(token2.text == "42")

        let token3 = try lexer.nextToken()
        #expect(token3.type == .symbol)
        #expect(token3.text == "bar")
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
        // 0XFF should be an error - 'X' is not a valid number terminator
        let lexer = Lexer("0XFF")
        #expect(throws: LexerError.invalidNumberFormat("0XFF", line: 1, column: 1)) {
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
        // 0B1010 should be an error - 'B' is not a valid number terminator
        let lexer = Lexer("0B1010")
        #expect(throws: LexerError.invalidNumberFormat("0B1010", line: 1, column: 1)) {
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
        // 0O7 should be an error - 'O' is not a valid number terminator
        let lexer = Lexer("0O7")
        #expect(throws: LexerError.invalidNumberFormat("0O7", line: 1, column: 1)) {
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

    // MARK: - String literals

    @Test("Scans basic string")
    func scanBasicString() throws {
        let lexer = Lexer("\"hello\"")
        let token = try lexer.nextToken()
        #expect(token.type == .string)
        #expect(token.text == "hello")
        #expect(token.line == 1)
        #expect(token.column == 1)
    }

    @Test("Scans empty string")
    func scanEmptyString() throws {
        let lexer = Lexer("\"\"")
        let token = try lexer.nextToken()
        #expect(token.type == .string)
        #expect(token.text == "")
    }

    @Test("Scans string with spaces")
    func scanStringWithSpaces() throws {
        let lexer = Lexer("\"hello world\"")
        let token = try lexer.nextToken()
        #expect(token.type == .string)
        #expect(token.text == "hello world")
    }

    @Test("Scans string with escaped quote")
    func scanStringWithEscapedQuote() throws {
        let lexer = Lexer("\"say \\\"hi\\\"\"")
        let token = try lexer.nextToken()
        #expect(token.type == .string)
        #expect(token.text == "say \"hi\"")
    }

    @Test("Scans string with escaped backslash")
    func scanStringWithEscapedBackslash() throws {
        let lexer = Lexer("\"a\\\\b\"")
        let token = try lexer.nextToken()
        #expect(token.type == .string)
        #expect(token.text == "a\\b")
    }

    @Test("Scans string with newline escape")
    func scanStringWithNewlineEscape() throws {
        let lexer = Lexer("\"line1\\nline2\"")
        let token = try lexer.nextToken()
        #expect(token.type == .string)
        #expect(token.text == "line1\nline2")
    }

    @Test("Scans string with tab escape")
    func scanStringWithTabEscape() throws {
        let lexer = Lexer("\"col1\\tcol2\"")
        let token = try lexer.nextToken()
        #expect(token.type == .string)
        #expect(token.text == "col1\tcol2")
    }

    @Test("Scans string with carriage return escape")
    func scanStringWithCarriageReturnEscape() throws {
        let lexer = Lexer("\"line1\\rline2\"")
        let token = try lexer.nextToken()
        #expect(token.type == .string)
        #expect(token.text == "line1\rline2")
    }

    @Test("Scans string with null escape")
    func scanStringWithNullEscape() throws {
        let lexer = Lexer("\"a\\0b\"")
        let token = try lexer.nextToken()
        #expect(token.type == .string)
        #expect(token.text == "a\0b")
    }

    @Test("Scans string with multiple escapes")
    func scanStringWithMultipleEscapes() throws {
        let lexer = Lexer("\"\\\"\\\\\\n\\t\"")
        let token = try lexer.nextToken()
        #expect(token.type == .string)
        #expect(token.text == "\"\\\n\t")
    }

    @Test("Scans multiline string")
    func scanMultilineString() throws {
        let lexer = Lexer("\"line1\nline2\"")
        let token = try lexer.nextToken()
        #expect(token.type == .string)
        #expect(token.text == "line1\nline2")
    }

    @Test("Throws error for unterminated string")
    func unterminatedStringThrows() throws {
        let lexer = Lexer("\"hello")
        #expect(throws: LexerError.unterminatedString(line: 1, column: 1)) {
            try lexer.nextToken()
        }
    }

    @Test("Throws error for unterminated string at EOF after escape")
    func unterminatedStringAfterEscapeThrows() throws {
        let lexer = Lexer("\"hello\\")
        #expect(throws: LexerError.unterminatedString(line: 1, column: 1)) {
            try lexer.nextToken()
        }
    }

    @Test("Throws error for invalid escape sequence")
    func invalidEscapeSequenceThrows() throws {
        let lexer = Lexer("\"foo\\x\"")
        #expect(throws: LexerError.invalidEscapeSequence(char: "x", line: 1, column: 6)) {
            try lexer.nextToken()
        }
    }

    @Test("Scans multiple strings")
    func scanMultipleStrings() throws {
        let lexer = Lexer("\"hello\" \"world\"")

        let token1 = try lexer.nextToken()
        #expect(token1.type == .string)
        #expect(token1.text == "hello")

        let token2 = try lexer.nextToken()
        #expect(token2.type == .string)
        #expect(token2.text == "world")

        let eofToken = try lexer.nextToken()
        #expect(eofToken.type == .eof)
    }

    @Test("Scans string with numbers")
    func scanStringWithNumbers() throws {
        let lexer = Lexer("\"abc123\"")
        let token = try lexer.nextToken()
        #expect(token.type == .string)
        #expect(token.text == "abc123")
    }

    @Test("String position tracking")
    func stringPositionTracking() throws {
        let lexer = Lexer("  \"hello\"")
        let token = try lexer.nextToken()
        #expect(token.type == .string)
        #expect(token.text == "hello")
        #expect(token.column == 3)
    }

    // MARK: - Unicode escape sequences

    @Test("Scans string with Unicode escape - Euro sign")
    func scanStringWithUnicodeEscapeEuro() throws {
        let lexer = Lexer("\"\\u{20AC}\"")
        let token = try lexer.nextToken()
        #expect(token.type == .string)
        #expect(token.text == "€")
    }

    @Test("Scans string with Unicode escape - letter A")
    func scanStringWithUnicodeEscapeA() throws {
        let lexer = Lexer("\"\\u{0041}\"")
        let token = try lexer.nextToken()
        #expect(token.type == .string)
        #expect(token.text == "A")
    }

    @Test("Scans string with Unicode escape - fewer digits")
    func scanStringWithUnicodeEscapeFewerDigits() throws {
        let lexer = Lexer("\"\\u{41}\"")
        let token = try lexer.nextToken()
        #expect(token.type == .string)
        #expect(token.text == "A")
    }

    @Test("Scans string with Unicode escape - emoji")
    func scanStringWithUnicodeEscapeEmoji() throws {
        let lexer = Lexer("\"\\u{1F600}\"")
        let token = try lexer.nextToken()
        #expect(token.type == .string)
        #expect(token.text == "😀")
    }

    @Test("Scans string with Unicode escape - mixed content")
    func scanStringWithUnicodeEscapeMixed() throws {
        let lexer = Lexer("\"Price: \\u{20AC}100\"")
        let token = try lexer.nextToken()
        #expect(token.type == .string)
        #expect(token.text == "Price: €100")
    }

    @Test("Scans string with multiple Unicode escapes")
    func scanStringWithMultipleUnicodeEscapes() throws {
        let lexer = Lexer("\"\\u{41}\\u{42}\\u{43}\"")
        let token = try lexer.nextToken()
        #expect(token.type == .string)
        #expect(token.text == "ABC")
    }

    @Test("Scans string with lowercase hex digits")
    func scanStringWithUnicodeEscapeLowercaseHex() throws {
        let lexer = Lexer("\"\\u{20ac}\"")
        let token = try lexer.nextToken()
        #expect(token.type == .string)
        #expect(token.text == "€")
    }

    @Test("Throws error for Unicode escape missing brace")
    func unicodeEscapeMissingBraceThrows() throws {
        let lexer = Lexer("\"\\u\"")
        #expect(throws: LexerError.invalidUnicodeEscape("expected '{'", line: 1, column: 3)) {
            try lexer.nextToken()
        }
    }

    @Test("Throws error for Unicode escape with no hex digits")
    func unicodeEscapeNoDigitsThrows() throws {
        let lexer = Lexer("\"\\u{}\"")
        #expect(throws: LexerError.invalidUnicodeEscape("expected 1-6 hex digits", line: 1, column: 5)) {
            try lexer.nextToken()
        }
    }

    @Test("Throws error for Unicode escape with invalid hex digit")
    func unicodeEscapeInvalidHexDigitThrows() throws {
        let lexer = Lexer("\"\\u{GGGG}\"")
        #expect(throws: LexerError.invalidUnicodeEscape("invalid hex digit", line: 1, column: 5)) {
            try lexer.nextToken()
        }
    }

    @Test("Throws error for Unicode escape with too many digits")
    func unicodeEscapeTooManyDigitsThrows() throws {
        let lexer = Lexer("\"\\u{1234567}\"")
        #expect(throws: LexerError.invalidUnicodeEscape("expected 1-6 hex digits", line: 1, column: 12)) {
            try lexer.nextToken()
        }
    }

    @Test("Throws error for Unicode escape with surrogate code point")
    func unicodeEscapeSurrogateThrows() throws {
        let lexer = Lexer("\"\\u{D800}\"")
        #expect(throws: LexerError.invalidUnicodeEscape("invalid code point", line: 1, column: 9)) {
            try lexer.nextToken()
        }
    }

    @Test("Throws error for Unicode escape with code point out of range")
    func unicodeEscapeOutOfRangeThrows() throws {
        let lexer = Lexer("\"\\u{110000}\"")
        #expect(throws: LexerError.invalidUnicodeEscape("invalid code point", line: 1, column: 11)) {
            try lexer.nextToken()
        }
    }

    @Test("Throws error for unterminated Unicode escape")
    func unicodeEscapeUnterminatedThrows() throws {
        let lexer = Lexer("\"\\u{20AC")
        #expect(throws: LexerError.unterminatedString(line: 1, column: 1)) {
            try lexer.nextToken()
        }
    }

    // MARK: - Multiline string literals

    @Test("Scans basic multiline string")
    func scanBasicMultilineString() throws {
        let lexer = Lexer("\"\"\"\nhello\n\"\"\"")
        let token = try lexer.nextToken()
        #expect(token.type == .string)
        #expect(token.text == "hello")
        #expect(token.line == 1)
        #expect(token.column == 1)
    }

    @Test("Scans empty multiline string")
    func scanEmptyMultilineString() throws {
        let lexer = Lexer("\"\"\"\n\"\"\"")
        let token = try lexer.nextToken()
        #expect(token.type == .string)
        #expect(token.text == "")
    }

    @Test("Scans multiline string with multiple lines")
    func scanMultilineStringWithMultipleLines() throws {
        let lexer = Lexer("\"\"\"\nline1\nline2\nline3\n\"\"\"")
        let token = try lexer.nextToken()
        #expect(token.type == .string)
        #expect(token.text == "line1\nline2\nline3")
    }

    @Test("Scans multiline string with indentation stripping")
    func scanMultilineStringIndentationStripping() throws {
        let lexer = Lexer("\"\"\"\n    hello\n    \"\"\"")
        let token = try lexer.nextToken()
        #expect(token.type == .string)
        #expect(token.text == "hello")
    }

    @Test("Scans multiline string preserving relative indentation")
    func scanMultilineStringPreservingRelativeIndentation() throws {
        let lexer = Lexer("\"\"\"\n    line1\n        indented\n    \"\"\"")
        let token = try lexer.nextToken()
        #expect(token.type == .string)
        #expect(token.text == "line1\n    indented")
    }

    @Test("Scans multiline string with unescaped single quote")
    func scanMultilineStringWithSingleQuote() throws {
        let lexer = Lexer("\"\"\"\nSay \"hi\"\n\"\"\"")
        let token = try lexer.nextToken()
        #expect(token.type == .string)
        #expect(token.text == "Say \"hi\"")
    }

    @Test("Scans multiline string with unescaped double quote")
    func scanMultilineStringWithDoubleQuote() throws {
        let lexer = Lexer("\"\"\"\nHe said \"hello\"\n\"\"\"")
        let token = try lexer.nextToken()
        #expect(token.type == .string)
        #expect(token.text == "He said \"hello\"")
    }

    @Test("Scans multiline string with two consecutive quotes")
    func scanMultilineStringWithTwoQuotes() throws {
        let lexer = Lexer("\"\"\"\ntest\"\"end\n\"\"\"")
        let token = try lexer.nextToken()
        #expect(token.type == .string)
        #expect(token.text == "test\"\"end")
    }

    @Test("Scans multiline string with line continuation")
    func scanMultilineStringWithLineContinuation() throws {
        let lexer = Lexer("\"\"\"\nhello \\\nworld\n\"\"\"")
        let token = try lexer.nextToken()
        #expect(token.type == .string)
        #expect(token.text == "hello world")
    }

    @Test("Scans multiline string with escape sequences")
    func scanMultilineStringWithEscapeSequences() throws {
        let lexer = Lexer("\"\"\"\nhello\\nworld\\ttab\n\"\"\"")
        let token = try lexer.nextToken()
        #expect(token.type == .string)
        #expect(token.text == "hello\nworld\ttab")
    }

    @Test("Scans multiline string with Unicode escape")
    func scanMultilineStringWithUnicodeEscape() throws {
        let lexer = Lexer("\"\"\"\nPrice: \\u{20AC}100\n\"\"\"")
        let token = try lexer.nextToken()
        #expect(token.type == .string)
        #expect(token.text == "Price: €100")
    }

    @Test("Scans multiline string with empty lines")
    func scanMultilineStringWithEmptyLines() throws {
        let lexer = Lexer("\"\"\"\nline1\n\nline3\n\"\"\"")
        let token = try lexer.nextToken()
        #expect(token.type == .string)
        #expect(token.text == "line1\n\nline3")
    }

    @Test("Scans multiline string with whitespace-only lines")
    func scanMultilineStringWithWhitespaceOnlyLines() throws {
        let lexer = Lexer("\"\"\"\n    line1\n    \n    line3\n    \"\"\"")
        let token = try lexer.nextToken()
        #expect(token.type == .string)
        #expect(token.text == "line1\n\nline3")
    }

    @Test("Scans multiline string with escaped backslash before newline")
    func scanMultilineStringEscapedBackslashBeforeNewline() throws {
        let lexer = Lexer("\"\"\"\npath\\\\\nnext\n\"\"\"")
        let token = try lexer.nextToken()
        #expect(token.type == .string)
        #expect(token.text == "path\\\nnext")
    }

    @Test("Throws error for content on multiline string opening line")
    func multilineStringContentOnOpeningLineThrows() throws {
        let lexer = Lexer("\"\"\"hello\n\"\"\"")
        #expect(throws: LexerError.multilineStringContentOnOpeningLine(line: 1, column: 4)) {
            try lexer.nextToken()
        }
    }

    @Test("Throws error for insufficient indentation in multiline string")
    func multilineStringInsufficientIndentationThrows() throws {
        let lexer = Lexer("\"\"\"\n    line1\n  short\n    \"\"\"")
        #expect(throws: LexerError.multilineStringInsufficientIndentation(line: 3, column: 1)) {
            try lexer.nextToken()
        }
    }

    @Test("Throws error for unterminated multiline string")
    func unterminatedMultilineStringThrows() throws {
        let lexer = Lexer("\"\"\"\nhello")
        #expect(throws: LexerError.unterminatedMultilineString(line: 1, column: 1)) {
            try lexer.nextToken()
        }
    }

    @Test("Throws error for invalid escape in multiline string")
    func multilineStringInvalidEscapeThrows() throws {
        let lexer = Lexer("\"\"\"\n\\x\n\"\"\"")
        #expect(throws: LexerError.invalidEscapeSequence(char: "x", line: 1, column: 1)) {
            try lexer.nextToken()
        }
    }

    @Test("Multiline string position tracking")
    func multilineStringPositionTracking() throws {
        let lexer = Lexer("  \"\"\"\n  hello\n  \"\"\"")
        let token = try lexer.nextToken()
        #expect(token.type == .string)
        #expect(token.text == "hello")
        #expect(token.column == 3)
    }

    @Test("Scans multiline string with tabs in indentation")
    func scanMultilineStringWithTabIndentation() throws {
        let lexer = Lexer("\"\"\"\n\thello\n\t\"\"\"")
        let token = try lexer.nextToken()
        #expect(token.type == .string)
        #expect(token.text == "hello")
    }

    @Test("Scans multiline string allowing whitespace after opening delimiter")
    func scanMultilineStringWithWhitespaceAfterOpening() throws {
        let lexer = Lexer("\"\"\"   \nhello\n\"\"\"")
        let token = try lexer.nextToken()
        #expect(token.type == .string)
        #expect(token.text == "hello")
    }

    @Test("Scans multiline string with all escape types")
    func scanMultilineStringAllEscapeTypes() throws {
        let lexer = Lexer("\"\"\"\n\\\"\\\\\\n\\t\\r\\0\n\"\"\"")
        let token = try lexer.nextToken()
        #expect(token.type == .string)
        #expect(token.text == "\"\\\n\t\r\0")
    }

    @Test("Scans multiline string with mixed content")
    func scanMultilineStringMixedContent() throws {
        let lexer = Lexer("\"\"\"\n    func hello() {\n        print(\"Hello\")\n    }\n    \"\"\"")
        let token = try lexer.nextToken()
        #expect(token.type == .string)
        #expect(token.text == "func hello() {\n    print(\"Hello\")\n}")
    }

    @Test("Throws error for unterminated multiline string with only opening")
    func unterminatedMultilineStringOnlyOpeningThrows() throws {
        let lexer = Lexer("\"\"\"")
        #expect(throws: LexerError.unterminatedMultilineString(line: 1, column: 1)) {
            try lexer.nextToken()
        }
    }

    @Test("Scans multiple tokens after multiline string")
    func scanMultipleTokensAfterMultilineString() throws {
        let lexer = Lexer("\"\"\"\nhello\n\"\"\" 42")
        let stringToken = try lexer.nextToken()
        #expect(stringToken.type == .string)
        #expect(stringToken.text == "hello")

        let intToken = try lexer.nextToken()
        #expect(intToken.type == .integer)
        #expect(intToken.text == "42")
    }

    // MARK: - Character literals

    @Test("Scans simple character - letter")
    func scanSimpleCharacterLetter() throws {
        let lexer = Lexer("\\a")
        let token = try lexer.nextToken()
        #expect(token.type == .character)
        #expect(token.text == "a")
        #expect(token.line == 1)
        #expect(token.column == 1)
    }

    @Test("Scans simple character - digit")
    func scanSimpleCharacterDigit() throws {
        let lexer = Lexer("\\5")
        let token = try lexer.nextToken()
        #expect(token.type == .character)
        #expect(token.text == "5")
    }

    @Test("Scans simple character - punctuation")
    func scanSimpleCharacterPunctuation() throws {
        let lexer = Lexer("\\!")
        let token = try lexer.nextToken()
        #expect(token.type == .character)
        #expect(token.text == "!")
    }

    @Test("Scans named character - newline")
    func scanNamedCharacterNewline() throws {
        let lexer = Lexer("\\newline")
        let token = try lexer.nextToken()
        #expect(token.type == .character)
        #expect(token.text == "\n")
    }

    @Test("Scans named character - tab")
    func scanNamedCharacterTab() throws {
        let lexer = Lexer("\\tab")
        let token = try lexer.nextToken()
        #expect(token.type == .character)
        #expect(token.text == "\t")
    }

    @Test("Scans named character - space")
    func scanNamedCharacterSpace() throws {
        let lexer = Lexer("\\space")
        let token = try lexer.nextToken()
        #expect(token.type == .character)
        #expect(token.text == " ")
    }

    @Test("Scans named character - return")
    func scanNamedCharacterReturn() throws {
        let lexer = Lexer("\\return")
        let token = try lexer.nextToken()
        #expect(token.type == .character)
        #expect(token.text == "\r")
    }

    @Test("Scans named character - backspace")
    func scanNamedCharacterBackspace() throws {
        let lexer = Lexer("\\backspace")
        let token = try lexer.nextToken()
        #expect(token.type == .character)
        #expect(token.text == "\u{0008}")
    }

    @Test("Scans named character - formfeed")
    func scanNamedCharacterFormfeed() throws {
        let lexer = Lexer("\\formfeed")
        let token = try lexer.nextToken()
        #expect(token.type == .character)
        #expect(token.text == "\u{000C}")
    }

    @Test("Scans Unicode character - euro sign")
    func scanUnicodeCharacterEuro() throws {
        let lexer = Lexer("\\u{20AC}")
        let token = try lexer.nextToken()
        #expect(token.type == .character)
        #expect(token.text == "€")
    }

    @Test("Scans Unicode character - letter A")
    func scanUnicodeCharacterA() throws {
        let lexer = Lexer("\\u{41}")
        let token = try lexer.nextToken()
        #expect(token.type == .character)
        #expect(token.text == "A")
    }

    @Test("Scans Unicode character - emoji")
    func scanUnicodeCharacterEmoji() throws {
        let lexer = Lexer("\\u{1F600}")
        let token = try lexer.nextToken()
        #expect(token.type == .character)
        #expect(token.text == "😀")
    }

    @Test("Single letter n is not newline")
    func singleLetterNIsNotNewline() throws {
        let lexer = Lexer("\\n")
        let token = try lexer.nextToken()
        #expect(token.type == .character)
        #expect(token.text == "n")
    }

    @Test("Single letter t is not tab")
    func singleLetterTIsNotTab() throws {
        let lexer = Lexer("\\t")
        let token = try lexer.nextToken()
        #expect(token.type == .character)
        #expect(token.text == "t")
    }

    @Test("Throws error for backslash at EOF")
    func characterAtEOFThrows() throws {
        let lexer = Lexer("\\")
        #expect(throws: LexerError.invalidCharacterLiteral("unexpected end of input", line: 1, column: 1)) {
            try lexer.nextToken()
        }
    }

    @Test("Throws error for whitespace after backslash")
    func characterWhitespaceAfterBackslashThrows() throws {
        let lexer = Lexer("\\ ")
        #expect(throws: LexerError.invalidCharacterLiteral("whitespace after backslash (use \\space for space character)", line: 1, column: 1)) {
            try lexer.nextToken()
        }
    }

    @Test("Throws error for unknown named character")
    func unknownNamedCharacterThrows() throws {
        let lexer = Lexer("\\foo")
        #expect(throws: LexerError.unknownNamedCharacter("foo", line: 1, column: 1)) {
            try lexer.nextToken()
        }
    }

    @Test("Character position tracking")
    func characterPositionTracking() throws {
        let lexer = Lexer("  \\a")
        let token = try lexer.nextToken()
        #expect(token.type == .character)
        #expect(token.text == "a")
        #expect(token.column == 3)
    }

    @Test("Scans multiple characters in sequence")
    func scanMultipleCharacters() throws {
        let lexer = Lexer("\\a \\b \\c")

        let token1 = try lexer.nextToken()
        #expect(token1.type == .character)
        #expect(token1.text == "a")

        let token2 = try lexer.nextToken()
        #expect(token2.type == .character)
        #expect(token2.text == "b")

        let token3 = try lexer.nextToken()
        #expect(token3.type == .character)
        #expect(token3.text == "c")

        let eofToken = try lexer.nextToken()
        #expect(eofToken.type == .eof)
    }

    @Test("Scans mixed characters and other tokens")
    func scanMixedCharactersAndTokens() throws {
        let lexer = Lexer("\\a 42 \"hello\"")

        let charToken = try lexer.nextToken()
        #expect(charToken.type == .character)
        #expect(charToken.text == "a")

        let intToken = try lexer.nextToken()
        #expect(intToken.type == .integer)
        #expect(intToken.text == "42")

        let stringToken = try lexer.nextToken()
        #expect(stringToken.type == .string)
        #expect(stringToken.text == "hello")
    }

    @Test("Unicode character with lowercase hex")
    func unicodeCharacterLowercaseHex() throws {
        let lexer = Lexer("\\u{20ac}")
        let token = try lexer.nextToken()
        #expect(token.type == .character)
        #expect(token.text == "€")
    }

    @Test("Throws error for Unicode character with invalid hex")
    func unicodeCharacterInvalidHexThrows() throws {
        let lexer = Lexer("\\u{GGGG}")
        #expect(throws: LexerError.invalidUnicodeEscape("invalid hex digit", line: 1, column: 4)) {
            try lexer.nextToken()
        }
    }

    @Test("Throws error for Unicode character with too many digits")
    func unicodeCharacterTooManyDigitsThrows() throws {
        let lexer = Lexer("\\u{1234567}")
        #expect(throws: LexerError.invalidUnicodeEscape("expected 1-6 hex digits", line: 1, column: 11)) {
            try lexer.nextToken()
        }
    }

    @Test("Throws error for Unicode character unterminated")
    func unicodeCharacterUnterminatedThrows() throws {
        let lexer = Lexer("\\u{20AC")
        #expect(throws: LexerError.invalidCharacterLiteral("unterminated unicode escape", line: 1, column: 1)) {
            try lexer.nextToken()
        }
    }

    @Test("Throws error for Unicode character with surrogate code point")
    func unicodeCharacterSurrogateThrows() throws {
        let lexer = Lexer("\\u{D800}")
        #expect(throws: LexerError.invalidUnicodeEscape("invalid code point", line: 1, column: 8)) {
            try lexer.nextToken()
        }
    }

    // MARK: - Boolean literals

    @Test("Scans true")
    func scanTrue() throws {
        let lexer = Lexer("true")
        let token = try lexer.nextToken()
        #expect(token.type == .boolean)
        #expect(token.text == "true")
        #expect(token.line == 1)
        #expect(token.column == 1)
    }

    @Test("Scans false")
    func scanFalse() throws {
        let lexer = Lexer("false")
        let token = try lexer.nextToken()
        #expect(token.type == .boolean)
        #expect(token.text == "false")
        #expect(token.line == 1)
        #expect(token.column == 1)
    }

    @Test("Boolean position tracking")
    func booleanPositionTracking() throws {
        let lexer = Lexer("  true")
        let token = try lexer.nextToken()
        #expect(token.type == .boolean)
        #expect(token.text == "true")
        #expect(token.column == 3)
    }

    @Test("Scans multiple booleans")
    func scanMultipleBooleans() throws {
        let lexer = Lexer("true false true")

        let token1 = try lexer.nextToken()
        #expect(token1.type == .boolean)
        #expect(token1.text == "true")

        let token2 = try lexer.nextToken()
        #expect(token2.type == .boolean)
        #expect(token2.text == "false")

        let token3 = try lexer.nextToken()
        #expect(token3.type == .boolean)
        #expect(token3.text == "true")

        let eofToken = try lexer.nextToken()
        #expect(eofToken.type == .eof)
    }

    @Test("Scans booleans mixed with other tokens")
    func scanBooleansMixedWithOtherTokens() throws {
        let lexer = Lexer("true 42 \"hello\" false")

        let token1 = try lexer.nextToken()
        #expect(token1.type == .boolean)
        #expect(token1.text == "true")

        let token2 = try lexer.nextToken()
        #expect(token2.type == .integer)
        #expect(token2.text == "42")

        let token3 = try lexer.nextToken()
        #expect(token3.type == .string)
        #expect(token3.text == "hello")

        let token4 = try lexer.nextToken()
        #expect(token4.type == .boolean)
        #expect(token4.text == "false")
    }

    @Test("Scans identifier starting with reserved word prefix as symbol")
    func scanIdentifierStartingWithReservedPrefix() throws {
        // "truthy" starts with "true" but should be scanned as a symbol
        let lexer = Lexer("truthy")
        let token = try lexer.nextToken()
        #expect(token.type == .symbol)
        #expect(token.text == "truthy")
    }

    // MARK: - Nil literal

    @Test("Scans nil")
    func scanNil() throws {
        let lexer = Lexer("nil")
        let token = try lexer.nextToken()
        #expect(token.type == .nil)
        #expect(token.text == "nil")
        #expect(token.line == 1)
        #expect(token.column == 1)
    }

    @Test("Nil position tracking")
    func nilPositionTracking() throws {
        let lexer = Lexer("  nil")
        let token = try lexer.nextToken()
        #expect(token.type == .nil)
        #expect(token.text == "nil")
        #expect(token.column == 3)
    }

    @Test("Scans nil mixed with other tokens")
    func scanNilMixedWithOtherTokens() throws {
        let lexer = Lexer("nil 42 true")

        let token1 = try lexer.nextToken()
        #expect(token1.type == .nil)
        #expect(token1.text == "nil")

        let token2 = try lexer.nextToken()
        #expect(token2.type == .integer)
        #expect(token2.text == "42")

        let token3 = try lexer.nextToken()
        #expect(token3.type == .boolean)
        #expect(token3.text == "true")
    }

    // MARK: - Keyword literals

    @Test("Scans simple keyword")
    func scanSimpleKeyword() throws {
        let lexer = Lexer(":foo")
        let token = try lexer.nextToken()
        #expect(token.type == .keyword)
        #expect(token.text == "foo")
        #expect(token.line == 1)
        #expect(token.column == 1)
    }

    @Test("Scans keyword with digits")
    func scanKeywordWithDigits() throws {
        let lexer = Lexer(":bar123")
        let token = try lexer.nextToken()
        #expect(token.type == .keyword)
        #expect(token.text == "bar123")
    }

    @Test("Scans hyphenated keyword")
    func scanHyphenatedKeyword() throws {
        let lexer = Lexer(":foo-bar")
        let token = try lexer.nextToken()
        #expect(token.type == .keyword)
        #expect(token.text == "foo-bar")
    }

    @Test("Scans namespaced keyword")
    func scanNamespacedKeyword() throws {
        let lexer = Lexer(":user/name")
        let token = try lexer.nextToken()
        #expect(token.type == .keyword)
        #expect(token.text == "user/name")
    }

    @Test("Scans keyword with dotted namespace")
    func scanKeywordWithDottedNamespace() throws {
        let lexer = Lexer(":my.ns/key")
        let token = try lexer.nextToken()
        #expect(token.type == .keyword)
        #expect(token.text == "my.ns/key")
    }

    @Test("Scans keyword with question mark")
    func scanKeywordWithQuestionMark() throws {
        let lexer = Lexer(":valid?")
        let token = try lexer.nextToken()
        #expect(token.type == .keyword)
        #expect(token.text == "valid?")
    }

    @Test("Scans keyword with bang")
    func scanKeywordWithBang() throws {
        let lexer = Lexer(":swap!")
        let token = try lexer.nextToken()
        #expect(token.type == .keyword)
        #expect(token.text == "swap!")
    }

    @Test(":true is a keyword not a boolean")
    func colonTrueIsKeyword() throws {
        let lexer = Lexer(":true")
        let token = try lexer.nextToken()
        #expect(token.type == .keyword)
        #expect(token.text == "true")
    }

    @Test(":false is a keyword not a boolean")
    func colonFalseIsKeyword() throws {
        let lexer = Lexer(":false")
        let token = try lexer.nextToken()
        #expect(token.type == .keyword)
        #expect(token.text == "false")
    }

    @Test(":nil is a keyword not nil")
    func colonNilIsKeyword() throws {
        let lexer = Lexer(":nil")
        let token = try lexer.nextToken()
        #expect(token.type == .keyword)
        #expect(token.text == "nil")
    }

    @Test("Throws error for keyword starting with number")
    func keywordStartingWithNumberThrows() throws {
        let lexer = Lexer(":123")
        #expect(throws: LexerError.invalidKeyword("keyword cannot start with a number", line: 1, column: 1)) {
            try lexer.nextToken()
        }
    }

    @Test("Throws error for colon alone")
    func colonAloneThrows() throws {
        let lexer = Lexer(":")
        #expect(throws: LexerError.invalidKeyword("expected name after ':'", line: 1, column: 1)) {
            try lexer.nextToken()
        }
    }

    @Test("Throws error for colon followed by whitespace")
    func colonWhitespaceThrows() throws {
        let lexer = Lexer(": foo")
        #expect(throws: LexerError.invalidKeyword("whitespace after ':'", line: 1, column: 1)) {
            try lexer.nextToken()
        }
    }

    @Test("Throws error for auto-resolved keyword")
    func autoResolvedKeywordThrows() throws {
        let lexer = Lexer("::foo")
        #expect(throws: LexerError.unsupportedAutoResolvedKeyword(line: 1, column: 1)) {
            try lexer.nextToken()
        }
    }

    @Test("Keyword position tracking")
    func keywordPositionTracking() throws {
        let lexer = Lexer("  :foo")
        let token = try lexer.nextToken()
        #expect(token.type == .keyword)
        #expect(token.text == "foo")
        #expect(token.column == 3)
    }

    @Test("Scans multiple keywords")
    func scanMultipleKeywords() throws {
        let lexer = Lexer(":foo :bar :baz")

        let token1 = try lexer.nextToken()
        #expect(token1.type == .keyword)
        #expect(token1.text == "foo")

        let token2 = try lexer.nextToken()
        #expect(token2.type == .keyword)
        #expect(token2.text == "bar")

        let token3 = try lexer.nextToken()
        #expect(token3.type == .keyword)
        #expect(token3.text == "baz")

        let eofToken = try lexer.nextToken()
        #expect(eofToken.type == .eof)
    }

    @Test("Scans keywords mixed with other tokens")
    func scanKeywordsMixedWithOtherTokens() throws {
        let lexer = Lexer(":foo 42 \"hello\" :bar")

        let token1 = try lexer.nextToken()
        #expect(token1.type == .keyword)
        #expect(token1.text == "foo")

        let token2 = try lexer.nextToken()
        #expect(token2.type == .integer)
        #expect(token2.text == "42")

        let token3 = try lexer.nextToken()
        #expect(token3.type == .string)
        #expect(token3.text == "hello")

        let token4 = try lexer.nextToken()
        #expect(token4.type == .keyword)
        #expect(token4.text == "bar")
    }

    // MARK: - Parentheses (list delimiters)

    @Test("Scans left paren")
    func scanLeftParen() throws {
        let lexer = Lexer("(")
        let token = try lexer.nextToken()
        #expect(token.type == .leftParen)
        #expect(token.text == "(")
        #expect(token.line == 1)
        #expect(token.column == 1)
    }

    @Test("Scans right paren")
    func scanRightParen() throws {
        let lexer = Lexer(")")
        let token = try lexer.nextToken()
        #expect(token.type == .rightParen)
        #expect(token.text == ")")
        #expect(token.line == 1)
        #expect(token.column == 1)
    }

    @Test("Scans empty parens")
    func scanEmptyParens() throws {
        let lexer = Lexer("()")

        let token1 = try lexer.nextToken()
        #expect(token1.type == .leftParen)
        #expect(token1.text == "(")

        let token2 = try lexer.nextToken()
        #expect(token2.type == .rightParen)
        #expect(token2.text == ")")

        let eofToken = try lexer.nextToken()
        #expect(eofToken.type == .eof)
    }

    @Test("Scans parens with content")
    func scanParensWithContent() throws {
        let lexer = Lexer("(foo 42)")

        let token1 = try lexer.nextToken()
        #expect(token1.type == .leftParen)

        let token2 = try lexer.nextToken()
        #expect(token2.type == .symbol)
        #expect(token2.text == "foo")

        let token3 = try lexer.nextToken()
        #expect(token3.type == .integer)
        #expect(token3.text == "42")

        let token4 = try lexer.nextToken()
        #expect(token4.type == .rightParen)

        let eofToken = try lexer.nextToken()
        #expect(eofToken.type == .eof)
    }

    @Test("Scans nested parens")
    func scanNestedParens() throws {
        let lexer = Lexer("((")

        let token1 = try lexer.nextToken()
        #expect(token1.type == .leftParen)
        #expect(token1.column == 1)

        let token2 = try lexer.nextToken()
        #expect(token2.type == .leftParen)
        #expect(token2.column == 2)
    }

    @Test("Paren position tracking")
    func parenPositionTracking() throws {
        let lexer = Lexer("  (")
        let token = try lexer.nextToken()
        #expect(token.type == .leftParen)
        #expect(token.column == 3)
    }

    // MARK: - Number terminator validation

    @Test("Binary followed by non-binary digits is an error")
    func binaryFollowedByNonBinaryDigitsIsError() throws {
        let lexer = Lexer("0b111222")
        #expect(throws: LexerError.invalidNumberFormat("0b111222", line: 1, column: 1)) {
            try lexer.nextToken()
        }
    }

    @Test("Octal followed by non-octal digits is an error")
    func octalFollowedByNonOctalDigitsIsError() throws {
        let lexer = Lexer("0o789")
        #expect(throws: LexerError.invalidNumberFormat("0o789", line: 1, column: 1)) {
            try lexer.nextToken()
        }
    }

    @Test("Hex followed by non-hex letters is an error")
    func hexFollowedByNonHexLettersIsError() throws {
        let lexer = Lexer("0xFGH")
        #expect(throws: LexerError.invalidNumberFormat("0xFGH", line: 1, column: 1)) {
            try lexer.nextToken()
        }
    }

    @Test("Decimal followed by letters is an error")
    func decimalFollowedByLettersIsError() throws {
        let lexer = Lexer("123abc")
        #expect(throws: LexerError.invalidNumberFormat("123abc", line: 1, column: 1)) {
            try lexer.nextToken()
        }
    }

    @Test("Binary integer inside parens is valid")
    func binaryIntegerInsideParensIsValid() throws {
        let lexer = Lexer("(0b111)")

        let lp = try lexer.nextToken()
        #expect(lp.type == .leftParen)

        let num = try lexer.nextToken()
        #expect(num.type == .integer)
        #expect(num.text == "0b111")

        let rp = try lexer.nextToken()
        #expect(rp.type == .rightParen)
    }

    @Test("Integer followed by string delimiter is valid")
    func integerFollowedByStringDelimiterIsValid() throws {
        let lexer = Lexer("123\"hello\"")

        let num = try lexer.nextToken()
        #expect(num.type == .integer)
        #expect(num.text == "123")

        let str = try lexer.nextToken()
        #expect(str.type == .string)
        #expect(str.text == "hello")
    }

    // MARK: - Symbol continuation with apostrophe

    @Test("a'b lexes as a single symbol")
    func apostropheInMiddleOfSymbol() throws {
        let lexer = Lexer("a'b")
        let token = try lexer.nextToken()
        #expect(token.type == .symbol)
        #expect(token.text == "a'b")
    }

    @Test("a' lexes as a single symbol")
    func apostropheAtEndOfSymbol() throws {
        let lexer = Lexer("a'")
        let token = try lexer.nextToken()
        #expect(token.type == .symbol)
        #expect(token.text == "a'")
    }

    @Test("'a lexes as quote token then symbol")
    func leadingApostropheRemainsQuoteMacro() throws {
        let lexer = Lexer("'a")
        let quote = try lexer.nextToken()
        #expect(quote.type == .quote)
        let sym = try lexer.nextToken()
        #expect(sym.type == .symbol)
        #expect(sym.text == "a")
    }

    // MARK: - Comma as whitespace

    @Test("Commas are treated as whitespace in a list")
    func commaAsWhitespace() throws {
        let lexer = Lexer("(1,2,3)")
        let lp = try lexer.nextToken()
        #expect(lp.type == .leftParen)
        let one = try lexer.nextToken()
        #expect(one.type == .integer)
        #expect(one.text == "1")
        let two = try lexer.nextToken()
        #expect(two.type == .integer)
        #expect(two.text == "2")
        let three = try lexer.nextToken()
        #expect(three.type == .integer)
        #expect(three.text == "3")
        let rp = try lexer.nextToken()
        #expect(rp.type == .rightParen)
    }
}

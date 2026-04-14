import Testing
@testable import SwishKit

@Suite("Lexer String Tests")
struct LexerStringTests {
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
}

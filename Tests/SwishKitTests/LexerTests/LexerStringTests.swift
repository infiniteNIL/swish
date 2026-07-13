import Testing
@testable import SwishKit

@Suite("Lexer String Tests")
struct LexerStringTests {
    @Test("Scans basic string")
    func scanBasicString() throws {
        #expect(try Lexer("\"hello\"").nextToken() == Token(type: .string, text: "hello", line: 1, column: 1))
    }

    @Test("Scans empty string")
    func scanEmptyString() throws {
        #expect(try Lexer("\"\"").nextToken() == Token(type: .string, text: "", line: 1, column: 1))
    }

    @Test("Scans string with spaces")
    func scanStringWithSpaces() throws {
        #expect(try Lexer("\"hello world\"").nextToken() == Token(type: .string, text: "hello world", line: 1, column: 1))
    }

    @Test("Scans string with escaped quote")
    func scanStringWithEscapedQuote() throws {
        #expect(try Lexer("\"say \\\"hi\\\"\"").nextToken() == Token(type: .string, text: "say \"hi\"", line: 1, column: 1))
    }

    @Test("Scans string with escaped backslash")
    func scanStringWithEscapedBackslash() throws {
        #expect(try Lexer("\"a\\\\b\"").nextToken() == Token(type: .string, text: "a\\b", line: 1, column: 1))
    }

    @Test("Scans string with newline escape")
    func scanStringWithNewlineEscape() throws {
        #expect(try Lexer("\"line1\\nline2\"").nextToken() == Token(type: .string, text: "line1\nline2", line: 1, column: 1))
    }

    @Test("Scans string with tab escape")
    func scanStringWithTabEscape() throws {
        #expect(try Lexer("\"col1\\tcol2\"").nextToken() == Token(type: .string, text: "col1\tcol2", line: 1, column: 1))
    }

    @Test("Scans string with carriage return escape")
    func scanStringWithCarriageReturnEscape() throws {
        #expect(try Lexer("\"line1\\rline2\"").nextToken() == Token(type: .string, text: "line1\rline2", line: 1, column: 1))
    }

    @Test("Scans string with null escape")
    func scanStringWithNullEscape() throws {
        #expect(try Lexer("\"a\\0b\"").nextToken() == Token(type: .string, text: "a\0b", line: 1, column: 1))
    }

    @Test("Scans string with multiple escapes")
    func scanStringWithMultipleEscapes() throws {
        #expect(try Lexer("\"\\\"\\\\\\n\\t\"").nextToken() == Token(type: .string, text: "\"\\\n\t", line: 1, column: 1))
    }

    @Test("Scans multiline string")
    func scanMultilineString() throws {
        #expect(try Lexer("\"line1\nline2\"").nextToken() == Token(type: .string, text: "line1\nline2", line: 1, column: 1))
    }

    @Test("Throws error for unterminated string")
    func unterminatedStringThrows() throws {
        #expect(throws: LexerError.unterminatedString(line: 1, column: 1)) {
            try Lexer("\"hello").nextToken()
        }
    }

    @Test("Throws error for unterminated string at EOF after escape")
    func unterminatedStringAfterEscapeThrows() throws {
        #expect(throws: LexerError.unterminatedString(line: 1, column: 1)) {
            try Lexer("\"hello\\").nextToken()
        }
    }

    @Test("Throws error for invalid escape sequence")
    func invalidEscapeSequenceThrows() throws {
        #expect(throws: LexerError.invalidEscapeSequence(char: "x", line: 1, column: 6)) {
            try Lexer("\"foo\\x\"").nextToken()
        }
    }

    @Test("Scans multiple strings")
    func scanMultipleStrings() throws {
        let lexer = Lexer("\"hello\" \"world\"")
        #expect(try lexer.nextToken() == Token(type: .string, text: "hello", line: 1, column: 1))
        #expect(try lexer.nextToken() == Token(type: .string, text: "world", line: 1, column: 9))
        #expect(try lexer.nextToken().type == .eof)
    }

    @Test("Scans string with numbers")
    func scanStringWithNumbers() throws {
        #expect(try Lexer("\"abc123\"").nextToken() == Token(type: .string, text: "abc123", line: 1, column: 1))
    }

    @Test("String position tracking")
    func stringPositionTracking() throws {
        #expect(try Lexer("  \"hello\"").nextToken() == Token(type: .string, text: "hello", line: 1, column: 3))
    }

    // MARK: - Unicode escape sequences

    @Test("Scans string with Unicode escape - Euro sign")
    func scanStringWithUnicodeEscapeEuro() throws {
        #expect(try Lexer("\"\\u{20AC}\"").nextToken() == Token(type: .string, text: "€", line: 1, column: 1))
    }

    @Test("Scans string with Unicode escape - letter A")
    func scanStringWithUnicodeEscapeA() throws {
        #expect(try Lexer("\"\\u{0041}\"").nextToken() == Token(type: .string, text: "A", line: 1, column: 1))
    }

    @Test("Scans string with Unicode escape - fewer digits")
    func scanStringWithUnicodeEscapeFewerDigits() throws {
        #expect(try Lexer("\"\\u{41}\"").nextToken() == Token(type: .string, text: "A", line: 1, column: 1))
    }

    @Test("Scans string with Unicode escape - emoji")
    func scanStringWithUnicodeEscapeEmoji() throws {
        #expect(try Lexer("\"\\u{1F600}\"").nextToken() == Token(type: .string, text: "😀", line: 1, column: 1))
    }

    @Test("Scans string with Unicode escape - mixed content")
    func scanStringWithUnicodeEscapeMixed() throws {
        #expect(try Lexer("\"Price: \\u{20AC}100\"").nextToken() == Token(type: .string, text: "Price: €100", line: 1, column: 1))
    }

    @Test("Scans string with multiple Unicode escapes")
    func scanStringWithMultipleUnicodeEscapes() throws {
        #expect(try Lexer("\"\\u{41}\\u{42}\\u{43}\"").nextToken() == Token(type: .string, text: "ABC", line: 1, column: 1))
    }

    @Test("Scans string with lowercase hex digits")
    func scanStringWithUnicodeEscapeLowercaseHex() throws {
        #expect(try Lexer("\"\\u{20ac}\"").nextToken() == Token(type: .string, text: "€", line: 1, column: 1))
    }

    @Test("Throws error for Unicode escape missing brace")
    func unicodeEscapeMissingBraceThrows() throws {
        #expect(throws: LexerError.invalidUnicodeEscape("expected 4 hex digits after \\u", line: 1, column: 4)) {
            try Lexer("\"\\u\"").nextToken()
        }
    }

    @Test("Throws error for Unicode escape with no hex digits")
    func unicodeEscapeNoDigitsThrows() throws {
        #expect(throws: LexerError.invalidUnicodeEscape("expected 1-6 hex digits", line: 1, column: 5)) {
            try Lexer("\"\\u{}\"").nextToken()
        }
    }

    @Test("Throws error for Unicode escape with invalid hex digit")
    func unicodeEscapeInvalidHexDigitThrows() throws {
        #expect(throws: LexerError.invalidUnicodeEscape("invalid hex digit", line: 1, column: 5)) {
            try Lexer("\"\\u{GGGG}\"").nextToken()
        }
    }

    @Test("Throws error for Unicode escape with too many digits")
    func unicodeEscapeTooManyDigitsThrows() throws {
        #expect(throws: LexerError.invalidUnicodeEscape("expected 1-6 hex digits", line: 1, column: 12)) {
            try Lexer("\"\\u{1234567}\"").nextToken()
        }
    }

    @Test("Throws error for Unicode escape with surrogate code point")
    func unicodeEscapeSurrogateThrows() throws {
        #expect(throws: LexerError.invalidUnicodeEscape("invalid code point", line: 1, column: 9)) {
            try Lexer("\"\\u{D800}\"").nextToken()
        }
    }

    @Test("Throws error for Unicode escape with code point out of range")
    func unicodeEscapeOutOfRangeThrows() throws {
        #expect(throws: LexerError.invalidUnicodeEscape("invalid code point", line: 1, column: 11)) {
            try Lexer("\"\\u{110000}\"").nextToken()
        }
    }

    @Test("Throws error for unterminated Unicode escape")
    func unicodeEscapeUnterminatedThrows() throws {
        #expect(throws: LexerError.unterminatedString(line: 1, column: 1)) {
            try Lexer("\"\\u{20AC").nextToken()
        }
    }

    // MARK: - Multiline string literals

    @Test("Scans basic multiline string")
    func scanBasicMultilineString() throws {
        #expect(try Lexer("\"\"\"\nhello\n\"\"\"").nextToken() == Token(type: .string, text: "hello", line: 1, column: 1))
    }

    @Test("Scans empty multiline string")
    func scanEmptyMultilineString() throws {
        #expect(try Lexer("\"\"\"\n\"\"\"").nextToken() == Token(type: .string, text: "", line: 1, column: 1))
    }

    @Test("Scans multiline string with multiple lines")
    func scanMultilineStringWithMultipleLines() throws {
        #expect(try Lexer("\"\"\"\nline1\nline2\nline3\n\"\"\"").nextToken() == Token(type: .string, text: "line1\nline2\nline3", line: 1, column: 1))
    }

    @Test("Scans multiline string with indentation stripping")
    func scanMultilineStringIndentationStripping() throws {
        #expect(try Lexer("\"\"\"\n    hello\n    \"\"\"").nextToken() == Token(type: .string, text: "hello", line: 1, column: 1))
    }

    @Test("Scans multiline string preserving relative indentation")
    func scanMultilineStringPreservingRelativeIndentation() throws {
        #expect(try Lexer("\"\"\"\n    line1\n        indented\n    \"\"\"").nextToken() == Token(type: .string, text: "line1\n    indented", line: 1, column: 1))
    }

    @Test("Scans multiline string with unescaped single quote")
    func scanMultilineStringWithSingleQuote() throws {
        #expect(try Lexer("\"\"\"\nSay \"hi\"\n\"\"\"").nextToken() == Token(type: .string, text: "Say \"hi\"", line: 1, column: 1))
    }

    @Test("Scans multiline string with unescaped double quote")
    func scanMultilineStringWithDoubleQuote() throws {
        #expect(try Lexer("\"\"\"\nHe said \"hello\"\n\"\"\"").nextToken() == Token(type: .string, text: "He said \"hello\"", line: 1, column: 1))
    }

    @Test("Scans multiline string with two consecutive quotes")
    func scanMultilineStringWithTwoQuotes() throws {
        #expect(try Lexer("\"\"\"\ntest\"\"end\n\"\"\"").nextToken() == Token(type: .string, text: "test\"\"end", line: 1, column: 1))
    }

    @Test("Scans multiline string with line continuation")
    func scanMultilineStringWithLineContinuation() throws {
        #expect(try Lexer("\"\"\"\nhello \\\nworld\n\"\"\"").nextToken() == Token(type: .string, text: "hello world", line: 1, column: 1))
    }

    @Test("Scans multiline string with escape sequences")
    func scanMultilineStringWithEscapeSequences() throws {
        #expect(try Lexer("\"\"\"\nhello\\nworld\\ttab\n\"\"\"").nextToken() == Token(type: .string, text: "hello\nworld\ttab", line: 1, column: 1))
    }

    @Test("Scans multiline string with Unicode escape")
    func scanMultilineStringWithUnicodeEscape() throws {
        #expect(try Lexer("\"\"\"\nPrice: \\u{20AC}100\n\"\"\"").nextToken() == Token(type: .string, text: "Price: €100", line: 1, column: 1))
    }

    @Test("Scans multiline string with empty lines")
    func scanMultilineStringWithEmptyLines() throws {
        #expect(try Lexer("\"\"\"\nline1\n\nline3\n\"\"\"").nextToken() == Token(type: .string, text: "line1\n\nline3", line: 1, column: 1))
    }

    @Test("Scans multiline string with whitespace-only lines")
    func scanMultilineStringWithWhitespaceOnlyLines() throws {
        #expect(try Lexer("\"\"\"\n    line1\n    \n    line3\n    \"\"\"").nextToken() == Token(type: .string, text: "line1\n\nline3", line: 1, column: 1))
    }

    @Test("Scans multiline string with escaped backslash before newline")
    func scanMultilineStringEscapedBackslashBeforeNewline() throws {
        #expect(try Lexer("\"\"\"\npath\\\\\nnext\n\"\"\"").nextToken() == Token(type: .string, text: "path\\\nnext", line: 1, column: 1))
    }

    @Test("Throws error for content on multiline string opening line")
    func multilineStringContentOnOpeningLineThrows() throws {
        #expect(throws: LexerError.multilineStringContentOnOpeningLine(line: 1, column: 4)) {
            try Lexer("\"\"\"hello\n\"\"\"").nextToken()
        }
    }

    @Test("Throws error for insufficient indentation in multiline string")
    func multilineStringInsufficientIndentationThrows() throws {
        #expect(throws: LexerError.multilineStringInsufficientIndentation(line: 3, column: 1)) {
            try Lexer("\"\"\"\n    line1\n  short\n    \"\"\"").nextToken()
        }
    }

    @Test("Throws error for unterminated multiline string")
    func unterminatedMultilineStringThrows() throws {
        #expect(throws: LexerError.unterminatedMultilineString(line: 1, column: 1)) {
            try Lexer("\"\"\"\nhello").nextToken()
        }
    }

    @Test("Throws error for invalid escape in multiline string")
    func multilineStringInvalidEscapeThrows() throws {
        #expect(throws: LexerError.invalidEscapeSequence(char: "x", line: 1, column: 1)) {
            try Lexer("\"\"\"\n\\x\n\"\"\"").nextToken()
        }
    }

    @Test("Multiline string position tracking")
    func multilineStringPositionTracking() throws {
        #expect(try Lexer("  \"\"\"\n  hello\n  \"\"\"").nextToken() == Token(type: .string, text: "hello", line: 1, column: 3))
    }

    @Test("Scans multiline string with tabs in indentation")
    func scanMultilineStringWithTabIndentation() throws {
        #expect(try Lexer("\"\"\"\n\thello\n\t\"\"\"").nextToken() == Token(type: .string, text: "hello", line: 1, column: 1))
    }

    @Test("Scans multiline string allowing whitespace after opening delimiter")
    func scanMultilineStringWithWhitespaceAfterOpening() throws {
        #expect(try Lexer("\"\"\"   \nhello\n\"\"\"").nextToken() == Token(type: .string, text: "hello", line: 1, column: 1))
    }

    @Test("Scans multiline string with all escape types")
    func scanMultilineStringAllEscapeTypes() throws {
        #expect(try Lexer("\"\"\"\n\\\"\\\\\\n\\t\\r\\0\n\"\"\"").nextToken() == Token(type: .string, text: "\"\\\n\t\r\0", line: 1, column: 1))
    }

    @Test("Scans multiline string with mixed content")
    func scanMultilineStringMixedContent() throws {
        #expect(try Lexer("\"\"\"\n    func hello() {\n        print(\"Hello\")\n    }\n    \"\"\"").nextToken() == Token(type: .string, text: "func hello() {\n    print(\"Hello\")\n}", line: 1, column: 1))
    }

    @Test("Throws error for unterminated multiline string with only opening")
    func unterminatedMultilineStringOnlyOpeningThrows() throws {
        #expect(throws: LexerError.unterminatedMultilineString(line: 1, column: 1)) {
            try Lexer("\"\"\"").nextToken()
        }
    }

    @Test("Scans multiple tokens after multiline string")
    func scanMultipleTokensAfterMultilineString() throws {
        let lexer = Lexer("\"\"\"\nhello\n\"\"\" 42")
        #expect(try lexer.nextToken() == Token(type: .string, text: "hello", line: 1, column: 1))
        #expect(try lexer.nextToken() == Token(type: .integer, text: "42", line: 3, column: 5))
    }
}

import Testing
@testable import SwishKit

@Suite("Lexer Character Tests")
struct LexerCharacterTests {
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
}

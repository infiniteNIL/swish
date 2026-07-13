import Testing
@testable import SwishKit

@Suite("Lexer Character Tests")
struct LexerCharacterTests {
    @Test("Scans simple character - letter")
    func scanSimpleCharacterLetter() throws {
        #expect(try Lexer("\\a").nextToken() == Token(type: .character, text: "a", line: 1, column: 1))
    }

    @Test("Scans simple character - digit")
    func scanSimpleCharacterDigit() throws {
        #expect(try Lexer("\\5").nextToken() == Token(type: .character, text: "5", line: 1, column: 1))
    }

    @Test("Scans simple character - punctuation")
    func scanSimpleCharacterPunctuation() throws {
        #expect(try Lexer("\\!").nextToken() == Token(type: .character, text: "!", line: 1, column: 1))
    }

    @Test("Scans named character - newline")
    func scanNamedCharacterNewline() throws {
        #expect(try Lexer("\\newline").nextToken() == Token(type: .character, text: "\n", line: 1, column: 1))
    }

    @Test("Scans named character - tab")
    func scanNamedCharacterTab() throws {
        #expect(try Lexer("\\tab").nextToken() == Token(type: .character, text: "\t", line: 1, column: 1))
    }

    @Test("Scans named character - space")
    func scanNamedCharacterSpace() throws {
        #expect(try Lexer("\\space").nextToken() == Token(type: .character, text: " ", line: 1, column: 1))
    }

    @Test("Scans named character - return")
    func scanNamedCharacterReturn() throws {
        #expect(try Lexer("\\return").nextToken() == Token(type: .character, text: "\r", line: 1, column: 1))
    }

    @Test("Scans named character - backspace")
    func scanNamedCharacterBackspace() throws {
        #expect(try Lexer("\\backspace").nextToken() == Token(type: .character, text: "\u{0008}", line: 1, column: 1))
    }

    @Test("Scans named character - formfeed")
    func scanNamedCharacterFormfeed() throws {
        #expect(try Lexer("\\formfeed").nextToken() == Token(type: .character, text: "\u{000C}", line: 1, column: 1))
    }

    @Test("Scans Unicode character - euro sign")
    func scanUnicodeCharacterEuro() throws {
        #expect(try Lexer("\\u20AC").nextToken() == Token(type: .character, text: "€", line: 1, column: 1))
    }

    @Test("Scans Unicode character - letter A")
    func scanUnicodeCharacterA() throws {
        #expect(try Lexer("\\u0041").nextToken() == Token(type: .character, text: "A", line: 1, column: 1))
    }

    @Test("Scans Unicode character - smiling face (U+263A)")
    func scanUnicodeCharacterSmilingFace() throws {
        #expect(try Lexer("\\u263A").nextToken() == Token(type: .character, text: "☺", line: 1, column: 1))
    }

    @Test("Single letter n is not newline")
    func singleLetterNIsNotNewline() throws {
        #expect(try Lexer("\\n").nextToken() == Token(type: .character, text: "n", line: 1, column: 1))
    }

    @Test("Single letter t is not tab")
    func singleLetterTIsNotTab() throws {
        #expect(try Lexer("\\t").nextToken() == Token(type: .character, text: "t", line: 1, column: 1))
    }

    @Test("Throws error for backslash at EOF")
    func characterAtEOFThrows() throws {
        #expect(throws: LexerError.invalidCharacterLiteral("unexpected end of input", line: 1, column: 1)) {
            try Lexer("\\").nextToken()
        }
    }

    @Test("Backslash followed by space returns space character")
    func characterBackslashSpace() throws {
        #expect(try Lexer("\\ ").nextToken() == Token(type: .character, text: " ", line: 1, column: 1))
    }

    @Test("Throws error for unknown named character")
    func unknownNamedCharacterThrows() throws {
        #expect(throws: LexerError.unknownNamedCharacter("foo", line: 1, column: 1)) {
            try Lexer("\\foo").nextToken()
        }
    }

    @Test("Character position tracking")
    func characterPositionTracking() throws {
        #expect(try Lexer("  \\a").nextToken() == Token(type: .character, text: "a", line: 1, column: 3))
    }

    @Test("Scans multiple characters in sequence")
    func scanMultipleCharacters() throws {
        let lexer = Lexer("\\a \\b \\c")
        #expect(try lexer.nextToken() == Token(type: .character, text: "a", line: 1, column: 1))
        #expect(try lexer.nextToken() == Token(type: .character, text: "b", line: 1, column: 4))
        #expect(try lexer.nextToken() == Token(type: .character, text: "c", line: 1, column: 7))
        #expect(try lexer.nextToken().type == .eof)
    }

    @Test("Scans mixed characters and other tokens")
    func scanMixedCharactersAndTokens() throws {
        let lexer = Lexer("\\a 42 \"hello\"")
        #expect(try lexer.nextToken() == Token(type: .character, text: "a", line: 1, column: 1))
        #expect(try lexer.nextToken() == Token(type: .integer, text: "42", line: 1, column: 4))
        #expect(try lexer.nextToken() == Token(type: .string, text: "hello", line: 1, column: 7))
    }

    @Test("Scans octal character literal \\o0 (NUL)")
    func scanOctalCharNul() throws {
        #expect(try Lexer("\\o0").nextToken() == Token(type: .character, text: "\0", line: 1, column: 1))
    }

    @Test("Scans octal character literal \\o101 (U+0041 = 'A')")
    func scanOctalCharA() throws {
        #expect(try Lexer("\\o101").nextToken() == Token(type: .character, text: "A", line: 1, column: 1))
    }

    @Test("Scans octal character literal \\o377 (U+00FF = 'ÿ')")
    func scanOctalCharMax() throws {
        #expect(try Lexer("\\o377").nextToken() == Token(type: .character, text: "ÿ", line: 1, column: 1))
    }

    @Test("Throws for octal character with invalid digit \\o8")
    func scanOctalCharInvalidDigit8() throws {
        #expect(throws: (any Error).self) { try Lexer("\\o8").nextToken() }
    }

    @Test("Throws for octal character with mixed invalid digit \\o18")
    func scanOctalCharMixedInvalidDigit() throws {
        #expect(throws: (any Error).self) { try Lexer("\\o18").nextToken() }
    }

    @Test("Throws for octal character out of range \\o400")
    func scanOctalCharOutOfRange() throws {
        #expect(throws: (any Error).self) { try Lexer("\\o400").nextToken() }
    }

    @Test("Throws for octal character with too many digits \\o1000")
    func scanOctalCharTooManyDigits() throws {
        #expect(throws: (any Error).self) { try Lexer("\\o1000").nextToken() }
    }

    @Test("Unicode character with lowercase hex")
    func unicodeCharacterLowercaseHex() throws {
        #expect(try Lexer("\\u20ac").nextToken() == Token(type: .character, text: "€", line: 1, column: 1))
    }

    @Test("Throws error for Unicode character with surrogate code point")
    func unicodeCharacterSurrogateThrows() throws {
        #expect(throws: LexerError.invalidCharacterLiteral("invalid Unicode code point \\uD800", line: 1, column: 1)) {
            try Lexer("\\uD800").nextToken()
        }
    }

    @Test("\\u followed by non-hex letters is treated as named character (throws unknownNamedCharacter)")
    func unicodeCharacterNonHexFallsThrough() throws {
        #expect(throws: LexerError.unknownNamedCharacter("uGGGG", line: 1, column: 1)) {
            try Lexer("\\uGGGG").nextToken()
        }
    }
}

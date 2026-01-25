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
}

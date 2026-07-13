import Testing
@testable import SwishKit

@Suite("Lexer Token Tests")
struct LexerTokenTests {
    // MARK: - Parentheses (list delimiters)

    @Test("Scans left paren")
    func scanLeftParen() throws {
        #expect(try Lexer("(").nextToken() == Token(type: .leftParen, text: "(", line: 1, column: 1))
    }

    @Test("Scans right paren")
    func scanRightParen() throws {
        #expect(try Lexer(")").nextToken() == Token(type: .rightParen, text: ")", line: 1, column: 1))
    }

    @Test("Scans empty parens")
    func scanEmptyParens() throws {
        let lexer = Lexer("()")
        #expect(try lexer.nextToken() == Token(type: .leftParen, text: "(", line: 1, column: 1))
        #expect(try lexer.nextToken() == Token(type: .rightParen, text: ")", line: 1, column: 2))
        #expect(try lexer.nextToken().type == .eof)
    }

    @Test("Scans parens with content")
    func scanParensWithContent() throws {
        let lexer = Lexer("(foo 42)")
        #expect(try lexer.nextToken() == Token(type: .leftParen, text: "(", line: 1, column: 1))
        #expect(try lexer.nextToken() == Token(type: .symbol, text: "foo", line: 1, column: 2))
        #expect(try lexer.nextToken() == Token(type: .integer, text: "42", line: 1, column: 6))
        #expect(try lexer.nextToken() == Token(type: .rightParen, text: ")", line: 1, column: 8))
        #expect(try lexer.nextToken().type == .eof)
    }

    @Test("Scans nested parens")
    func scanNestedParens() throws {
        let lexer = Lexer("((")
        #expect(try lexer.nextToken() == Token(type: .leftParen, text: "(", line: 1, column: 1))
        #expect(try lexer.nextToken() == Token(type: .leftParen, text: "(", line: 1, column: 2))
    }

    @Test("Paren position tracking")
    func parenPositionTracking() throws {
        #expect(try Lexer("  (").nextToken() == Token(type: .leftParen, text: "(", line: 1, column: 3))
    }

    // MARK: - Number terminator validation

    @Test("Binary followed by non-binary digits is an error")
    func binaryFollowedByNonBinaryDigitsIsError() throws {
        #expect(throws: LexerError.invalidNumberFormat("0b111222", line: 1, column: 1)) {
            try Lexer("0b111222").nextToken()
        }
    }

    @Test("Octal followed by non-octal digits is an error")
    func octalFollowedByNonOctalDigitsIsError() throws {
        #expect(throws: LexerError.invalidNumberFormat("0o789", line: 1, column: 1)) {
            try Lexer("0o789").nextToken()
        }
    }

    @Test("Hex followed by non-hex letters is an error")
    func hexFollowedByNonHexLettersIsError() throws {
        #expect(throws: LexerError.invalidNumberFormat("0xFGH", line: 1, column: 1)) {
            try Lexer("0xFGH").nextToken()
        }
    }

    @Test("Decimal followed by letters is an error")
    func decimalFollowedByLettersIsError() throws {
        #expect(throws: LexerError.invalidNumberFormat("123abc", line: 1, column: 1)) {
            try Lexer("123abc").nextToken()
        }
    }

    @Test("Binary integer inside parens is valid")
    func binaryIntegerInsideParensIsValid() throws {
        let lexer = Lexer("(0b111)")
        #expect(try lexer.nextToken() == Token(type: .leftParen, text: "(", line: 1, column: 1))
        #expect(try lexer.nextToken() == Token(type: .integer, text: "0b111", line: 1, column: 2))
        #expect(try lexer.nextToken() == Token(type: .rightParen, text: ")", line: 1, column: 7))
    }

    @Test("Integer followed by string delimiter is valid")
    func integerFollowedByStringDelimiterIsValid() throws {
        let lexer = Lexer("123\"hello\"")
        #expect(try lexer.nextToken() == Token(type: .integer, text: "123", line: 1, column: 1))
        #expect(try lexer.nextToken() == Token(type: .string, text: "hello", line: 1, column: 4))
    }

    // MARK: - Symbol continuation with apostrophe

    @Test("a'b lexes as a single symbol")
    func apostropheInMiddleOfSymbol() throws {
        #expect(try Lexer("a'b").nextToken() == Token(type: .symbol, text: "a'b", line: 1, column: 1))
    }

    @Test("a' lexes as a single symbol")
    func apostropheAtEndOfSymbol() throws {
        #expect(try Lexer("a'").nextToken() == Token(type: .symbol, text: "a'", line: 1, column: 1))
    }

    @Test("'a lexes as quote token then symbol")
    func leadingApostropheRemainsQuoteMacro() throws {
        let lexer = Lexer("'a")
        #expect(try lexer.nextToken() == Token(type: .quote, text: "'", line: 1, column: 1))
        #expect(try lexer.nextToken() == Token(type: .symbol, text: "a", line: 1, column: 2))
    }

    // MARK: - Unquote reader macros

    @Test("~ produces unquote token")
    func tildeProducesUnquoteToken() throws {
        #expect(try Lexer("~").nextToken() == Token(type: .unquote, text: "~", line: 1, column: 1))
    }

    @Test("~@ produces unquoteSplicing token")
    func tildeAtProducesUnquoteSplicingToken() throws {
        #expect(try Lexer("~@").nextToken() == Token(type: .unquoteSplicing, text: "~@", line: 1, column: 1))
    }

    @Test("~a lexes as unquote token then symbol")
    func unquoteFollowedBySymbol() throws {
        let lexer = Lexer("~a")
        #expect(try lexer.nextToken() == Token(type: .unquote, text: "~", line: 1, column: 1))
        #expect(try lexer.nextToken() == Token(type: .symbol, text: "a", line: 1, column: 2))
    }

    @Test("~@xs lexes as unquoteSplicing token then symbol")
    func unquoteSplicingFollowedBySymbol() throws {
        let lexer = Lexer("~@xs")
        #expect(try lexer.nextToken() == Token(type: .unquoteSplicing, text: "~@", line: 1, column: 1))
        #expect(try lexer.nextToken() == Token(type: .symbol, text: "xs", line: 1, column: 3))
    }

    @Test("unquote token has correct position")
    func unquoteTokenPosition() throws {
        #expect(try Lexer("~x").nextToken() == Token(type: .unquote, text: "~", line: 1, column: 1))
    }

    @Test("unquoteSplicing token has correct position")
    func unquoteSplicingTokenPosition() throws {
        #expect(try Lexer("~@x").nextToken() == Token(type: .unquoteSplicing, text: "~@", line: 1, column: 1))
    }

    @Test("~(1 2) lexes as unquote then list tokens")
    func unquoteFollowedByList() throws {
        let lexer = Lexer("~(1 2)")
        #expect(try lexer.nextToken() == Token(type: .unquote, text: "~", line: 1, column: 1))
        #expect(try lexer.nextToken() == Token(type: .leftParen, text: "(", line: 1, column: 2))
        #expect(try lexer.nextToken() == Token(type: .integer, text: "1", line: 1, column: 3))
    }

    @Test("~@(xs) lexes as unquoteSplicing then list tokens")
    func unquoteSplicingFollowedByList() throws {
        let lexer = Lexer("~@(xs)")
        #expect(try lexer.nextToken() == Token(type: .unquoteSplicing, text: "~@", line: 1, column: 1))
        #expect(try lexer.nextToken() == Token(type: .leftParen, text: "(", line: 1, column: 3))
    }

    @Test("backtick followed by ~x produces backtick unquote symbol sequence")
    func backtickUnquoteSymbolSequence() throws {
        let lexer = Lexer("`~x")
        #expect(try lexer.nextToken() == Token(type: .backtick, text: "`", line: 1, column: 1))
        #expect(try lexer.nextToken() == Token(type: .unquote, text: "~", line: 1, column: 2))
        #expect(try lexer.nextToken() == Token(type: .symbol, text: "x", line: 1, column: 3))
    }

    // MARK: - Bracket tokens

    @Test("Scans left bracket")
    func scanLeftBracket() throws {
        #expect(try Lexer("[").nextToken() == Token(type: .leftBracket, text: "[", line: 1, column: 1))
    }

    @Test("Scans right bracket")
    func scanRightBracket() throws {
        #expect(try Lexer("]").nextToken() == Token(type: .rightBracket, text: "]", line: 1, column: 1))
    }

    @Test("Scans bracket pair with integers")
    func scanBracketPairWithIntegers() throws {
        let lexer = Lexer("[1 2]")
        #expect(try lexer.nextToken() == Token(type: .leftBracket, text: "[", line: 1, column: 1))
        #expect(try lexer.nextToken() == Token(type: .integer, text: "1", line: 1, column: 2))
        #expect(try lexer.nextToken() == Token(type: .integer, text: "2", line: 1, column: 4))
        #expect(try lexer.nextToken() == Token(type: .rightBracket, text: "]", line: 1, column: 5))
    }

    @Test("Bracket immediately after integer is a separate token")
    func bracketAfterIntegerIsSeparateToken() throws {
        let lexer = Lexer("1[2]")
        #expect(try lexer.nextToken() == Token(type: .integer, text: "1", line: 1, column: 1))
        #expect(try lexer.nextToken() == Token(type: .leftBracket, text: "[", line: 1, column: 2))
    }

    // MARK: - Comma as whitespace

    @Test("Commas are treated as whitespace in a list")
    func commaAsWhitespace() throws {
        let lexer = Lexer("(1,2,3)")
        #expect(try lexer.nextToken() == Token(type: .leftParen, text: "(", line: 1, column: 1))
        #expect(try lexer.nextToken() == Token(type: .integer, text: "1", line: 1, column: 2))
        #expect(try lexer.nextToken() == Token(type: .integer, text: "2", line: 1, column: 4))
        #expect(try lexer.nextToken() == Token(type: .integer, text: "3", line: 1, column: 6))
        #expect(try lexer.nextToken() == Token(type: .rightParen, text: ")", line: 1, column: 7))
    }

    // MARK: - Discard macro

    @Test("#_ produces discard token")
    func hashUnderscoreProducesDiscardToken() throws {
        #expect(try Lexer("#_").nextToken() == Token(type: .discard, text: "#_", line: 1, column: 1))
    }

    // MARK: - Comments

    @Test("Comment-only input returns EOF")
    func commentOnlyReturnsEof() throws {
        #expect(try Lexer("; just a comment").nextToken().type == .eof)
    }

    @Test("Comment before token is skipped")
    func commentBeforeToken() throws {
        #expect(try Lexer("; comment\n42").nextToken() == Token(type: .integer, text: "42", line: 2, column: 1))
    }

    @Test("Inline comment after token is skipped")
    func inlineCommentAfterToken() throws {
        let lexer = Lexer("42 ; comment")
        #expect(try lexer.nextToken() == Token(type: .integer, text: "42", line: 1, column: 1))
        #expect(try lexer.nextToken().type == .eof)
    }

    @Test("Multiple comment lines are all skipped")
    func multipleCommentLines() throws {
        #expect(try Lexer("; a\n; b\n99").nextToken() == Token(type: .integer, text: "99", line: 3, column: 1))
    }

    @Test("Comment at end of file with no trailing newline returns EOF")
    func commentAtEofNoNewline() throws {
        #expect(try Lexer("; no newline").nextToken().type == .eof)
    }
}

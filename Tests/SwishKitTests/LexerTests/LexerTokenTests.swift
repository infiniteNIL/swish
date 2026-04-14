import Testing
@testable import SwishKit

@Suite("Lexer Token Tests")
struct LexerTokenTests {
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

    // MARK: - Unquote reader macros

    @Test("~ produces unquote token")
    func tildeProducesUnquoteToken() throws {
        let lexer = Lexer("~")
        let token = try lexer.nextToken()
        #expect(token.type == .unquote)
        #expect(token.text == "~")
    }

    @Test("~@ produces unquoteSplicing token")
    func tildeAtProducesUnquoteSplicingToken() throws {
        let lexer = Lexer("~@")
        let token = try lexer.nextToken()
        #expect(token.type == .unquoteSplicing)
        #expect(token.text == "~@")
    }

    @Test("~a lexes as unquote token then symbol")
    func unquoteFollowedBySymbol() throws {
        let lexer = Lexer("~a")
        let uq = try lexer.nextToken()
        #expect(uq.type == .unquote)
        let sym = try lexer.nextToken()
        #expect(sym.type == .symbol)
        #expect(sym.text == "a")
    }

    @Test("~@xs lexes as unquoteSplicing token then symbol")
    func unquoteSplicingFollowedBySymbol() throws {
        let lexer = Lexer("~@xs")
        let uqs = try lexer.nextToken()
        #expect(uqs.type == .unquoteSplicing)
        let sym = try lexer.nextToken()
        #expect(sym.type == .symbol)
        #expect(sym.text == "xs")
    }

    @Test("unquote token has correct position")
    func unquoteTokenPosition() throws {
        let lexer = Lexer("~x")
        let token = try lexer.nextToken()
        #expect(token.line == 1)
        #expect(token.column == 1)
    }

    @Test("unquoteSplicing token has correct position")
    func unquoteSplicingTokenPosition() throws {
        let lexer = Lexer("~@x")
        let token = try lexer.nextToken()
        #expect(token.line == 1)
        #expect(token.column == 1)
    }

    @Test("~(1 2) lexes as unquote then list tokens")
    func unquoteFollowedByList() throws {
        let lexer = Lexer("~(1 2)")
        let uq = try lexer.nextToken()
        #expect(uq.type == .unquote)
        let lp = try lexer.nextToken()
        #expect(lp.type == .leftParen)
        let one = try lexer.nextToken()
        #expect(one.type == .integer)
        #expect(one.text == "1")
    }

    @Test("~@(xs) lexes as unquoteSplicing then list tokens")
    func unquoteSplicingFollowedByList() throws {
        let lexer = Lexer("~@(xs)")
        let uqs = try lexer.nextToken()
        #expect(uqs.type == .unquoteSplicing)
        let lp = try lexer.nextToken()
        #expect(lp.type == .leftParen)
    }

    @Test("backtick followed by ~x produces backtick unquote symbol sequence")
    func backtickUnquoteSymbolSequence() throws {
        let lexer = Lexer("`~x")
        let bt = try lexer.nextToken()
        #expect(bt.type == .backtick)
        let uq = try lexer.nextToken()
        #expect(uq.type == .unquote)
        let sym = try lexer.nextToken()
        #expect(sym.type == .symbol)
        #expect(sym.text == "x")
    }

    // MARK: - Bracket tokens

    @Test("Scans left bracket")
    func scanLeftBracket() throws {
        let lexer = Lexer("[")
        let token = try lexer.nextToken()
        #expect(token.type == .leftBracket)
        #expect(token.text == "[")
        #expect(token.line == 1)
        #expect(token.column == 1)
    }

    @Test("Scans right bracket")
    func scanRightBracket() throws {
        let lexer = Lexer("]")
        let token = try lexer.nextToken()
        #expect(token.type == .rightBracket)
        #expect(token.text == "]")
        #expect(token.line == 1)
        #expect(token.column == 1)
    }

    @Test("Scans bracket pair with integers")
    func scanBracketPairWithIntegers() throws {
        let lexer = Lexer("[1 2]")
        let lb = try lexer.nextToken()
        #expect(lb.type == .leftBracket)
        let one = try lexer.nextToken()
        #expect(one.type == .integer)
        #expect(one.text == "1")
        let two = try lexer.nextToken()
        #expect(two.type == .integer)
        #expect(two.text == "2")
        let rb = try lexer.nextToken()
        #expect(rb.type == .rightBracket)
    }

    @Test("Bracket immediately after integer is a separate token")
    func bracketAfterIntegerIsSeparateToken() throws {
        let lexer = Lexer("1[2]")
        let one = try lexer.nextToken()
        #expect(one.type == .integer)
        #expect(one.text == "1")
        let lb = try lexer.nextToken()
        #expect(lb.type == .leftBracket)
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

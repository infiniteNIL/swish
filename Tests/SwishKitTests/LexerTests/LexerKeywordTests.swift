import Testing
@testable import SwishKit

@Suite("Lexer Keyword Tests")
struct LexerKeywordTests {
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
}

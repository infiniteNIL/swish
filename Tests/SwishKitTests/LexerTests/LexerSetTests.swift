import Testing
@testable import SwishKit

@Suite("Lexer Set Tests")
struct LexerSetTests {
    @Test("Lexes left-set token")
    func lexLeftSet() throws {
        let lexer = Lexer("#{")
        let token = try lexer.nextToken()
        #expect(token == Token(type: .leftSet, text: "#{", line: 1, column: 1))
    }

    @Test("Lexes empty set")
    func lexEmptySet() throws {
        let lexer = Lexer("#{}")
        let t1 = try lexer.nextToken()
        let t2 = try lexer.nextToken()
        let t3 = try lexer.nextToken()
        #expect(t1 == Token(type: .leftSet, text: "#{", line: 1, column: 1))
        #expect(t2 == Token(type: .rightBrace, text: "}", line: 1, column: 3))
        #expect(t3.type == .eof)
    }

    @Test("Lexes set with integer elements")
    func lexSetWithIntegers() throws {
        let lexer = Lexer("#{1 2 3}")
        let tokens = try [
            lexer.nextToken(),
            lexer.nextToken(),
            lexer.nextToken(),
            lexer.nextToken(),
            lexer.nextToken(),
        ]
        #expect(tokens[0] == Token(type: .leftSet, text: "#{", line: 1, column: 1))
        #expect(tokens[1] == Token(type: .integer, text: "1", line: 1, column: 3))
        #expect(tokens[2] == Token(type: .integer, text: "2", line: 1, column: 5))
        #expect(tokens[3] == Token(type: .integer, text: "3", line: 1, column: 7))
        #expect(tokens[4] == Token(type: .rightBrace, text: "}", line: 1, column: 8))
    }

    @Test("Lexes set with keyword element")
    func lexSetWithKeyword() throws {
        let lexer = Lexer("#{:a}")
        let t1 = try lexer.nextToken()
        let t2 = try lexer.nextToken()
        let t3 = try lexer.nextToken()
        #expect(t1 == Token(type: .leftSet, text: "#{", line: 1, column: 1))
        #expect(t2 == Token(type: .keyword, text: "a", line: 1, column: 3))
        #expect(t3 == Token(type: .rightBrace, text: "}", line: 1, column: 5))
    }
}

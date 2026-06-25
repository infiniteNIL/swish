import Testing
@testable import SwishKit

@Suite("Lexer Anonymous Fn Tests")
struct LexerAnonymousFnTests {
    @Test("Lexes anonymousFn token")
    func lexAnonymousFn() throws {
        let lexer = Lexer("#(")
        let token = try lexer.nextToken()
        #expect(token == Token(type: .anonymousFn, text: "#(", line: 1, column: 1))
    }

    @Test("Lexes #( with offset column")
    func lexAnonymousFnColumn() throws {
        let lexer = Lexer("  #(")
        let token = try lexer.nextToken()
        #expect(token == Token(type: .anonymousFn, text: "#(", line: 1, column: 3))
    }

    @Test("Lexes full #( token sequence")
    func lexAnonymousFnSequence() throws {
        let lexer = Lexer("#(+ 1 2)")
        let tokens = try [
            lexer.nextToken(),
            lexer.nextToken(),
            lexer.nextToken(),
            lexer.nextToken(),
            lexer.nextToken(),
        ]
        #expect(tokens[0] == Token(type: .anonymousFn, text: "#(", line: 1, column: 1))
        #expect(tokens[1] == Token(type: .symbol, text: "+", line: 1, column: 3))
        #expect(tokens[2] == Token(type: .integer, text: "1", line: 1, column: 5))
        #expect(tokens[3] == Token(type: .integer, text: "2", line: 1, column: 7))
        #expect(tokens[4] == Token(type: .rightParen, text: ")", line: 1, column: 8))
    }

    @Test("Lexes % as symbol")
    func lexPercent() throws {
        let lexer = Lexer("%")
        let token = try lexer.nextToken()
        #expect(token == Token(type: .symbol, text: "%", line: 1, column: 1))
    }

    @Test("Lexes %1 as symbol")
    func lexPercent1() throws {
        let lexer = Lexer("%1")
        let token = try lexer.nextToken()
        #expect(token == Token(type: .symbol, text: "%1", line: 1, column: 1))
    }

    @Test("Lexes %2 as symbol")
    func lexPercent2() throws {
        let lexer = Lexer("%2")
        let token = try lexer.nextToken()
        #expect(token == Token(type: .symbol, text: "%2", line: 1, column: 1))
    }

    @Test("Lexes %& as symbol")
    func lexPercentAmpersand() throws {
        let lexer = Lexer("%&")
        let token = try lexer.nextToken()
        #expect(token == Token(type: .symbol, text: "%&", line: 1, column: 1))
    }
}

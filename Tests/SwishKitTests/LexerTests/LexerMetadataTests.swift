import Testing
@testable import SwishKit

@Suite("Lexer Metadata Tests")
struct LexerMetadataTests {
    @Test("Lexes ^ as metadata token")
    func lexCaret() throws {
        let lexer = Lexer("^")
        let token = try lexer.nextToken()
        #expect(token == Token(type: .metadata, text: "^", line: 1, column: 1))
    }

    @Test("Lexes ^:k as metadata token followed by keyword")
    func lexCaretKeyword() throws {
        let lexer = Lexer("^:k")
        let t1 = try lexer.nextToken()
        let t2 = try lexer.nextToken()
        #expect(t1 == Token(type: .metadata, text: "^", line: 1, column: 1))
        #expect(t2 == Token(type: .keyword, text: "k", line: 1, column: 2))
    }
}

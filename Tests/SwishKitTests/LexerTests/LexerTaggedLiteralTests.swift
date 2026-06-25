import Testing
@testable import SwishKit

@Suite("Lexer Tagged Literal Tests")
struct LexerTaggedLiteralTests {
    @Test("# followed by a letter produces a taggedLiteral token")
    func hashFollowedByLetterIsTaggedLiteral() throws {
        let lexer = Lexer("#a")
        let token = try lexer.nextToken()
        #expect(token.type == .taggedLiteral)
        #expect(token.text == "a")
    }

    @Test("Lexes #inst tag as taggedLiteral")
    func lexesInstTag() throws {
        let lexer = Lexer(#"#inst "2024-01-01T00:00:00Z""#)
        let token = try lexer.nextToken()
        #expect(token.type == .taggedLiteral)
        #expect(token.text == "inst")
    }

    @Test("Lexes #uuid tag as taggedLiteral")
    func lexesUuidTag() throws {
        let lexer = Lexer(#"#uuid "f81d4fae-7dec-11d0-a765-00a0c91e6bf6""#)
        let token = try lexer.nextToken()
        #expect(token.type == .taggedLiteral)
        #expect(token.text == "uuid")
    }

    @Test("Tagged literal is followed by a string token")
    func taggedLiteralFollowedByString() throws {
        let lexer = Lexer(#"#inst "2024-01-01T00:00:00Z""#)
        _ = try lexer.nextToken()  // taggedLiteral
        let str = try lexer.nextToken()
        #expect(str.type == .string)
        #expect(str.text == "2024-01-01T00:00:00Z")
    }

    @Test("Lexes qualified tag name")
    func lexesQualifiedTag() throws {
        let lexer = Lexer(#"#my.ns/tag "value""#)
        let token = try lexer.nextToken()
        #expect(token.type == .taggedLiteral)
        #expect(token.text == "my.ns/tag")
    }

    @Test("Still throws for bare # with no following symbol or special char")
    func bareHashThrows() throws {
        let lexer = Lexer("# ")
        #expect(throws: LexerError.self) {
            try lexer.nextToken()
        }
    }

    @Test("taggedLiteral column tracks correctly")
    func taggedLiteralColumn() throws {
        let lexer = Lexer("  #inst")
        let token = try lexer.nextToken()
        #expect(token.type == .taggedLiteral)
        #expect(token.column == 3)
    }
}

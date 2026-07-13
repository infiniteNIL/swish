import Testing
@testable import SwishKit

@Suite("Lexer Namespaced Map Tests")
struct LexerNamespacedMapTests {
    @Test("#:foo{ produces namespacedMapPrefix then leftBrace")
    func namespacedMapSimpleNamespace() throws {
        let lexer = Lexer("#:foo{")
        #expect(try lexer.nextToken() == Token(type: .namespacedMapPrefix, text: "foo", line: 1, column: 1))
        #expect(try lexer.nextToken() == Token(type: .leftBrace, text: "{", line: 1, column: 6))
    }

    @Test("#:foo.bar{ produces namespacedMapPrefix with dotted namespace")
    func namespacedMapDottedNamespace() throws {
        let lexer = Lexer("#:foo.bar{")
        #expect(try lexer.nextToken() == Token(type: .namespacedMapPrefix, text: "foo.bar", line: 1, column: 1))
        #expect(try lexer.nextToken() == Token(type: .leftBrace, text: "{", line: 1, column: 10))
    }
}

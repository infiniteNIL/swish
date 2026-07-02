import Testing
@testable import SwishKit

@Suite("Lexer Namespaced Map Tests")
struct LexerNamespacedMapTests {
    @Test("#:foo{ produces namespacedMapPrefix then leftBrace")
    func namespacedMapSimpleNamespace() throws {
        let lexer = Lexer("#:foo{")
        let prefix = try lexer.nextToken()
        #expect(prefix.type == .namespacedMapPrefix)
        #expect(prefix.text == "foo")
        let brace = try lexer.nextToken()
        #expect(brace.type == .leftBrace)
    }

    @Test("#:foo.bar{ produces namespacedMapPrefix with dotted namespace")
    func namespacedMapDottedNamespace() throws {
        let lexer = Lexer("#:foo.bar{")
        let prefix = try lexer.nextToken()
        #expect(prefix.type == .namespacedMapPrefix)
        #expect(prefix.text == "foo.bar")
        let brace = try lexer.nextToken()
        #expect(brace.type == .leftBrace)
    }
}

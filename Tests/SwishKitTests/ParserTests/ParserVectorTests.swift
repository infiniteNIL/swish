import Testing
@testable import SwishKit

@Suite("Parser Vector Tests")
struct ParserVectorTests {
    @Test("Parses empty vector")
    func parseEmptyVector() throws {
        let lexer = Lexer("[]")
        let parser = try Parser(lexer)
        let exprs = try parser.parse()
        #expect(exprs == [.vector([])])
    }

    @Test("Parses vector with single element")
    func parseVectorWithSingleElement() throws {
        let lexer = Lexer("[42]")
        let parser = try Parser(lexer)
        let exprs = try parser.parse()
        #expect(exprs == [.vector([.integer(42)])])
    }

    @Test("Parses vector with multiple integers")
    func parseVectorWithMultipleIntegers() throws {
        let lexer = Lexer("[1 2 3]")
        let parser = try Parser(lexer)
        let exprs = try parser.parse()
        #expect(exprs == [.vector([.integer(1), .integer(2), .integer(3)])])
    }

    @Test("Parses vector with mixed types")
    func parseVectorWithMixedTypes() throws {
        let lexer = Lexer("[:foo \"bar\" 42]")
        let parser = try Parser(lexer)
        let exprs = try parser.parse()
        #expect(exprs == [.vector([.keyword("foo"), .string("bar"), .integer(42)])])
    }

    @Test("Parses nested vectors")
    func parseNestedVectors() throws {
        let lexer = Lexer("[1 [2 3] 4]")
        let parser = try Parser(lexer)
        let exprs = try parser.parse()
        #expect(exprs == [.vector([.integer(1), .vector([.integer(2), .integer(3)]), .integer(4)])])
    }

    @Test("Parses vector inside list")
    func parseVectorInsideList() throws {
        let lexer = Lexer("(1 [2 3] 4)")
        let parser = try Parser(lexer)
        let exprs = try parser.parse()
        #expect(exprs == [.list([.integer(1), .vector([.integer(2), .integer(3)]), .integer(4)])])
    }

    @Test("Throws unterminatedVector for unclosed bracket")
    func unterminatedVectorThrows() throws {
        let lexer = Lexer("[1 2")
        let parser = try Parser(lexer)
        #expect(throws: ParserError.unterminatedVector(line: 1, column: 1)) {
            try parser.parse()
        }
    }

    @Test("Throws unexpectedToken for bare right bracket")
    func bareRightBracketThrows() throws {
        let lexer = Lexer("]")
        let parser = try Parser(lexer)
        #expect(throws: ParserError.unexpectedToken(Token(type: .rightBracket, text: "]", line: 1, column: 1))) {
            try parser.parse()
        }
    }
}

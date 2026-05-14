import Testing
@testable import SwishKit

@Suite("Parser Map Tests")
struct ParserMapTests {
    @Test("Parses empty map")
    func parseEmptyMap() throws {
        let lexer = Lexer("{}")
        let parser = try Parser(lexer)
        let exprs = try parser.parse()
        #expect(exprs == [.map([:], metadata: nil)])
    }

    @Test("Parses map with single keyword-integer pair")
    func parseMapWithSinglePair() throws {
        let lexer = Lexer("{:a 1}")
        let parser = try Parser(lexer)
        let exprs = try parser.parse()
        #expect(exprs == [.map([.keyword("a"): .integer(1)], metadata: nil)])
    }

    @Test("Parses map with multiple pairs")
    func parseMapWithMultiplePairs() throws {
        let lexer = Lexer("{:a 1 :b 2}")
        let parser = try Parser(lexer)
        let exprs = try parser.parse()
        #expect(exprs == [.map([.keyword("a"): .integer(1), .keyword("b"): .integer(2)], metadata: nil)])
    }

    @Test("Parses map with mixed key types")
    func parseMapWithMixedKeyTypes() throws {
        let lexer = Lexer("{\"name\" :rod 42 true}")
        let parser = try Parser(lexer)
        let exprs = try parser.parse()
        #expect(exprs == [.map([.string("name"): .keyword("rod"), .integer(42): .boolean(true)], metadata: nil)])
    }

    @Test("Parses nested map")
    func parseNestedMap() throws {
        let lexer = Lexer("{:a {:b 2}}")
        let parser = try Parser(lexer)
        let exprs = try parser.parse()
        #expect(exprs == [.map([.keyword("a"): .map([.keyword("b"): .integer(2)], metadata: nil)], metadata: nil)])
    }

    @Test("Parses map inside vector")
    func parseMapInsideVector() throws {
        let lexer = Lexer("[{:a 1}]")
        let parser = try Parser(lexer)
        let exprs = try parser.parse()
        #expect(exprs == [.vector([.map([.keyword("a"): .integer(1)], metadata: nil)], metadata: nil)])
    }

    @Test("Throws unterminatedMap for unclosed brace")
    func unterminatedMapThrows() throws {
        let lexer = Lexer("{:a 1")
        let parser = try Parser(lexer)
        #expect(throws: ParserError.unterminatedMap(line: 1, column: 1)) {
            try parser.parse()
        }
    }

    @Test("Throws oddNumberOfMapForms for odd form count")
    func oddMapFormsThrows() throws {
        let lexer = Lexer("{:a}")
        let parser = try Parser(lexer)
        #expect(throws: ParserError.oddNumberOfMapForms(line: 1, column: 1)) {
            try parser.parse()
        }
    }

    @Test("Throws unexpectedToken for bare right brace")
    func bareRightBraceThrows() throws {
        let lexer = Lexer("}")
        let parser = try Parser(lexer)
        #expect(throws: ParserError.unexpectedToken(Token(type: .rightBrace, text: "}", line: 1, column: 1))) {
            try parser.parse()
        }
    }

    @Test("Duplicate keys — last value wins")
    func duplicateKeysLastWins() throws {
        let lexer = Lexer("{:a 1 :a 2}")
        let parser = try Parser(lexer)
        let exprs = try parser.parse()
        #expect(exprs == [.map([.keyword("a"): .integer(2)], metadata: nil)])
    }
}

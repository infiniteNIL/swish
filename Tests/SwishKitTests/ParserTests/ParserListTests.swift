import Testing
@testable import SwishKit

@Suite("Parser List Tests")
struct ParserListTests {
    @Test("Parses empty list")
    func parseEmptyList() throws {
        let lexer = Lexer("()")
        let parser = try Parser(lexer)
        let exprs = try parser.parse()
        #expect(exprs == [.list([])])
    }

    @Test("Parses list with single element")
    func parseListWithSingleElement() throws {
        let lexer = Lexer("(42)")
        let parser = try Parser(lexer)
        let exprs = try parser.parse()
        #expect(exprs == [.list([.integer(42)])])
    }

    @Test("Parses list with multiple integers")
    func parseListWithMultipleIntegers() throws {
        let lexer = Lexer("(1 2 3)")
        let parser = try Parser(lexer)
        let exprs = try parser.parse()
        #expect(exprs == [.list([.integer(1), .integer(2), .integer(3)])])
    }

    @Test("Parses list with mixed types")
    func parseListWithMixedTypes() throws {
        let lexer = Lexer("(:foo \"bar\" 42)")
        let parser = try Parser(lexer)
        let exprs = try parser.parse()
        #expect(exprs == [.list([.keyword("foo"), .string("bar"), .integer(42)])])
    }

    @Test("Parses nested lists")
    func parseNestedLists() throws {
        let lexer = Lexer("(1 (2 3) 4)")
        let parser = try Parser(lexer)
        let exprs = try parser.parse()
        #expect(exprs == [.list([.integer(1), .list([.integer(2), .integer(3)]), .integer(4)])])
    }

    @Test("Parses deeply nested lists")
    func parseDeeplyNestedLists() throws {
        let lexer = Lexer("(((1)))")
        let parser = try Parser(lexer)
        let exprs = try parser.parse()
        #expect(exprs == [.list([.list([.list([.integer(1)])])])])
    }

    @Test("Parses multiple lists")
    func parseMultipleLists() throws {
        let lexer = Lexer("(1 2) (3 4)")
        let parser = try Parser(lexer)
        let exprs = try parser.parse()
        #expect(exprs == [.list([.integer(1), .integer(2)]), .list([.integer(3), .integer(4)])])
    }

    @Test("Parses list with symbols")
    func parseListWithSymbols() throws {
        let lexer = Lexer("(+ 1 2)")
        let parser = try Parser(lexer)
        let exprs = try parser.parse()
        #expect(exprs == [.list([.symbol("+"), .integer(1), .integer(2)])])
    }

    @Test("Parses list mixed with other expressions")
    func parseListMixedWithOtherExpressions() throws {
        let lexer = Lexer("42 (1 2) \"hello\"")
        let parser = try Parser(lexer)
        let exprs = try parser.parse()
        #expect(exprs == [.integer(42), .list([.integer(1), .integer(2)]), .string("hello")])
    }

    @Test("Throws error for unmatched right paren")
    func unmatchedRightParenThrows() throws {
        let lexer = Lexer(")")
        let parser = try Parser(lexer)
        #expect(throws: ParserError.unexpectedToken(Token(type: .rightParen, text: ")", line: 1, column: 1))) {
            try parser.parse()
        }
    }

    @Test("Throws error for unterminated list")
    func unterminatedListThrows() throws {
        let lexer = Lexer("(1 2")
        let parser = try Parser(lexer)
        #expect(throws: ParserError.unterminatedList(line: 1, column: 1)) {
            try parser.parse()
        }
    }

    @Test("Throws error for unterminated nested list")
    func unterminatedNestedListThrows() throws {
        let lexer = Lexer("(1 (2 3)")
        let parser = try Parser(lexer)
        #expect(throws: ParserError.unterminatedList(line: 1, column: 1)) {
            try parser.parse()
        }
    }

    // MARK: - def syntax validation

    @Test("Parses valid def form")
    func parseValidDef() throws {
        let lexer = Lexer("(def x 10)")
        let parser = try Parser(lexer)
        let exprs = try parser.parse()
        #expect(exprs == [.list([.symbol("def"), .symbol("x"), .integer(10)])])
    }

    @Test("Throws error for def with non-symbol first argument")
    func defWithNonSymbolThrows() throws {
        let lexer = Lexer("(def 42 10)")
        let parser = try Parser(lexer)
        #expect(throws: ParserError.invalidDef("first argument to def must be a symbol")) {
            try parser.parse()
        }
    }

    @Test("Parses def with one argument (unbound var)")
    func defWithOneArgumentParses() throws {
        let lexer = Lexer("(def x)")
        let parser = try Parser(lexer)
        let exprs = try parser.parse()
        #expect(exprs == [.list([.symbol("def"), .symbol("x")])])
    }

    @Test("Throws error for def with too many arguments")
    func defWithTooManyArgumentsThrows() throws {
        let lexer = Lexer("(def x 1 2)")
        let parser = try Parser(lexer)
        #expect(throws: ParserError.invalidDef("def requires 1 or 2 arguments")) {
            try parser.parse()
        }
    }
}

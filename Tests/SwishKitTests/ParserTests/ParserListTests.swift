import Testing
@testable import SwishKit

@Suite("Parser List Tests")
struct ParserListTests {
    @Test("Parses empty list")
    func parseEmptyList() throws {
        let lexer = Lexer("()")
        let parser = try Parser(lexer)
        let exprs = try parser.parse()
        #expect(exprs == [.list([], metadata: nil)])
    }

    @Test("Parses list with single element")
    func parseListWithSingleElement() throws {
        let lexer = Lexer("(42)")
        let parser = try Parser(lexer)
        let exprs = try parser.parse()
        #expect(exprs == [.list([.integer(42)], metadata: nil)])
    }

    @Test("Parses list with multiple integers")
    func parseListWithMultipleIntegers() throws {
        let lexer = Lexer("(1 2 3)")
        let parser = try Parser(lexer)
        let exprs = try parser.parse()
        #expect(exprs == [.list([.integer(1), .integer(2), .integer(3)], metadata: nil)])
    }

    @Test("Parses list with mixed types")
    func parseListWithMixedTypes() throws {
        let lexer = Lexer("(:foo \"bar\" 42)")
        let parser = try Parser(lexer)
        let exprs = try parser.parse()
        #expect(exprs == [.list([.keyword("foo"), .string("bar"), .integer(42)], metadata: nil)])
    }

    @Test("Parses nested lists")
    func parseNestedLists() throws {
        let lexer = Lexer("(1 (2 3) 4)")
        let parser = try Parser(lexer)
        let exprs = try parser.parse()
        #expect(exprs == [.list([.integer(1), .list([.integer(2), .integer(3)], metadata: nil), .integer(4)], metadata: nil)])
    }

    @Test("Parses deeply nested lists")
    func parseDeeplyNestedLists() throws {
        let lexer = Lexer("(((1)))")
        let parser = try Parser(lexer)
        let exprs = try parser.parse()
        #expect(exprs == [.list([.list([.list([.integer(1)], metadata: nil)], metadata: nil)], metadata: nil)])
    }

    @Test("Parses multiple lists")
    func parseMultipleLists() throws {
        let lexer = Lexer("(1 2) (3 4)")
        let parser = try Parser(lexer)
        let exprs = try parser.parse()
        #expect(exprs == [.list([.integer(1), .integer(2)], metadata: nil), .list([.integer(3), .integer(4)], metadata: nil)])
    }

    @Test("Parses list with symbols")
    func parseListWithSymbols() throws {
        let lexer = Lexer("(+ 1 2)")
        let parser = try Parser(lexer)
        let exprs = try parser.parse()
        #expect(exprs == [.list([.symbol("+", metadata: nil), .integer(1), .integer(2)], metadata: nil)])
    }

    @Test("Parses list mixed with other expressions")
    func parseListMixedWithOtherExpressions() throws {
        let lexer = Lexer("42 (1 2) \"hello\"")
        let parser = try Parser(lexer)
        let exprs = try parser.parse()
        #expect(exprs == [.integer(42), .list([.integer(1), .integer(2)], metadata: nil), .string("hello")])
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
        #expect(exprs == [.list([.symbol("def", metadata: nil), .symbol("x", metadata: nil), .integer(10)], metadata: nil)])
    }

    @Test("Throws error for def with non-symbol first argument")
    func defWithNonSymbolThrows() throws {
        let lexer = Lexer("(def 42 10)")
        let parser = try Parser(lexer)
        #expect(throws: ParserError.invalidDef("first argument to def must be a symbol", line: 1, column: 1)) {
            try parser.parse()
        }
    }

    @Test("Parses def with one argument (unbound var)")
    func defWithOneArgumentParses() throws {
        let lexer = Lexer("(def x)")
        let parser = try Parser(lexer)
        let exprs = try parser.parse()
        #expect(exprs == [.list([.symbol("def", metadata: nil), .symbol("x", metadata: nil)], metadata: nil)])
    }

    @Test("Throws error for def with too many arguments")
    func defWithTooManyArgumentsThrows() throws {
        let lexer = Lexer("(def x \"doc\" 1 2)")
        let parser = try Parser(lexer)
        #expect(throws: ParserError.invalidDef("def requires 1 to 3 arguments", line: 1, column: 1)) {
            try parser.parse()
        }
    }
}

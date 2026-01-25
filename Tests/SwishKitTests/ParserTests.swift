import Testing
@testable import SwishKit

@Suite("Parser Tests")
struct ParserTests {
    @Test("Parses integer")
    func parseInteger() throws {
        let lexer = Lexer("42")
        let parser = try Parser(lexer)
        let expr = try parser.parse()
        #expect(expr == .integer(.int(42)))
    }

    @Test("Parses negative integer")
    func parseNegativeInteger() throws {
        let lexer = Lexer("-17")
        let parser = try Parser(lexer)
        let expr = try parser.parse()
        #expect(expr == .integer(.int(-17)))
    }

    @Test("Parses positive integer with plus sign")
    func parsePositiveInteger() throws {
        let lexer = Lexer("+5")
        let parser = try Parser(lexer)
        let expr = try parser.parse()
        #expect(expr == .integer(.int(5)))
    }

    @Test("Parses zero")
    func parseZero() throws {
        let lexer = Lexer("0")
        let parser = try Parser(lexer)
        let expr = try parser.parse()
        #expect(expr == .integer(.int(0)))
    }

    @Test("Throws unexpectedEOF for empty input")
    func emptyInputThrowsUnexpectedEOF() throws {
        let lexer = Lexer("")
        let parser = try Parser(lexer)
        #expect(throws: ParserError.unexpectedEOF) {
            try parser.parse()
        }
    }

    @Test("Throws unexpectedEOF for whitespace-only input")
    func whitespaceOnlyThrowsUnexpectedEOF() throws {
        let lexer = Lexer("   \n\t  ")
        let parser = try Parser(lexer)
        #expect(throws: ParserError.unexpectedEOF) {
            try parser.parse()
        }
    }

    @Test("Lexer error propagates through parser init")
    func lexerErrorPropagates() throws {
        let lexer = Lexer("abc")
        #expect(throws: LexerError.illegalCharacter("a", line: 1, column: 1)) {
            try Parser(lexer)
        }
    }
}

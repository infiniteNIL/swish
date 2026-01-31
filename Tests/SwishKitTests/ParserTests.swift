import Testing
@testable import SwishKit

@Suite("Parser Tests")
struct ParserTests {
    @Test("Parses integer")
    func parseInteger() throws {
        let lexer = Lexer("42")
        let parser = try Parser(lexer)
        let exprs = try parser.parse()
        #expect(exprs == [.integer(42)])
    }

    @Test("Parses negative integer")
    func parseNegativeInteger() throws {
        let lexer = Lexer("-17")
        let parser = try Parser(lexer)
        let exprs = try parser.parse()
        #expect(exprs == [.integer(-17)])
    }

    @Test("Parses positive integer with plus sign")
    func parsePositiveInteger() throws {
        let lexer = Lexer("+5")
        let parser = try Parser(lexer)
        let exprs = try parser.parse()
        #expect(exprs == [.integer(5)])
    }

    @Test("Parses zero")
    func parseZero() throws {
        let lexer = Lexer("0")
        let parser = try Parser(lexer)
        let exprs = try parser.parse()
        #expect(exprs == [.integer(0)])
    }

    @Test("Parses multiple integers")
    func parseMultipleIntegers() throws {
        let lexer = Lexer("1 2 3")
        let parser = try Parser(lexer)
        let exprs = try parser.parse()
        #expect(exprs == [.integer(1), .integer(2), .integer(3)])
    }

    @Test("Returns empty array for empty input")
    func emptyInputReturnsEmptyArray() throws {
        let lexer = Lexer("")
        let parser = try Parser(lexer)
        let exprs = try parser.parse()
        #expect(exprs == [])
    }

    @Test("Returns empty array for whitespace-only input")
    func whitespaceOnlyReturnsEmptyArray() throws {
        let lexer = Lexer("   \n\t  ")
        let parser = try Parser(lexer)
        let exprs = try parser.parse()
        #expect(exprs == [])
    }

    @Test("Lexer error propagates through parser init")
    func lexerErrorPropagates() throws {
        let lexer = Lexer("abc")
        #expect(throws: LexerError.illegalCharacter("a", line: 1, column: 1)) {
            try Parser(lexer)
        }
    }

    // MARK: - Hexadecimal integer literals

    @Test("Parses hex integer")
    func parseHexInteger() throws {
        let lexer = Lexer("0xFF")
        let parser = try Parser(lexer)
        let exprs = try parser.parse()
        #expect(exprs == [.integer(255)])
    }

    @Test("Parses negative hex integer")
    func parseNegativeHexInteger() throws {
        let lexer = Lexer("-0x10")
        let parser = try Parser(lexer)
        let exprs = try parser.parse()
        #expect(exprs == [.integer(-16)])
    }

    @Test("Parses positive hex integer with plus sign")
    func parsePositiveHexInteger() throws {
        let lexer = Lexer("+0x10")
        let parser = try Parser(lexer)
        let exprs = try parser.parse()
        #expect(exprs == [.integer(16)])
    }

    @Test("Parses hex zero")
    func parseHexZero() throws {
        let lexer = Lexer("0x0")
        let parser = try Parser(lexer)
        let exprs = try parser.parse()
        #expect(exprs == [.integer(0)])
    }

    @Test("Parses lowercase hex digits")
    func parseLowercaseHex() throws {
        let lexer = Lexer("0x0a")
        let parser = try Parser(lexer)
        let exprs = try parser.parse()
        #expect(exprs == [.integer(10)])
    }

    // MARK: - Binary integer literals

    @Test("Parses binary integer")
    func parseBinaryInteger() throws {
        let lexer = Lexer("0b1010")
        let parser = try Parser(lexer)
        let exprs = try parser.parse()
        #expect(exprs == [.integer(10)])
    }

    @Test("Parses negative binary integer")
    func parseNegativeBinaryInteger() throws {
        let lexer = Lexer("-0b1010")
        let parser = try Parser(lexer)
        let exprs = try parser.parse()
        #expect(exprs == [.integer(-10)])
    }

    @Test("Parses positive binary integer with plus sign")
    func parsePositiveBinaryInteger() throws {
        let lexer = Lexer("+0b100")
        let parser = try Parser(lexer)
        let exprs = try parser.parse()
        #expect(exprs == [.integer(4)])
    }

    @Test("Parses binary zero")
    func parseBinaryZero() throws {
        let lexer = Lexer("0b0")
        let parser = try Parser(lexer)
        let exprs = try parser.parse()
        #expect(exprs == [.integer(0)])
    }
}

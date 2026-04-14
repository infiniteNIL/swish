import Testing
@testable import SwishKit

@Suite("Parser Float Tests")
struct ParserFloatTests {
    // MARK: - Floating point literals

    @Test("Parses basic float")
    func parseBasicFloat() throws {
        let lexer = Lexer("1.5")
        let parser = try Parser(lexer)
        let exprs = try parser.parse()
        #expect(exprs == [.float(1.5)])
    }

    @Test("Parses negative float")
    func parseNegativeFloat() throws {
        let lexer = Lexer("-3.14")
        let parser = try Parser(lexer)
        let exprs = try parser.parse()
        #expect(exprs == [.float(-3.14)])
    }

    @Test("Parses positive float with plus sign")
    func parsePositiveFloat() throws {
        let lexer = Lexer("+3.14")
        let parser = try Parser(lexer)
        let exprs = try parser.parse()
        #expect(exprs == [.float(3.14)])
    }

    @Test("Parses float with exponent")
    func parseFloatWithExponent() throws {
        let lexer = Lexer("1.5e2")
        let parser = try Parser(lexer)
        let exprs = try parser.parse()
        #expect(exprs == [.float(150.0)])
    }

    @Test("Parses float with negative exponent")
    func parseFloatWithNegativeExponent() throws {
        let lexer = Lexer("1e-2")
        let parser = try Parser(lexer)
        let exprs = try parser.parse()
        #expect(exprs == [.float(0.01)])
    }

    @Test("Parses float with uppercase exponent")
    func parseFloatWithUppercaseExponent() throws {
        let lexer = Lexer("2.5E3")
        let parser = try Parser(lexer)
        let exprs = try parser.parse()
        #expect(exprs == [.float(2500.0)])
    }

    @Test("Parses zero point zero")
    func parseZeroPointZero() throws {
        let lexer = Lexer("0.0")
        let parser = try Parser(lexer)
        let exprs = try parser.parse()
        #expect(exprs == [.float(0.0)])
    }

    @Test("Parses multiple floats")
    func parseMultipleFloats() throws {
        let lexer = Lexer("1.5 2.5 3.5")
        let parser = try Parser(lexer)
        let exprs = try parser.parse()
        #expect(exprs == [.float(1.5), .float(2.5), .float(3.5)])
    }

    @Test("Parses mixed integers and floats")
    func parseMixedIntegersAndFloats() throws {
        let lexer = Lexer("1 2.5 3")
        let parser = try Parser(lexer)
        let exprs = try parser.parse()
        #expect(exprs == [.integer(1), .float(2.5), .integer(3)])
    }
}

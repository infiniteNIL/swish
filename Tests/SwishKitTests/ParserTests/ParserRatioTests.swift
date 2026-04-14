import Testing
@testable import SwishKit

@Suite("Parser Ratio Tests")
struct ParserRatioTests {
    // MARK: - Ratio literals

    @Test("Parses basic ratio")
    func parseBasicRatio() throws {
        let lexer = Lexer("3/4")
        let parser = try Parser(lexer)
        let exprs = try parser.parse()
        #expect(exprs == [.ratio(Ratio(3, 4))])
    }

    @Test("Parses and reduces ratio")
    func parseAndReducesRatio() throws {
        let lexer = Lexer("10/4")
        let parser = try Parser(lexer)
        let exprs = try parser.parse()
        #expect(exprs == [.ratio(Ratio(5, 2))])
    }

    @Test("Parses negative ratio")
    func parseNegativeRatio() throws {
        let lexer = Lexer("-3/4")
        let parser = try Parser(lexer)
        let exprs = try parser.parse()
        #expect(exprs == [.ratio(Ratio(-3, 4))])
    }

    @Test("Parses positive ratio with plus sign")
    func parsePositiveRatio() throws {
        let lexer = Lexer("+3/4")
        let parser = try Parser(lexer)
        let exprs = try parser.parse()
        #expect(exprs == [.ratio(Ratio(3, 4))])
    }

    @Test("Parses ratio with zero numerator as integer zero")
    func parseRatioZeroNumeratorAsInteger() throws {
        let lexer = Lexer("0/5")
        let parser = try Parser(lexer)
        let exprs = try parser.parse()
        #expect(exprs == [.integer(0)])
    }

    @Test("Parses ratio that reduces to integer")
    func parseRatioReducesToInteger() throws {
        let lexer = Lexer("4/2")
        let parser = try Parser(lexer)
        let exprs = try parser.parse()
        #expect(exprs == [.integer(2)])
    }

    @Test("Parses ratio that reduces to integer via GCD")
    func parseRatioReducesToIntegerViaGCD() throws {
        let lexer = Lexer("6/3")
        let parser = try Parser(lexer)
        let exprs = try parser.parse()
        #expect(exprs == [.integer(2)])
    }

    @Test("Parses ratio with underscores that reduces to integer")
    func parseRatioWithUnderscoresReducesToInteger() throws {
        let lexer = Lexer("1_000/4")
        let parser = try Parser(lexer)
        let exprs = try parser.parse()
        #expect(exprs == [.integer(250)])
    }

    @Test("Parses multiple ratios")
    func parseMultipleRatios() throws {
        let lexer = Lexer("1/2 3/4")
        let parser = try Parser(lexer)
        let exprs = try parser.parse()
        #expect(exprs == [.ratio(Ratio(1, 2)), .ratio(Ratio(3, 4))])
    }

    @Test("Parses mixed integers, floats, and ratios")
    func parseMixedIntegersFloatsAndRatios() throws {
        let lexer = Lexer("1 1.5 1/2")
        let parser = try Parser(lexer)
        let exprs = try parser.parse()
        #expect(exprs == [.integer(1), .float(1.5), .ratio(Ratio(1, 2))])
    }
}

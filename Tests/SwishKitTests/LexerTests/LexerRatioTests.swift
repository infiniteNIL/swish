import Testing
@testable import SwishKit

@Suite("Lexer Ratio Tests")
struct LexerRatioTests {
    @Test("Scans basic ratio")
    func scanBasicRatio() throws {
        let lexer = Lexer("3/4")
        let token = try lexer.nextToken()
        #expect(token.type == .ratio)
        #expect(token.text == "3/4")
    }

    @Test("Scans ratio with larger numbers")
    func scanRatioLargerNumbers() throws {
        let lexer = Lexer("10/4")
        let token = try lexer.nextToken()
        #expect(token.type == .ratio)
        #expect(token.text == "10/4")
    }

    @Test("Scans negative ratio")
    func scanNegativeRatio() throws {
        let lexer = Lexer("-3/4")
        let token = try lexer.nextToken()
        #expect(token.type == .ratio)
        #expect(token.text == "-3/4")
    }

    @Test("Scans positive ratio with plus sign")
    func scanPositiveRatio() throws {
        let lexer = Lexer("+3/4")
        let token = try lexer.nextToken()
        #expect(token.type == .ratio)
        #expect(token.text == "+3/4")
    }

    @Test("Scans ratio with zero numerator")
    func scanRatioZeroNumerator() throws {
        let lexer = Lexer("0/5")
        let token = try lexer.nextToken()
        #expect(token.type == .ratio)
        #expect(token.text == "0/5")
    }

    @Test("Scans ratio with underscores in numerator")
    func scanRatioWithUnderscoresInNumerator() throws {
        let lexer = Lexer("1_000/4")
        let token = try lexer.nextToken()
        #expect(token.type == .ratio)
        #expect(token.text == "1000/4")
    }

    @Test("Scans ratio with underscores in denominator")
    func scanRatioWithUnderscoresInDenominator() throws {
        let lexer = Lexer("3/1_000")
        let token = try lexer.nextToken()
        #expect(token.type == .ratio)
        #expect(token.text == "3/1000")
    }

    @Test("Scans ratio with underscores in both parts")
    func scanRatioWithUnderscoresInBothParts() throws {
        let lexer = Lexer("1_000/2_000")
        let token = try lexer.nextToken()
        #expect(token.type == .ratio)
        #expect(token.text == "1000/2000")
    }

    @Test("Throws error for ratio with zero denominator")
    func ratioZeroDenominatorThrows() throws {
        let lexer = Lexer("3/0")
        #expect(throws: LexerError.invalidRatio("3/0", line: 1, column: 1)) {
            try lexer.nextToken()
        }
    }

    @Test("Throws error for trailing underscore in ratio denominator")
    func ratioTrailingUnderscoreInDenominatorThrows() throws {
        let lexer = Lexer("3/4_")
        #expect(throws: LexerError.invalidNumberFormat("3/4_", line: 1, column: 1)) {
            try lexer.nextToken()
        }
    }

    @Test("Throws error for consecutive underscores in ratio denominator")
    func ratioConsecutiveUnderscoresInDenominatorThrows() throws {
        let lexer = Lexer("3/4__5")
        #expect(throws: LexerError.invalidNumberFormat("3/4__", line: 1, column: 1)) {
            try lexer.nextToken()
        }
    }

    @Test("Scans multiple ratios")
    func scanMultipleRatios() throws {
        let lexer = Lexer("1/2 3/4 5/6")

        let token1 = try lexer.nextToken()
        #expect(token1.type == .ratio)
        #expect(token1.text == "1/2")

        let token2 = try lexer.nextToken()
        #expect(token2.type == .ratio)
        #expect(token2.text == "3/4")

        let token3 = try lexer.nextToken()
        #expect(token3.type == .ratio)
        #expect(token3.text == "5/6")

        let eofToken = try lexer.nextToken()
        #expect(eofToken.type == .eof)
    }
}

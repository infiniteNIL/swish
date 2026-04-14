import Testing
@testable import SwishKit

@Suite("Lexer Symbol Tests")
struct LexerSymbolTests {
    @Test("Scans simple symbol")
    func scanSimpleSymbol() throws {
        let lexer = Lexer("foo")
        let token = try lexer.nextToken()
        #expect(token.type == .symbol)
        #expect(token.text == "foo")
        #expect(token.line == 1)
        #expect(token.column == 1)
    }

    @Test("Scans symbol with digits")
    func scanSymbolWithDigits() throws {
        let lexer = Lexer("foo123")
        let token = try lexer.nextToken()
        #expect(token.type == .symbol)
        #expect(token.text == "foo123")
    }

    @Test("Scans hyphenated symbol")
    func scanHyphenatedSymbol() throws {
        let lexer = Lexer("foo-bar")
        let token = try lexer.nextToken()
        #expect(token.type == .symbol)
        #expect(token.text == "foo-bar")
    }

    @Test("Scans symbol starting with hyphen")
    func scanSymbolStartingWithHyphen() throws {
        let lexer = Lexer("-bar")
        let token = try lexer.nextToken()
        #expect(token.type == .symbol)
        #expect(token.text == "-bar")
    }

    @Test("Scans lone plus as symbol")
    func scanLonePlusAsSymbol() throws {
        let lexer = Lexer("+")
        let token = try lexer.nextToken()
        #expect(token.type == .symbol)
        #expect(token.text == "+")
    }

    @Test("Scans lone minus as symbol")
    func scanLoneMinusAsSymbol() throws {
        let lexer = Lexer("-")
        let token = try lexer.nextToken()
        #expect(token.type == .symbol)
        #expect(token.text == "-")
    }

    @Test("Scans symbol with special start chars")
    func scanSymbolWithSpecialStartChars() throws {
        let lexer = Lexer("*foo*")
        let token = try lexer.nextToken()
        #expect(token.type == .symbol)
        #expect(token.text == "*foo*")
    }

    @Test("Scans question mark symbol")
    func scanQuestionMarkSymbol() throws {
        let lexer = Lexer("empty?")
        let token = try lexer.nextToken()
        #expect(token.type == .symbol)
        #expect(token.text == "empty?")
    }

    @Test("Scans bang symbol")
    func scanBangSymbol() throws {
        let lexer = Lexer("swap!")
        let token = try lexer.nextToken()
        #expect(token.type == .symbol)
        #expect(token.text == "swap!")
    }

    @Test("Scans arrow symbol")
    func scanArrowSymbol() throws {
        let lexer = Lexer("->")
        let token = try lexer.nextToken()
        #expect(token.type == .symbol)
        #expect(token.text == "->")
    }

    @Test("Scans comparison symbols")
    func scanComparisonSymbols() throws {
        let lexer = Lexer("<=>")
        let token = try lexer.nextToken()
        #expect(token.type == .symbol)
        #expect(token.text == "<=>")
    }

    @Test("Scans +foo as symbol")
    func scanPlusFooAsSymbol() throws {
        let lexer = Lexer("+foo")
        let token = try lexer.nextToken()
        #expect(token.type == .symbol)
        #expect(token.text == "+foo")
    }

    @Test("+5 is still an integer")
    func plusFiveIsStillInteger() throws {
        let lexer = Lexer("+5")
        let token = try lexer.nextToken()
        #expect(token.type == .integer)
        #expect(token.text == "+5")
    }

    @Test("-3 is still an integer")
    func minusThreeIsStillInteger() throws {
        let lexer = Lexer("-3")
        let token = try lexer.nextToken()
        #expect(token.type == .integer)
        #expect(token.text == "-3")
    }

    @Test("Scans / as symbol")
    func scanSlashAsSymbol() throws {
        let lexer = Lexer("/")
        let token = try lexer.nextToken()
        #expect(token.type == .symbol)
        #expect(token.text == "/")
    }

    @Test("Scans namespaced symbol")
    func scanNamespacedSymbol() throws {
        let lexer = Lexer("clojure.core/map")
        let token = try lexer.nextToken()
        #expect(token.type == .symbol)
        #expect(token.text == "clojure.core/map")
    }

    @Test("Scans dotted symbol")
    func scanDottedSymbol() throws {
        let lexer = Lexer("java.util.BitSet")
        let token = try lexer.nextToken()
        #expect(token.type == .symbol)
        #expect(token.text == "java.util.BitSet")
    }

    @Test("Scans namespaced symbol with hyphen")
    func scanNamespacedSymbolWithHyphen() throws {
        let lexer = Lexer("my-ns/my-fn")
        let token = try lexer.nextToken()
        #expect(token.type == .symbol)
        #expect(token.text == "my-ns/my-fn")
    }

    @Test("true is still a boolean")
    func trueIsStillBoolean() throws {
        let lexer = Lexer("true")
        let token = try lexer.nextToken()
        #expect(token.type == .boolean)
        #expect(token.text == "true")
    }

    @Test("false is still a boolean")
    func falseIsStillBoolean() throws {
        let lexer = Lexer("false")
        let token = try lexer.nextToken()
        #expect(token.type == .boolean)
        #expect(token.text == "false")
    }

    @Test("nil is still nil")
    func nilIsStillNil() throws {
        let lexer = Lexer("nil")
        let token = try lexer.nextToken()
        #expect(token.type == .nil)
        #expect(token.text == "nil")
    }

    @Test("Scans multiple symbols")
    func scanMultipleSymbols() throws {
        let lexer = Lexer("foo bar baz")

        let token1 = try lexer.nextToken()
        #expect(token1.type == .symbol)
        #expect(token1.text == "foo")

        let token2 = try lexer.nextToken()
        #expect(token2.type == .symbol)
        #expect(token2.text == "bar")

        let token3 = try lexer.nextToken()
        #expect(token3.type == .symbol)
        #expect(token3.text == "baz")

        let eofToken = try lexer.nextToken()
        #expect(eofToken.type == .eof)
    }

    @Test("Scans mixed symbols and numbers")
    func scanMixedSymbolsAndNumbers() throws {
        let lexer = Lexer("foo 42 bar")

        let token1 = try lexer.nextToken()
        #expect(token1.type == .symbol)
        #expect(token1.text == "foo")

        let token2 = try lexer.nextToken()
        #expect(token2.type == .integer)
        #expect(token2.text == "42")

        let token3 = try lexer.nextToken()
        #expect(token3.type == .symbol)
        #expect(token3.text == "bar")
    }

    @Test("Tracks line and column across newlines")
    func positionTrackingAcrossNewlines() throws {
        let lexer = Lexer("\n\n  42")
        let token = try lexer.nextToken()
        #expect(token.type == .integer)
        #expect(token.text == "42")
        #expect(token.line == 3)
        #expect(token.column == 3)
    }

    @Test("Scans multiple integers")
    func scanMultipleIntegers() throws {
        let lexer = Lexer("1 2 3")

        let token1 = try lexer.nextToken()
        #expect(token1.type == .integer)
        #expect(token1.text == "1")
        #expect(token1.column == 1)

        let token2 = try lexer.nextToken()
        #expect(token2.type == .integer)
        #expect(token2.text == "2")
        #expect(token2.column == 3)

        let token3 = try lexer.nextToken()
        #expect(token3.type == .integer)
        #expect(token3.text == "3")
        #expect(token3.column == 5)

        let eofToken = try lexer.nextToken()
        #expect(eofToken.type == .eof)
    }

    // MARK: - Boolean literals

    @Test("Scans true")
    func scanTrue() throws {
        let lexer = Lexer("true")
        let token = try lexer.nextToken()
        #expect(token.type == .boolean)
        #expect(token.text == "true")
        #expect(token.line == 1)
        #expect(token.column == 1)
    }

    @Test("Scans false")
    func scanFalse() throws {
        let lexer = Lexer("false")
        let token = try lexer.nextToken()
        #expect(token.type == .boolean)
        #expect(token.text == "false")
        #expect(token.line == 1)
        #expect(token.column == 1)
    }

    @Test("Boolean position tracking")
    func booleanPositionTracking() throws {
        let lexer = Lexer("  true")
        let token = try lexer.nextToken()
        #expect(token.type == .boolean)
        #expect(token.text == "true")
        #expect(token.column == 3)
    }

    @Test("Scans multiple booleans")
    func scanMultipleBooleans() throws {
        let lexer = Lexer("true false true")

        let token1 = try lexer.nextToken()
        #expect(token1.type == .boolean)
        #expect(token1.text == "true")

        let token2 = try lexer.nextToken()
        #expect(token2.type == .boolean)
        #expect(token2.text == "false")

        let token3 = try lexer.nextToken()
        #expect(token3.type == .boolean)
        #expect(token3.text == "true")

        let eofToken = try lexer.nextToken()
        #expect(eofToken.type == .eof)
    }

    @Test("Scans booleans mixed with other tokens")
    func scanBooleansMixedWithOtherTokens() throws {
        let lexer = Lexer("true 42 \"hello\" false")

        let token1 = try lexer.nextToken()
        #expect(token1.type == .boolean)
        #expect(token1.text == "true")

        let token2 = try lexer.nextToken()
        #expect(token2.type == .integer)
        #expect(token2.text == "42")

        let token3 = try lexer.nextToken()
        #expect(token3.type == .string)
        #expect(token3.text == "hello")

        let token4 = try lexer.nextToken()
        #expect(token4.type == .boolean)
        #expect(token4.text == "false")
    }

    @Test("Scans identifier starting with reserved word prefix as symbol")
    func scanIdentifierStartingWithReservedPrefix() throws {
        // "truthy" starts with "true" but should be scanned as a symbol
        let lexer = Lexer("truthy")
        let token = try lexer.nextToken()
        #expect(token.type == .symbol)
        #expect(token.text == "truthy")
    }

    // MARK: - Nil literal

    @Test("Scans nil")
    func scanNil() throws {
        let lexer = Lexer("nil")
        let token = try lexer.nextToken()
        #expect(token.type == .nil)
        #expect(token.text == "nil")
        #expect(token.line == 1)
        #expect(token.column == 1)
    }

    @Test("Nil position tracking")
    func nilPositionTracking() throws {
        let lexer = Lexer("  nil")
        let token = try lexer.nextToken()
        #expect(token.type == .nil)
        #expect(token.text == "nil")
        #expect(token.column == 3)
    }

    @Test("Scans nil mixed with other tokens")
    func scanNilMixedWithOtherTokens() throws {
        let lexer = Lexer("nil 42 true")

        let token1 = try lexer.nextToken()
        #expect(token1.type == .nil)
        #expect(token1.text == "nil")

        let token2 = try lexer.nextToken()
        #expect(token2.type == .integer)
        #expect(token2.text == "42")

        let token3 = try lexer.nextToken()
        #expect(token3.type == .boolean)
        #expect(token3.text == "true")
    }
}

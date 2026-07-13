import Testing
@testable import SwishKit

@Suite("Lexer Symbol Tests")
struct LexerSymbolTests {
    @Test("Scans simple symbol")
    func scanSimpleSymbol() throws {
        #expect(try Lexer("foo").nextToken() == Token(type: .symbol, text: "foo", line: 1, column: 1))
    }

    @Test("Scans symbol with digits")
    func scanSymbolWithDigits() throws {
        #expect(try Lexer("foo123").nextToken() == Token(type: .symbol, text: "foo123", line: 1, column: 1))
    }

    @Test("Scans hyphenated symbol")
    func scanHyphenatedSymbol() throws {
        #expect(try Lexer("foo-bar").nextToken() == Token(type: .symbol, text: "foo-bar", line: 1, column: 1))
    }

    @Test("Scans symbol starting with hyphen")
    func scanSymbolStartingWithHyphen() throws {
        #expect(try Lexer("-bar").nextToken() == Token(type: .symbol, text: "-bar", line: 1, column: 1))
    }

    @Test("Scans lone plus as symbol")
    func scanLonePlusAsSymbol() throws {
        #expect(try Lexer("+").nextToken() == Token(type: .symbol, text: "+", line: 1, column: 1))
    }

    @Test("Scans lone minus as symbol")
    func scanLoneMinusAsSymbol() throws {
        #expect(try Lexer("-").nextToken() == Token(type: .symbol, text: "-", line: 1, column: 1))
    }

    @Test("Scans symbol with special start chars")
    func scanSymbolWithSpecialStartChars() throws {
        #expect(try Lexer("*foo*").nextToken() == Token(type: .symbol, text: "*foo*", line: 1, column: 1))
    }

    @Test("Scans question mark symbol")
    func scanQuestionMarkSymbol() throws {
        #expect(try Lexer("empty?").nextToken() == Token(type: .symbol, text: "empty?", line: 1, column: 1))
    }

    @Test("Scans bang symbol")
    func scanBangSymbol() throws {
        #expect(try Lexer("swap!").nextToken() == Token(type: .symbol, text: "swap!", line: 1, column: 1))
    }

    @Test("Scans arrow symbol")
    func scanArrowSymbol() throws {
        #expect(try Lexer("->").nextToken() == Token(type: .symbol, text: "->", line: 1, column: 1))
    }

    @Test("Scans comparison symbols")
    func scanComparisonSymbols() throws {
        #expect(try Lexer("<=>").nextToken() == Token(type: .symbol, text: "<=>", line: 1, column: 1))
    }

    @Test("Scans +foo as symbol")
    func scanPlusFooAsSymbol() throws {
        #expect(try Lexer("+foo").nextToken() == Token(type: .symbol, text: "+foo", line: 1, column: 1))
    }

    @Test("+5 is still an integer")
    func plusFiveIsStillInteger() throws {
        #expect(try Lexer("+5").nextToken() == Token(type: .integer, text: "+5", line: 1, column: 1))
    }

    @Test("-3 is still an integer")
    func minusThreeIsStillInteger() throws {
        #expect(try Lexer("-3").nextToken() == Token(type: .integer, text: "-3", line: 1, column: 1))
    }

    @Test("Scans / as symbol")
    func scanSlashAsSymbol() throws {
        #expect(try Lexer("/").nextToken() == Token(type: .symbol, text: "/", line: 1, column: 1))
    }

    @Test("Scans . as symbol")
    func scanDotAsSymbol() throws {
        #expect(try Lexer(".").nextToken() == Token(type: .symbol, text: ".", line: 1, column: 1))
    }

    @Test("Scans namespaced symbol")
    func scanNamespacedSymbol() throws {
        #expect(try Lexer("clojure.core/map").nextToken() == Token(type: .symbol, text: "clojure.core/map", line: 1, column: 1))
    }

    @Test("Scans dotted symbol")
    func scanDottedSymbol() throws {
        #expect(try Lexer("java.util.BitSet").nextToken() == Token(type: .symbol, text: "java.util.BitSet", line: 1, column: 1))
    }

    @Test("Scans namespaced symbol with hyphen")
    func scanNamespacedSymbolWithHyphen() throws {
        #expect(try Lexer("my-ns/my-fn").nextToken() == Token(type: .symbol, text: "my-ns/my-fn", line: 1, column: 1))
    }

    @Test("true is still a boolean")
    func trueIsStillBoolean() throws {
        #expect(try Lexer("true").nextToken() == Token(type: .boolean, text: "true", line: 1, column: 1))
    }

    @Test("false is still a boolean")
    func falseIsStillBoolean() throws {
        #expect(try Lexer("false").nextToken() == Token(type: .boolean, text: "false", line: 1, column: 1))
    }

    @Test("nil is still nil")
    func nilIsStillNil() throws {
        #expect(try Lexer("nil").nextToken() == Token(type: .nil, text: "nil", line: 1, column: 1))
    }

    @Test("Scans multiple symbols")
    func scanMultipleSymbols() throws {
        let lexer = Lexer("foo bar baz")
        #expect(try lexer.nextToken() == Token(type: .symbol, text: "foo", line: 1, column: 1))
        #expect(try lexer.nextToken() == Token(type: .symbol, text: "bar", line: 1, column: 5))
        #expect(try lexer.nextToken() == Token(type: .symbol, text: "baz", line: 1, column: 9))
        #expect(try lexer.nextToken().type == .eof)
    }

    @Test("Scans mixed symbols and numbers")
    func scanMixedSymbolsAndNumbers() throws {
        let lexer = Lexer("foo 42 bar")
        #expect(try lexer.nextToken() == Token(type: .symbol, text: "foo", line: 1, column: 1))
        #expect(try lexer.nextToken() == Token(type: .integer, text: "42", line: 1, column: 5))
        #expect(try lexer.nextToken() == Token(type: .symbol, text: "bar", line: 1, column: 8))
    }

    @Test("Tracks line and column across newlines")
    func positionTrackingAcrossNewlines() throws {
        #expect(try Lexer("\n\n  42").nextToken() == Token(type: .integer, text: "42", line: 3, column: 3))
    }

    @Test("Scans multiple integers")
    func scanMultipleIntegers() throws {
        let lexer = Lexer("1 2 3")
        #expect(try lexer.nextToken() == Token(type: .integer, text: "1", line: 1, column: 1))
        #expect(try lexer.nextToken() == Token(type: .integer, text: "2", line: 1, column: 3))
        #expect(try lexer.nextToken() == Token(type: .integer, text: "3", line: 1, column: 5))
        #expect(try lexer.nextToken().type == .eof)
    }

    // MARK: - Boolean literals

    @Test("Scans true")
    func scanTrue() throws {
        #expect(try Lexer("true").nextToken() == Token(type: .boolean, text: "true", line: 1, column: 1))
    }

    @Test("Scans false")
    func scanFalse() throws {
        #expect(try Lexer("false").nextToken() == Token(type: .boolean, text: "false", line: 1, column: 1))
    }

    @Test("Boolean position tracking")
    func booleanPositionTracking() throws {
        #expect(try Lexer("  true").nextToken() == Token(type: .boolean, text: "true", line: 1, column: 3))
    }

    @Test("Scans multiple booleans")
    func scanMultipleBooleans() throws {
        let lexer = Lexer("true false true")
        #expect(try lexer.nextToken() == Token(type: .boolean, text: "true", line: 1, column: 1))
        #expect(try lexer.nextToken() == Token(type: .boolean, text: "false", line: 1, column: 6))
        #expect(try lexer.nextToken() == Token(type: .boolean, text: "true", line: 1, column: 12))
        #expect(try lexer.nextToken().type == .eof)
    }

    @Test("Scans booleans mixed with other tokens")
    func scanBooleansMixedWithOtherTokens() throws {
        let lexer = Lexer("true 42 \"hello\" false")
        #expect(try lexer.nextToken() == Token(type: .boolean, text: "true", line: 1, column: 1))
        #expect(try lexer.nextToken() == Token(type: .integer, text: "42", line: 1, column: 6))
        #expect(try lexer.nextToken() == Token(type: .string, text: "hello", line: 1, column: 9))
        #expect(try lexer.nextToken() == Token(type: .boolean, text: "false", line: 1, column: 17))
    }

    @Test("Scans identifier starting with reserved word prefix as symbol")
    func scanIdentifierStartingWithReservedPrefix() throws {
        // "truthy" starts with "true" but should be scanned as a symbol
        #expect(try Lexer("truthy").nextToken() == Token(type: .symbol, text: "truthy", line: 1, column: 1))
    }

    // MARK: - Nil literal

    @Test("Scans nil")
    func scanNil() throws {
        #expect(try Lexer("nil").nextToken() == Token(type: .nil, text: "nil", line: 1, column: 1))
    }

    @Test("Nil position tracking")
    func nilPositionTracking() throws {
        #expect(try Lexer("  nil").nextToken() == Token(type: .nil, text: "nil", line: 1, column: 3))
    }

    @Test("Scans nil mixed with other tokens")
    func scanNilMixedWithOtherTokens() throws {
        let lexer = Lexer("nil 42 true")
        #expect(try lexer.nextToken() == Token(type: .nil, text: "nil", line: 1, column: 1))
        #expect(try lexer.nextToken() == Token(type: .integer, text: "42", line: 1, column: 5))
        #expect(try lexer.nextToken() == Token(type: .boolean, text: "true", line: 1, column: 8))
    }

    @Test("Scans foo// as a single symbol (namespace foo, name /)")
    func scanFooDoubleSlash() throws {
        #expect(try Lexer("foo//").nextToken() == Token(type: .symbol, text: "foo//", line: 1, column: 1))
    }

    @Test("foo//bar scans as two tokens: foo// and bar")
    func scanFooDoubleSlashBar() throws {
        let lexer = Lexer("foo//bar")
        #expect(try lexer.nextToken() == Token(type: .symbol, text: "foo//", line: 1, column: 1))
        #expect(try lexer.nextToken() == Token(type: .symbol, text: "bar", line: 1, column: 6))
    }

    @Test(".5 scans as a single symbol token (not a float)")
    func scanLeadingDotDigitAsSymbol() throws {
        #expect(try Lexer(".5").nextToken() == Token(type: .symbol, text: ".5", line: 1, column: 1))
    }

    @Test(".5e2 scans as a single symbol token")
    func scanLeadingDotDigitLetterAsSymbol() throws {
        #expect(try Lexer(".5e2").nextToken() == Token(type: .symbol, text: ".5e2", line: 1, column: 1))
    }
}

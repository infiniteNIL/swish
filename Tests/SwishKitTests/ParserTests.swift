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
        let lexer = Lexer("@")
        #expect(throws: LexerError.illegalCharacter("@", line: 1, column: 1)) {
            try Parser(lexer)
        }
    }

    // MARK: - Symbol literals

    @Test("Parses simple symbol")
    func parseSimpleSymbol() throws {
        let lexer = Lexer("foo")
        let parser = try Parser(lexer)
        let exprs = try parser.parse()
        #expect(exprs == [.symbol("foo")])
    }

    @Test("Parses hyphenated symbol")
    func parseHyphenatedSymbol() throws {
        let lexer = Lexer("foo-bar")
        let parser = try Parser(lexer)
        let exprs = try parser.parse()
        #expect(exprs == [.symbol("foo-bar")])
    }

    @Test("Parses symbol with special chars")
    func parseSymbolWithSpecialChars() throws {
        let lexer = Lexer("*foo*")
        let parser = try Parser(lexer)
        let exprs = try parser.parse()
        #expect(exprs == [.symbol("*foo*")])
    }

    @Test("Parses lone + as symbol")
    func parseLonePlusAsSymbol() throws {
        let lexer = Lexer("+")
        let parser = try Parser(lexer)
        let exprs = try parser.parse()
        #expect(exprs == [.symbol("+")])
    }

    @Test("Parses lone - as symbol")
    func parseLoneMinusAsSymbol() throws {
        let lexer = Lexer("-")
        let parser = try Parser(lexer)
        let exprs = try parser.parse()
        #expect(exprs == [.symbol("-")])
    }

    @Test("Parses / as symbol")
    func parseSlashAsSymbol() throws {
        let lexer = Lexer("/")
        let parser = try Parser(lexer)
        let exprs = try parser.parse()
        #expect(exprs == [.symbol("/")])
    }

    @Test("Parses namespaced symbol")
    func parseNamespacedSymbol() throws {
        let lexer = Lexer("clojure.core/map")
        let parser = try Parser(lexer)
        let exprs = try parser.parse()
        #expect(exprs == [.symbol("clojure.core/map")])
    }

    @Test("Parses multiple symbols")
    func parseMultipleSymbols() throws {
        let lexer = Lexer("foo bar baz")
        let parser = try Parser(lexer)
        let exprs = try parser.parse()
        #expect(exprs == [.symbol("foo"), .symbol("bar"), .symbol("baz")])
    }

    @Test("Parses mixed types including symbols")
    func parseMixedTypesWithSymbols() throws {
        let lexer = Lexer("foo 42 \"hello\" bar 1.5")
        let parser = try Parser(lexer)
        let exprs = try parser.parse()
        #expect(exprs == [.symbol("foo"), .integer(42), .string("hello"), .symbol("bar"), .float(1.5)])
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

    // MARK: - Octal integer literals

    @Test("Parses octal integer")
    func parseOctalInteger() throws {
        let lexer = Lexer("0o700")
        let parser = try Parser(lexer)
        let exprs = try parser.parse()
        #expect(exprs == [.integer(448)]) // 7*64 = 448
    }

    @Test("Parses negative octal integer")
    func parseNegativeOctalInteger() throws {
        let lexer = Lexer("-0o700")
        let parser = try Parser(lexer)
        let exprs = try parser.parse()
        #expect(exprs == [.integer(-448)])
    }

    @Test("Parses positive octal integer with plus sign")
    func parsePositiveOctalInteger() throws {
        let lexer = Lexer("+0o755")
        let parser = try Parser(lexer)
        let exprs = try parser.parse()
        #expect(exprs == [.integer(493)]) // 7*64 + 5*8 + 5 = 493
    }

    @Test("Parses octal zero")
    func parseOctalZero() throws {
        let lexer = Lexer("0o0")
        let parser = try Parser(lexer)
        let exprs = try parser.parse()
        #expect(exprs == [.integer(0)])
    }

    // MARK: - Decimal integers with leading zeros

    @Test("Parses leading zero as decimal")
    func parseLeadingZeroAsDecimal() throws {
        let lexer = Lexer("0700")
        let parser = try Parser(lexer)
        let exprs = try parser.parse()
        #expect(exprs == [.integer(700)])
    }

    @Test("Parses 08 as decimal")
    func parse08AsDecimal() throws {
        let lexer = Lexer("08")
        let parser = try Parser(lexer)
        let exprs = try parser.parse()
        #expect(exprs == [.integer(8)])
    }

    @Test("Parses 00 as decimal zero")
    func parse00AsDecimal() throws {
        let lexer = Lexer("00")
        let parser = try Parser(lexer)
        let exprs = try parser.parse()
        #expect(exprs == [.integer(0)])
    }

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

    // MARK: - String literals

    @Test("Parses basic string")
    func parseBasicString() throws {
        let lexer = Lexer("\"hello\"")
        let parser = try Parser(lexer)
        let exprs = try parser.parse()
        #expect(exprs == [.string("hello")])
    }

    @Test("Parses empty string")
    func parseEmptyString() throws {
        let lexer = Lexer("\"\"")
        let parser = try Parser(lexer)
        let exprs = try parser.parse()
        #expect(exprs == [.string("")])
    }

    @Test("Parses string with escapes")
    func parseStringWithEscapes() throws {
        let lexer = Lexer("\"hello\\nworld\"")
        let parser = try Parser(lexer)
        let exprs = try parser.parse()
        #expect(exprs == [.string("hello\nworld")])
    }

    @Test("Parses multiple strings")
    func parseMultipleStrings() throws {
        let lexer = Lexer("\"hello\" \"world\"")
        let parser = try Parser(lexer)
        let exprs = try parser.parse()
        #expect(exprs == [.string("hello"), .string("world")])
    }

    @Test("Parses mixed integers, floats, ratios, and strings")
    func parseMixedTypes() throws {
        let lexer = Lexer("1 \"hello\" 1.5 1/2")
        let parser = try Parser(lexer)
        let exprs = try parser.parse()
        #expect(exprs == [.integer(1), .string("hello"), .float(1.5), .ratio(Ratio(1, 2))])
    }

    // MARK: - Character literals

    @Test("Parses simple character")
    func parseSimpleCharacter() throws {
        let lexer = Lexer("\\a")
        let parser = try Parser(lexer)
        let exprs = try parser.parse()
        #expect(exprs == [.character("a")])
    }

    @Test("Parses named character - newline")
    func parseNamedCharacterNewline() throws {
        let lexer = Lexer("\\newline")
        let parser = try Parser(lexer)
        let exprs = try parser.parse()
        #expect(exprs == [.character("\n")])
    }

    @Test("Parses named character - space")
    func parseNamedCharacterSpace() throws {
        let lexer = Lexer("\\space")
        let parser = try Parser(lexer)
        let exprs = try parser.parse()
        #expect(exprs == [.character(" ")])
    }

    @Test("Parses Unicode character")
    func parseUnicodeCharacter() throws {
        let lexer = Lexer("\\u{20AC}")
        let parser = try Parser(lexer)
        let exprs = try parser.parse()
        #expect(exprs == [.character("€")])
    }

    @Test("Parses multiple characters")
    func parseMultipleCharacters() throws {
        let lexer = Lexer("\\a \\b \\c")
        let parser = try Parser(lexer)
        let exprs = try parser.parse()
        #expect(exprs == [.character("a"), .character("b"), .character("c")])
    }

    @Test("Parses mixed types including characters")
    func parseMixedTypesWithCharacters() throws {
        let lexer = Lexer("\\a 42 \"hello\" 1.5")
        let parser = try Parser(lexer)
        let exprs = try parser.parse()
        #expect(exprs == [.character("a"), .integer(42), .string("hello"), .float(1.5)])
    }

    // MARK: - Boolean literals

    @Test("Parses true")
    func parseTrue() throws {
        let lexer = Lexer("true")
        let parser = try Parser(lexer)
        let exprs = try parser.parse()
        #expect(exprs == [.boolean(true)])
    }

    @Test("Parses false")
    func parseFalse() throws {
        let lexer = Lexer("false")
        let parser = try Parser(lexer)
        let exprs = try parser.parse()
        #expect(exprs == [.boolean(false)])
    }

    @Test("Parses multiple booleans")
    func parseMultipleBooleans() throws {
        let lexer = Lexer("true false true")
        let parser = try Parser(lexer)
        let exprs = try parser.parse()
        #expect(exprs == [.boolean(true), .boolean(false), .boolean(true)])
    }

    @Test("Parses mixed types including booleans")
    func parseMixedTypesWithBooleans() throws {
        let lexer = Lexer("true 42 \"hello\" false 1.5")
        let parser = try Parser(lexer)
        let exprs = try parser.parse()
        #expect(exprs == [.boolean(true), .integer(42), .string("hello"), .boolean(false), .float(1.5)])
    }

    // MARK: - Nil literal

    @Test("Parses nil")
    func parseNil() throws {
        let lexer = Lexer("nil")
        let parser = try Parser(lexer)
        let exprs = try parser.parse()
        #expect(exprs == [.nil])
    }

    @Test("Parses mixed types including nil")
    func parseMixedTypesWithNil() throws {
        let lexer = Lexer("nil 42 true nil")
        let parser = try Parser(lexer)
        let exprs = try parser.parse()
        #expect(exprs == [.nil, .integer(42), .boolean(true), .nil])
    }

    // MARK: - Keyword literals

    @Test("Parses simple keyword")
    func parseSimpleKeyword() throws {
        let lexer = Lexer(":foo")
        let parser = try Parser(lexer)
        let exprs = try parser.parse()
        #expect(exprs == [.keyword("foo")])
    }

    @Test("Parses hyphenated keyword")
    func parseHyphenatedKeyword() throws {
        let lexer = Lexer(":foo-bar")
        let parser = try Parser(lexer)
        let exprs = try parser.parse()
        #expect(exprs == [.keyword("foo-bar")])
    }

    @Test("Parses namespaced keyword")
    func parseNamespacedKeyword() throws {
        let lexer = Lexer(":user/name")
        let parser = try Parser(lexer)
        let exprs = try parser.parse()
        #expect(exprs == [.keyword("user/name")])
    }

    @Test("Parses :true as keyword")
    func parseColonTrueAsKeyword() throws {
        let lexer = Lexer(":true")
        let parser = try Parser(lexer)
        let exprs = try parser.parse()
        #expect(exprs == [.keyword("true")])
    }

    @Test("Parses :false as keyword")
    func parseColonFalseAsKeyword() throws {
        let lexer = Lexer(":false")
        let parser = try Parser(lexer)
        let exprs = try parser.parse()
        #expect(exprs == [.keyword("false")])
    }

    @Test("Parses :nil as keyword")
    func parseColonNilAsKeyword() throws {
        let lexer = Lexer(":nil")
        let parser = try Parser(lexer)
        let exprs = try parser.parse()
        #expect(exprs == [.keyword("nil")])
    }

    @Test("Parses multiple keywords")
    func parseMultipleKeywords() throws {
        let lexer = Lexer(":foo :bar :baz")
        let parser = try Parser(lexer)
        let exprs = try parser.parse()
        #expect(exprs == [.keyword("foo"), .keyword("bar"), .keyword("baz")])
    }

    @Test("Parses mixed types including keywords")
    func parseMixedTypesWithKeywords() throws {
        let lexer = Lexer(":foo 42 \"hello\" :bar true")
        let parser = try Parser(lexer)
        let exprs = try parser.parse()
        #expect(exprs == [.keyword("foo"), .integer(42), .string("hello"), .keyword("bar"), .boolean(true)])
    }

    // MARK: - List literals

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

    @Test("Throws error for def with too few arguments")
    func defWithTooFewArgumentsThrows() throws {
        let lexer = Lexer("(def x)")
        let parser = try Parser(lexer)
        #expect(throws: ParserError.invalidDef("def requires exactly 2 arguments")) {
            try parser.parse()
        }
    }

    @Test("Throws error for def with too many arguments")
    func defWithTooManyArgumentsThrows() throws {
        let lexer = Lexer("(def x 1 2)")
        let parser = try Parser(lexer)
        #expect(throws: ParserError.invalidDef("def requires exactly 2 arguments")) {
            try parser.parse()
        }
    }
}

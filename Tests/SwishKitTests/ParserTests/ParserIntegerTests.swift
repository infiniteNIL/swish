import Testing
@testable import SwishKit

@Suite("Parser Integer Tests")
struct ParserIntegerTests {
    @Test("Parses integer")
    func parseInteger() throws {
        #expect(try Reader.readString("42") == [.integer(42)])
    }

    @Test("Parses negative integer")
    func parseNegativeInteger() throws {
        #expect(try Reader.readString("-17") == [.integer(-17)])
    }

    @Test("Parses positive integer with plus sign")
    func parsePositiveInteger() throws {
        #expect(try Reader.readString("+5") == [.integer(5)])
    }

    @Test("Parses zero")
    func parseZero() throws {
        #expect(try Reader.readString("0") == [.integer(0)])
    }

    @Test("Parses multiple integers")
    func parseMultipleIntegers() throws {
        #expect(try Reader.readString("1 2 3") == [.integer(1), .integer(2), .integer(3)])
    }

    @Test("Returns empty array for empty input")
    func emptyInputReturnsEmptyArray() throws {
        #expect(try Reader.readString("") == [])
    }

    @Test("Returns empty array for whitespace-only input")
    func whitespaceOnlyReturnsEmptyArray() throws {
        #expect(try Reader.readString("   \n\t  ") == [])
    }

    @Test("Lexer error propagates through parser init")
    func lexerErrorPropagates() throws {
        #expect(throws: LexerError.illegalCharacter("¡", line: 1, column: 1)) {
            try Reader.readString("¡")
        }
    }

    // MARK: - Symbol literals

    @Test("Parses simple symbol")
    func parseSimpleSymbol() throws {
        #expect(try Reader.readString("foo") == [.symbol("foo", metadata: nil)])
    }

    @Test("Parses hyphenated symbol")
    func parseHyphenatedSymbol() throws {
        #expect(try Reader.readString("foo-bar") == [.symbol("foo-bar", metadata: nil)])
    }

    @Test("Parses symbol with special chars")
    func parseSymbolWithSpecialChars() throws {
        #expect(try Reader.readString("*foo*") == [.symbol("*foo*", metadata: nil)])
    }

    @Test("Parses lone + as symbol")
    func parseLonePlusAsSymbol() throws {
        #expect(try Reader.readString("+") == [.symbol("+", metadata: nil)])
    }

    @Test("Parses lone - as symbol")
    func parseLoneMinusAsSymbol() throws {
        #expect(try Reader.readString("-") == [.symbol("-", metadata: nil)])
    }

    @Test("Parses / as symbol")
    func parseSlashAsSymbol() throws {
        #expect(try Reader.readString("/") == [.symbol("/", metadata: nil)])
    }

    @Test("Parses namespaced symbol")
    func parseNamespacedSymbol() throws {
        #expect(try Reader.readString("clojure.core/map") == [.symbol("clojure.core/map", metadata: nil)])
    }

    @Test("Parses multiple symbols")
    func parseMultipleSymbols() throws {
        #expect(try Reader.readString("foo bar baz") == [.symbol("foo", metadata: nil), .symbol("bar", metadata: nil), .symbol("baz", metadata: nil)])
    }

    @Test("Parses mixed types including symbols")
    func parseMixedTypesWithSymbols() throws {
        #expect(try Reader.readString("foo 42 \"hello\" bar 1.5") == [.symbol("foo", metadata: nil), .integer(42), .string("hello"), .symbol("bar", metadata: nil), .double(1.5)])
    }

    // MARK: - Hexadecimal integer literals

    @Test("Parses hex integer")
    func parseHexInteger() throws {
        #expect(try Reader.readString("0xFF") == [.integer(255)])
    }

    @Test("Parses negative hex integer")
    func parseNegativeHexInteger() throws {
        #expect(try Reader.readString("-0x10") == [.integer(-16)])
    }

    @Test("Parses positive hex integer with plus sign")
    func parsePositiveHexInteger() throws {
        #expect(try Reader.readString("+0x10") == [.integer(16)])
    }

    @Test("Parses hex zero")
    func parseHexZero() throws {
        #expect(try Reader.readString("0x0") == [.integer(0)])
    }

    @Test("Parses lowercase hex digits")
    func parseLowercaseHex() throws {
        #expect(try Reader.readString("0x0a") == [.integer(10)])
    }

    // MARK: - Binary integer literals

    @Test("Parses binary integer")
    func parseBinaryInteger() throws {
        #expect(try Reader.readString("0b1010") == [.integer(10)])
    }

    @Test("Parses negative binary integer")
    func parseNegativeBinaryInteger() throws {
        #expect(try Reader.readString("-0b1010") == [.integer(-10)])
    }

    @Test("Parses positive binary integer with plus sign")
    func parsePositiveBinaryInteger() throws {
        #expect(try Reader.readString("+0b100") == [.integer(4)])
    }

    @Test("Parses binary zero")
    func parseBinaryZero() throws {
        #expect(try Reader.readString("0b0") == [.integer(0)])
    }

    // MARK: - Octal integer literals

    @Test("Parses octal integer")
    func parseOctalInteger() throws {
        #expect(try Reader.readString("0o700") == [.integer(448)]) // 7*64 = 448
    }

    @Test("Parses negative octal integer")
    func parseNegativeOctalInteger() throws {
        #expect(try Reader.readString("-0o700") == [.integer(-448)])
    }

    @Test("Parses positive octal integer with plus sign")
    func parsePositiveOctalInteger() throws {
        #expect(try Reader.readString("+0o755") == [.integer(493)]) // 7*64 + 5*8 + 5 = 493
    }

    @Test("Parses octal zero")
    func parseOctalZero() throws {
        #expect(try Reader.readString("0o0") == [.integer(0)])
    }

    // MARK: - Clojure-style octal integers (leading zero)

    @Test("Parses leading zero as octal: 0700 = 448")
    func parseLeadingZeroAsOctal() throws {
        #expect(try Reader.readString("0700") == [.integer(448)])
    }

    @Test("Throws for invalid octal digit: 08")
    func parse08Throws() throws {
        #expect(throws: (any Error).self) {
            try Reader.readString("08")
        }
    }

    @Test("Parses 00 as decimal zero")
    func parse00AsDecimal() throws {
        #expect(try Reader.readString("00") == [.integer(0)])
    }
}

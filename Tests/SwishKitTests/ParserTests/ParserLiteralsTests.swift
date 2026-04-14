import Testing
@testable import SwishKit

@Suite("Parser Literals Tests")
struct ParserLiteralsTests {
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
}

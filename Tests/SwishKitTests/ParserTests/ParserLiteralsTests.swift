import Testing
@testable import SwishKit

@Suite("Parser Literals Tests")
struct ParserLiteralsTests {
    // MARK: - String literals

    @Test("Parses basic string")
    func parseBasicString() throws {
        #expect(try Reader.readString("\"hello\"") == [.string("hello")])
    }

    @Test("Parses empty string")
    func parseEmptyString() throws {
        #expect(try Reader.readString("\"\"") == [.string("")])
    }

    @Test("Parses string with escapes")
    func parseStringWithEscapes() throws {
        #expect(try Reader.readString("\"hello\\nworld\"") == [.string("hello\nworld")])
    }

    @Test("Parses multiple strings")
    func parseMultipleStrings() throws {
        #expect(try Reader.readString("\"hello\" \"world\"") == [.string("hello"), .string("world")])
    }

    @Test("Parses mixed integers, floats, ratios, and strings")
    func parseMixedTypes() throws {
        #expect(try Reader.readString("1 \"hello\" 1.5 1/2") == [.integer(1), .string("hello"), .double(1.5), .ratio(Ratio(1, 2))])
    }

    // MARK: - Character literals

    @Test("Parses simple character")
    func parseSimpleCharacter() throws {
        #expect(try Reader.readString("\\a") == [.character("a")])
    }

    @Test("Parses named character - newline")
    func parseNamedCharacterNewline() throws {
        #expect(try Reader.readString("\\newline") == [.character("\n")])
    }

    @Test("Parses named character - space")
    func parseNamedCharacterSpace() throws {
        #expect(try Reader.readString("\\space") == [.character(" ")])
    }

    @Test("Parses Clojure-style Unicode character literal \\uXXXX (U+20AC = '€')")
    func parseUnicodeCharacter() throws {
        #expect(try Reader.readString("\\u20AC") == [.character("€")])
    }

    @Test("Parses Clojure-style Unicode character literal \\u1234 (U+1234)")
    func parseUnicodeCharacter1234() throws {
        #expect(try Reader.readString("\\u1234") == [.character("\u{1234}")])
    }

    @Test("Parses multiple characters")
    func parseMultipleCharacters() throws {
        #expect(try Reader.readString("\\a \\b \\c") == [.character("a"), .character("b"), .character("c")])
    }

    @Test("Parses mixed types including characters")
    func parseMixedTypesWithCharacters() throws {
        #expect(try Reader.readString("\\a 42 \"hello\" 1.5") == [.character("a"), .integer(42), .string("hello"), .double(1.5)])
    }

    // MARK: - Boolean literals

    @Test("Parses true")
    func parseTrue() throws {
        #expect(try Reader.readString("true") == [.boolean(true)])
    }

    @Test("Parses false")
    func parseFalse() throws {
        #expect(try Reader.readString("false") == [.boolean(false)])
    }

    @Test("Parses multiple booleans")
    func parseMultipleBooleans() throws {
        #expect(try Reader.readString("true false true") == [.boolean(true), .boolean(false), .boolean(true)])
    }

    @Test("Parses mixed types including booleans")
    func parseMixedTypesWithBooleans() throws {
        #expect(try Reader.readString("true 42 \"hello\" false 1.5") == [.boolean(true), .integer(42), .string("hello"), .boolean(false), .double(1.5)])
    }

    // MARK: - Nil literal

    @Test("Parses nil")
    func parseNil() throws {
        #expect(try Reader.readString("nil") == [.nil])
    }

    @Test("Parses mixed types including nil")
    func parseMixedTypesWithNil() throws {
        #expect(try Reader.readString("nil 42 true nil") == [.nil, .integer(42), .boolean(true), .nil])
    }

    // MARK: - Keyword literals

    @Test("Parses simple keyword")
    func parseSimpleKeyword() throws {
        #expect(try Reader.readString(":foo") == [.keyword("foo")])
    }

    @Test("Parses hyphenated keyword")
    func parseHyphenatedKeyword() throws {
        #expect(try Reader.readString(":foo-bar") == [.keyword("foo-bar")])
    }

    @Test("Parses namespaced keyword")
    func parseNamespacedKeyword() throws {
        #expect(try Reader.readString(":user/name") == [.keyword("user/name")])
    }

    @Test("Parses :true as keyword")
    func parseColonTrueAsKeyword() throws {
        #expect(try Reader.readString(":true") == [.keyword("true")])
    }

    @Test("Parses :false as keyword")
    func parseColonFalseAsKeyword() throws {
        #expect(try Reader.readString(":false") == [.keyword("false")])
    }

    @Test("Parses :nil as keyword")
    func parseColonNilAsKeyword() throws {
        #expect(try Reader.readString(":nil") == [.keyword("nil")])
    }

    @Test("Parses multiple keywords")
    func parseMultipleKeywords() throws {
        #expect(try Reader.readString(":foo :bar :baz") == [.keyword("foo"), .keyword("bar"), .keyword("baz")])
    }

    @Test("Parses mixed types including keywords")
    func parseMixedTypesWithKeywords() throws {
        #expect(try Reader.readString(":foo 42 \"hello\" :bar true") == [.keyword("foo"), .integer(42), .string("hello"), .keyword("bar"), .boolean(true)])
    }
}

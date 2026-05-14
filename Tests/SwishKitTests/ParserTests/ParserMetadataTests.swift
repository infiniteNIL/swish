import Testing
@testable import SwishKit

@Suite("Parser Metadata Tests")
struct ParserMetadataTests {
    func parse(_ source: String) throws -> [Expr] {
        let lexer = Lexer(source)
        let parser = try Parser(lexer)
        return try parser.parse()
    }

    // MARK: - Spec forms

    @Test("^:k x attaches {:k true} to symbol")
    func keywordSpec() throws {
        let exprs = try parse("^:private foo")
        #expect(exprs == [.symbol("foo", metadata: [.keyword("private"): .boolean(true)])])
    }

    @Test("^Sym x attaches {:tag Sym} to symbol")
    func symbolSpec() throws {
        let exprs = try parse("^String foo")
        #expect(exprs == [.symbol("foo", metadata: [.keyword("tag"): .symbol("String", metadata: nil)])])
    }

    @Test("^\"str\" x attaches {:tag \"str\"} to symbol")
    func stringSpec() throws {
        let exprs = try parse("^\"MyType\" foo")
        #expect(exprs == [.symbol("foo", metadata: [.keyword("tag"): .string("MyType")])])
    }

    @Test("^{:a 1} x attaches map metadata to symbol")
    func mapSpec() throws {
        let exprs = try parse("^{:a 1} foo")
        #expect(exprs == [.symbol("foo", metadata: [.keyword("a"): .integer(1)])])
    }

    // MARK: - Targets

    @Test("^ applies to vector")
    func metadataOnVector() throws {
        let exprs = try parse("^:tag [1 2]")
        #expect(exprs == [.vector([.integer(1), .integer(2)], metadata: [.keyword("tag"): .boolean(true)])])
    }

    @Test("^ applies to list")
    func metadataOnList() throws {
        let exprs = try parse("^:tag (1 2)")
        #expect(exprs == [.list([.integer(1), .integer(2)], metadata: [.keyword("tag"): .boolean(true)])])
    }

    @Test("^ applies to map")
    func metadataOnMap() throws {
        let exprs = try parse("^:tag {:a 1}")
        #expect(exprs == [.map([.keyword("a"): .integer(1)], metadata: [.keyword("tag"): .boolean(true)])])
    }

    // MARK: - Stacking

    @Test("^:a ^:b x merges — outer (:a) wins on conflict")
    func stackingDistinctKeys() throws {
        let exprs = try parse("^:a ^:b foo")
        let expected = Expr.symbol("foo", metadata: [
            .keyword("a"): .boolean(true),
            .keyword("b"): .boolean(true)
        ])
        #expect(exprs == [expected])
    }

    @Test("^{:k 1} ^{:k 2} x — outer wins on same key")
    func stackingConflictingKeys() throws {
        let exprs = try parse("^{:k 1} ^{:k 2} foo")
        #expect(exprs == [.symbol("foo", metadata: [.keyword("k"): .integer(1)])])
    }

    // MARK: - Errors

    @Test("^ on integer throws metadataOnUnsupportedForm")
    func metadataOnInteger() throws {
        #expect(throws: ParserError.metadataOnUnsupportedForm(line: 1, column: 1)) {
            try parse("^:tag 42")
        }
    }

    @Test("^ with integer spec throws invalidMetadataSpec")
    func invalidSpec() throws {
        #expect(throws: ParserError.invalidMetadataSpec(line: 1, column: 1)) {
            try parse("^42 foo")
        }
    }

    @Test("^ at EOF throws unexpectedEOF")
    func caretAtEOF() throws {
        #expect(throws: ParserError.unexpectedEOF) {
            try parse("^")
        }
    }
}

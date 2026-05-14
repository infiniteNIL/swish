import Testing
@testable import SwishKit

@Suite("Printer Metadata Tests")
struct PrinterMetadataTests {
    // MARK: - printMeta: false (default)

    @Test("printMeta false: symbol with metadata prints without meta prefix")
    func symbolNoMetaPrefix() {
        let printer = Printer()
        let sym = Expr.symbol("foo", metadata: [.keyword("private"): .boolean(true)])
        #expect(printer.printString(sym) == "foo")
    }

    @Test("printMeta false: vector with metadata prints without meta prefix")
    func vectorNoMetaPrefix() {
        let printer = Printer()
        let vec = Expr.vector([.integer(1)], metadata: [.keyword("tag"): .string("T")])
        #expect(printer.printString(vec) == "[1]")
    }

    // MARK: - printMeta: true

    @Test("printMeta true: symbol with metadata prints with meta prefix")
    func symbolWithMetaPrefix() {
        var printer = Printer()
        printer.printMeta = true
        let sym = Expr.symbol("foo", metadata: [.keyword("private"): .boolean(true)])
        #expect(printer.printString(sym) == "^{:private true} foo")
    }

    @Test("printMeta true: vector with metadata prints with meta prefix")
    func vectorWithMetaPrefix() {
        var printer = Printer()
        printer.printMeta = true
        let vec = Expr.vector([.integer(1)], metadata: [.keyword("tag"): .string("T")])
        #expect(printer.printString(vec) == "^{:tag \"T\"} [1]")
    }

    @Test("printMeta true: value with nil metadata prints without prefix")
    func nilMetadataNoPrefixWhenPrintMetaTrue() {
        var printer = Printer()
        printer.printMeta = true
        let sym = Expr.symbol("foo", metadata: nil)
        #expect(printer.printString(sym) == "foo")
    }

    // MARK: - Round-trip

    @Test("Round-trip: symbol with metadata reads back with same metadata")
    func roundTripSymbol() throws {
        var printer = Printer()
        printer.printMeta = true
        let sym = Expr.symbol("foo", metadata: [.keyword("private"): .boolean(true)])
        let printed = printer.printString(sym)
        let exprs = try Reader.readString(printed)
        #expect(exprs.count == 1)
        if case .symbol(let name, let meta) = exprs[0] {
            #expect(name == "foo")
            #expect(meta == [.keyword("private"): .boolean(true)])
        }
        else {
            Issue.record("Expected symbol, got \(exprs[0])")
        }
    }
}

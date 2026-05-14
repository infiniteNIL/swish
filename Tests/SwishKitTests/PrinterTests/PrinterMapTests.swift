import Testing
@testable import SwishKit

@Suite("Printer Map Tests")
struct PrinterMapTests {
    let printer = Printer()

    @Test("prints empty map")
    func printsEmptyMap() {
        #expect(printer.printString(.map([:], metadata: nil)) == "{}")
    }

    @Test("prints map with single keyword-integer pair")
    func printsMapWithSinglePair() {
        #expect(printer.printString(.map([.keyword("a"): .integer(1)], metadata: nil)) == "{:a 1}")
    }

    @Test("prints map with multiple pairs sorted by key")
    func printsMapWithMultiplePairsSorted() {
        let map = Expr.map([.keyword("b"): .integer(2), .keyword("a"): .integer(1)], metadata: nil)
        #expect(printer.printString(map) == "{:a 1 :b 2}")
    }

    @Test("prints nested map")
    func printsNestedMap() {
        let inner = Expr.map([.keyword("b"): .integer(2)], metadata: nil)
        let outer = Expr.map([.keyword("a"): inner], metadata: nil)
        #expect(printer.printString(outer) == "{:a {:b 2}}")
    }

    @Test("str prints empty map")
    func strPrintsEmptyMap() {
        #expect(printer.strString(.map([:], metadata: nil)) == "{}")
    }

    @Test("str prints map with single pair")
    func strPrintsMapWithSinglePair() {
        #expect(printer.strString(.map([.keyword("a"): .string("hello")], metadata: nil)) == "{:a hello}")
    }

    @Test("sourceForm prints map")
    func sourceFormPrintsMap() {
        #expect(printer.sourceForm(.map([.keyword("a"): .integer(1)], metadata: nil)) == "{:a 1}")
    }
}

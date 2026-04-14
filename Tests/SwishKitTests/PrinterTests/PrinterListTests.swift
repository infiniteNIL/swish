import Testing
@testable import SwishKit

@Suite("Printer List Tests")
struct PrinterListTests {
    let printer = Printer()

    @Test("prints empty list")
    func printsEmptyList() {
        #expect(printer.printString(.list([])) == "()")
    }

    @Test("prints list with single element")
    func printsListWithSingleElement() {
        #expect(printer.printString(.list([.integer(42)])) == "(42)")
    }

    @Test("prints list with multiple elements")
    func printsListWithMultipleElements() {
        #expect(printer.printString(.list([.integer(1), .integer(2), .integer(3)])) == "(1 2 3)")
    }

    @Test("prints list with mixed types")
    func printsListWithMixedTypes() {
        #expect(printer.printString(.list([.keyword("foo"), .string("bar"), .integer(42)])) == "(:foo \"bar\" 42)")
    }

    @Test("prints nested list")
    func printsNestedList() {
        #expect(printer.printString(.list([.integer(1), .list([.integer(2), .integer(3)]), .integer(4)])) == "(1 (2 3) 4)")
    }

    @Test("prints deeply nested list")
    func printsDeeplyNestedList() {
        #expect(printer.printString(.list([.list([.list([.integer(1)])])])) == "(((1)))")
    }

    @Test("prints list with symbols")
    func printsListWithSymbols() {
        #expect(printer.printString(.list([.symbol("+"), .integer(1), .integer(2)])) == "(+ 1 2)")
    }
}

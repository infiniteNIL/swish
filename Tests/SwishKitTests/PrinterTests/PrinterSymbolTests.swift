import Testing
@testable import SwishKit

@Suite("Printer Symbol Tests")
struct PrinterSymbolTests {
    let printer = Printer()

    @Test("prints simple symbol")
    func printsSimpleSymbol() {
        #expect(printer.printString(.symbol("foo", metadata: nil)) == "foo")
    }

    @Test("prints hyphenated symbol")
    func printsHyphenatedSymbol() {
        #expect(printer.printString(.symbol("foo-bar", metadata: nil)) == "foo-bar")
    }

    @Test("prints special char symbol")
    func printsSpecialCharSymbol() {
        #expect(printer.printString(.symbol("*foo*", metadata: nil)) == "*foo*")
    }

    @Test("prints + symbol")
    func printsPlusSymbol() {
        #expect(printer.printString(.symbol("+", metadata: nil)) == "+")
    }

    @Test("prints - symbol")
    func printsMinusSymbol() {
        #expect(printer.printString(.symbol("-", metadata: nil)) == "-")
    }

    @Test("prints / symbol")
    func printsSlashSymbol() {
        #expect(printer.printString(.symbol("/", metadata: nil)) == "/")
    }

    @Test("prints namespaced symbol")
    func printsNamespacedSymbol() {
        #expect(printer.printString(.symbol("clojure.core/map", metadata: nil)) == "clojure.core/map")
    }
}

import Testing
@testable import SwishKit

@Suite("Printer Keyword Tests")
struct PrinterKeywordTests {
    let printer = Printer()

    @Test("prints simple keyword with colon prefix")
    func printsSimpleKeyword() {
        #expect(printer.printString(.keyword("foo")) == ":foo")
    }

    @Test("prints hyphenated keyword")
    func printsHyphenatedKeyword() {
        #expect(printer.printString(.keyword("foo-bar")) == ":foo-bar")
    }

    @Test("prints namespaced keyword")
    func printsNamespacedKeyword() {
        #expect(printer.printString(.keyword("user/name")) == ":user/name")
    }

    @Test("prints :true keyword")
    func printsTrueKeyword() {
        #expect(printer.printString(.keyword("true")) == ":true")
    }

    @Test("prints :false keyword")
    func printsFalseKeyword() {
        #expect(printer.printString(.keyword("false")) == ":false")
    }

    @Test("prints :nil keyword")
    func printsNilKeyword() {
        #expect(printer.printString(.keyword("nil")) == ":nil")
    }
}

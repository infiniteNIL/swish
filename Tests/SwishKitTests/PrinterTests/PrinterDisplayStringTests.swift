import Testing
@testable import SwishKit

@Suite("Printer Display String Tests")
struct PrinterDisplayStringTests {
    let printer = Printer()

    @Test("displays string without quotes")
    func displaysStringWithoutQuotes() {
        #expect(printer.strString(.string("hello")) == "hello")
    }

    @Test("displays empty string as empty")
    func displaysEmptyString() {
        #expect(printer.strString(.string("")) == "")
    }

    @Test("displays string with special characters unescaped")
    func displaysStringWithSpecialChars() {
        #expect(printer.strString(.string("line1\nline2")) == "line1\nline2")
    }

    @Test("displays character as raw character")
    func displaysCharacterAsRaw() {
        #expect(printer.strString(.character("a")) == "a")
    }

    @Test("displays newline character as actual newline")
    func displaysNewlineCharacter() {
        #expect(printer.strString(.character("\n")) == "\n")
    }

    @Test("displays space character as space")
    func displaysSpaceCharacter() {
        #expect(printer.strString(.character(" ")) == " ")
    }

    @Test("displays list with string elements without quotes")
    func displaysListWithStrings() {
        #expect(printer.strString(.list([.string("hello"), .string("world")])) == "(hello world)")
    }

    @Test("displays integer same as printString")
    func displaysInteger() {
        #expect(printer.strString(.integer(42)) == "42")
    }

    @Test("displays boolean same as printString")
    func displaysBoolean() {
        #expect(printer.strString(.boolean(true)) == "true")
    }

    @Test("displays nil same as printString")
    func displaysNil() {
        #expect(printer.strString(.nil) == "nil")
    }

    @Test("displays keyword same as printString")
    func displaysKeyword() {
        #expect(printer.strString(.keyword("foo")) == ":foo")
    }
}

import Testing
@testable import SwishKit

@Suite("Printer Display String Tests")
struct PrinterDisplayStringTests {
    let printer = Printer()

    @Test("displays string without quotes")
    func displaysStringWithoutQuotes() {
        #expect(printer.displayString(.string("hello")) == "hello")
    }

    @Test("displays empty string as empty")
    func displaysEmptyString() {
        #expect(printer.displayString(.string("")) == "")
    }

    @Test("displays string with special characters unescaped")
    func displaysStringWithSpecialChars() {
        #expect(printer.displayString(.string("line1\nline2")) == "line1\nline2")
    }

    @Test("displays character as raw character")
    func displaysCharacterAsRaw() {
        #expect(printer.displayString(.character("a")) == "a")
    }

    @Test("displays newline character as actual newline")
    func displaysNewlineCharacter() {
        #expect(printer.displayString(.character("\n")) == "\n")
    }

    @Test("displays space character as space")
    func displaysSpaceCharacter() {
        #expect(printer.displayString(.character(" ")) == " ")
    }

    @Test("displays list with string elements without quotes")
    func displaysListWithStrings() {
        #expect(printer.displayString(.list([.string("hello"), .string("world")])) == "(hello world)")
    }

    @Test("displays integer same as printString")
    func displaysInteger() {
        #expect(printer.displayString(.integer(42)) == "42")
    }

    @Test("displays boolean same as printString")
    func displaysBoolean() {
        #expect(printer.displayString(.boolean(true)) == "true")
    }

    @Test("displays nil same as printString")
    func displaysNil() {
        #expect(printer.displayString(.nil) == "nil")
    }

    @Test("displays keyword same as printString")
    func displaysKeyword() {
        #expect(printer.displayString(.keyword("foo")) == ":foo")
    }
}

import Testing
@testable import SwishKit

@Suite("Printer String Tests")
struct PrinterStringTests {
    let printer = Printer()

    @Test("prints basic string with quotes")
    func printsBasicString() {
        #expect(printer.printString(.string("hello")) == "\"hello\"")
    }

    @Test("prints empty string")
    func printsEmptyString() {
        #expect(printer.printString(.string("")) == "\"\"")
    }

    @Test("prints string with escaped quote")
    func printsStringWithEscapedQuote() {
        #expect(printer.printString(.string("say \"hi\"")) == "\"say \\\"hi\\\"\"")
    }

    @Test("prints string with escaped backslash")
    func printsStringWithEscapedBackslash() {
        #expect(printer.printString(.string("a\\b")) == "\"a\\\\b\"")
    }

    @Test("prints string with escaped newline")
    func printsStringWithEscapedNewline() {
        #expect(printer.printString(.string("line1\nline2")) == "\"line1\\nline2\"")
    }

    @Test("prints string with escaped tab")
    func printsStringWithEscapedTab() {
        #expect(printer.printString(.string("col1\tcol2")) == "\"col1\\tcol2\"")
    }

    @Test("prints string with escaped carriage return")
    func printsStringWithEscapedCarriageReturn() {
        #expect(printer.printString(.string("line1\rline2")) == "\"line1\\rline2\"")
    }

    @Test("prints string with escaped null")
    func printsStringWithEscapedNull() {
        #expect(printer.printString(.string("a\0b")) == "\"a\\0b\"")
    }

    @Test("prints string with multiple special characters")
    func printsStringWithMultipleSpecialChars() {
        #expect(printer.printString(.string("\"\\\n\t")) == "\"\\\"\\\\\\n\\t\"")
    }
}

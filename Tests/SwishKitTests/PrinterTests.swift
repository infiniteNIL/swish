import Testing
@testable import SwishKit

@Suite("Printer Tests")
struct PrinterTests {
    let printer = Printer()

    @Suite("Integers")
    struct Integers {
        let printer = Printer()

        @Test("prints positive integer")
        func printsPositiveInteger() {
            #expect(printer.printString(.integer(.int(42))) == "42")
        }

        @Test("prints negative integer")
        func printsNegativeInteger() {
            #expect(printer.printString(.integer(.int(-17))) == "-17")
        }

        @Test("prints zero")
        func printsZero() {
            #expect(printer.printString(.integer(.int(0))) == "0")
        }
    }
}

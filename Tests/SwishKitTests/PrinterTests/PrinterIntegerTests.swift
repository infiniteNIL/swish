import Testing
@testable import SwishKit

@Suite("Printer Integer Tests")
struct PrinterIntegerTests {
    let printer = Printer()

    @Test("prints positive integer")
    func printsPositiveInteger() {
        #expect(printer.printString(.integer(42)) == "42")
    }

    @Test("prints negative integer")
    func printsNegativeInteger() {
        #expect(printer.printString(.integer(-17)) == "-17")
    }

    @Test("prints zero")
    func printsZero() {
        #expect(printer.printString(.integer(0)) == "0")
    }

    @Test("prints large number")
    func printsLargeNumber() {
        #expect(printer.printString(.integer(1_000_000)) == "1000000")
    }

    @Test("prints negative large number")
    func printsNegativeLargeNumber() {
        #expect(printer.printString(.integer(-1_000_000)) == "-1000000")
    }
}
